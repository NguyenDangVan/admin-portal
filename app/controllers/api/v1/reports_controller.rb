module Api
  module V1
    class ReportsController < ApplicationController
      before_action :set_restaurant
      before_action :authorize_report_access!

      def dashboard
        # Try to get from cache first
        cache_key = "dashboard_#{@restaurant.id}_#{Date.current}"
        cached_dashboard = Rails.cache.read(cache_key)
        
        if cached_dashboard
          render json: cached_dashboard
          return
        end

        dashboard_data = generate_dashboard_data
        
        # Cache for 10 minutes
        Rails.cache.write(cache_key, dashboard_data, expires_in: 10.minutes)
        
        render json: dashboard_data
      end

      def sales_analytics
        start_date = params[:start_date]&.to_date || 30.days.ago.to_date
        end_date = params[:end_date]&.to_date || Date.current
        group_by = params[:group_by] || 'day'

        analytics = generate_sales_analytics(start_date, end_date, group_by)
        
        render json: analytics
      end

      def employee_performance
        start_date = params[:start_date]&.to_date || 30.days.ago.to_date
        end_date = params[:end_date]&.to_date || Date.current

        performance_data = generate_employee_performance(start_date, end_date)
        
        render json: performance_data
      end

      def inventory_insights
        start_date = params[:start_date]&.to_date || 30.days.ago.to_date
        end_date = params[:end_date]&.to_date || Date.current

        insights = generate_inventory_insights(start_date, end_date)
        
        render json: insights
      end

      def financial_summary
        start_date = params[:start_date]&.to_date || 30.days.ago.to_date
        end_date = params[:end_date]&.to_date || Date.current

        summary = generate_financial_summary(start_date, end_date)
        
        render json: summary
      end

      def export_report
        report_type = params[:report_type]
        start_date = params[:start_date]&.to_date || 30.days.ago.to_date
        end_date = params[:end_date]&.to_date || Date.current

        case report_type
        when 'sales'
          data = generate_sales_analytics(start_date, end_date, 'day')
        when 'employees'
          data = generate_employee_performance(start_date, end_date)
        when 'financial'
          data = generate_financial_summary(start_date, end_date)
        else
          return render json: { error: 'Invalid report type' }, status: :unprocessable_entity
        end

        # Generate CSV
        csv_data = generate_csv(data, report_type)
        
        send_data csv_data, 
                  filename: "#{report_type}_report_#{start_date}_#{end_date}.csv",
                  type: 'text/csv'
      end

      private

      def set_restaurant
        @restaurant = current_restaurant
        head :forbidden unless @restaurant
      end

      def authorize_report_access!
        unless current_user.manager? || current_user.admin? || current_user.super_admin?
          raise Pundit::NotAuthorizedError, "Only managers and admins can access reports"
        end
      end

      def generate_dashboard_data
        today = Date.current
        yesterday = today - 1.day
        this_week = today.beginning_of_week
        this_month = today.beginning_of_month

        {
          restaurant: @restaurant,
          time_periods: {
            today: generate_period_stats(today, today),
            yesterday: generate_period_stats(yesterday, yesterday),
            this_week: generate_period_stats(this_week, today),
            this_month: generate_period_stats(this_month, today)
          },
          top_performers: {
            employees: @restaurant.employees.joins(:transactions)
                                     .where(transactions: { status: :completed })
                                     .group('employees.id')
                                     .order('SUM(transactions.amount) DESC')
                                     .limit(5)
                                     .select('employees.*, SUM(transactions.amount) as total_sales'),
            items: extract_top_items(@restaurant.transactions.completed.where(transaction_time: this_month.beginning_of_day..today.end_of_day))
          },
          recent_activity: {
            transactions: @restaurant.transactions.recent.limit(10),
            new_employees: @restaurant.employees.recently_hired.limit(5),
            expiring_discounts: @restaurant.discounts.active.where('end_date <= ?', 7.days.from_now).limit(5)
          }
        }
      end

      def generate_period_stats(start_date, end_date)
        transactions = @restaurant.transactions.completed
                                  .where(transaction_time: start_date.beginning_of_day..end_date.end_of_day)

        {
          period: { start_date: start_date, end_date: end_date },
          transactions: transactions.count,
          sales: transactions.sum(:amount),
          average_transaction: transactions.average(:amount)&.round(2) || 0,
          by_payment_method: transactions.group(:payment_method).sum(:amount)
        }
      end

      def generate_sales_analytics(start_date, end_date, group_by)
        transactions = @restaurant.transactions.completed
                                  .where(transaction_time: start_date.beginning_of_day..end_date.end_of_day)

        case group_by
        when 'day'
          grouped_data = transactions.group("DATE(transaction_time)").sum(:amount)
        when 'week'
          grouped_data = transactions.group("DATE_TRUNC('week', transaction_time)").sum(:amount)
        when 'month'
          grouped_data = transactions.group("DATE_TRUNC('month', transaction_time)").sum(:amount)
        when 'hour'
          grouped_data = transactions.group("EXTRACT(hour FROM transaction_time)").sum(:amount)
        else
          grouped_data = transactions.group("DATE(transaction_time)").sum(:amount)
        end

        {
          period: { start_date: start_date, end_date: end_date },
          group_by: group_by,
          data: grouped_data,
          summary: {
            total_transactions: transactions.count,
            total_sales: transactions.sum(:amount),
            average_transaction: transactions.average(:amount)&.round(2) || 0,
            peak_hours: extract_peak_hours(transactions)
          }
        }
      end

      def generate_employee_performance(start_date, end_date)
        employees = @restaurant.employees
                               .joins(:transactions)
                               .where(transactions: { 
                                 transaction_time: start_date.beginning_of_day..end_date.end_of_day,
                                 status: :completed
                               })
                               .group('employees.id')
                               .select('employees.*, 
                                       COUNT(transactions.id) as transaction_count,
                                       SUM(transactions.amount) as total_sales,
                                       AVG(transactions.amount) as avg_transaction_value')

        {
          period: { start_date: start_date, end_date: end_date },
          employees: employees.map do |emp|
            {
              id: emp.id,
              name: emp.full_name,
              position: emp.position,
              transaction_count: emp.transaction_count,
              total_sales: emp.total_sales,
              avg_transaction_value: emp.avg_transaction_value,
              performance_score: calculate_performance_score(emp),
              efficiency: (emp.total_sales / emp.transaction_count.to_f).round(2)
            }
          end.sort_by { |emp| -emp[:performance_score] }
        }
      end

      def generate_inventory_insights(start_date, end_date)
        transactions = @restaurant.transactions.completed
                                  .where(transaction_time: start_date.beginning_of_day..end_date.end_of_day)

        item_analysis = analyze_items(transactions)
        
        {
          period: { start_date: start_date, end_date: end_date },
          top_selling_items: item_analysis[:top_selling],
          low_performing_items: item_analysis[:low_performing],
          revenue_by_category: item_analysis[:revenue_by_category],
          recommendations: generate_inventory_recommendations(item_analysis)
        }
      end

      def generate_financial_summary(start_date, end_date)
        transactions = @restaurant.transactions.completed
                                  .where(transaction_time: start_date.beginning_of_day..end_date.end_of_day)

        {
          period: { start_date: start_date, end_date: end_date },
          revenue: {
            total: transactions.sum(:amount),
            by_payment_method: transactions.group(:payment_method).sum(:amount),
            by_day_of_week: transactions.group("EXTRACT(dow FROM transaction_time)").sum(:amount),
            by_hour: transactions.group("EXTRACT(hour FROM transaction_time)").sum(:amount)
          },
          transactions: {
            total: transactions.count,
            average: transactions.average(:amount)&.round(2) || 0,
            high_value: transactions.high_value.count,
            by_status: transactions.group(:status).count
          },
          trends: calculate_trends(start_date, end_date)
        }
      end

      def extract_top_items(transactions)
        item_counts = {}
        
        transactions.each do |transaction|
          transaction.items.each do |item|
            item_name = item['name']
            item_counts[item_name] ||= { count: 0, revenue: 0 }
            item_counts[item_name][:count] += item['quantity'] || 1
            item_counts[item_name][:revenue] += (item['price'] || 0) * (item['quantity'] || 1)
          end
        end

        item_counts.sort_by { |_, data| -data[:revenue] }.first(10)
      end

      def extract_peak_hours(transactions)
        hourly_sales = transactions.group("EXTRACT(hour FROM transaction_time)").sum(:amount)
        peak_hours = hourly_sales.sort_by { |_, amount| -amount }.first(3)
        
        peak_hours.map { |hour, amount| { hour: hour.to_i, sales: amount } }
      end

      def calculate_performance_score(employee)
        sales_score = (employee.total_sales / 1000.0) * 50
        transaction_score = [employee.transaction_count * 2, 30].min
        efficiency_score = [employee.avg_transaction_value / 10.0, 20].min
        
        (sales_score + transaction_score + efficiency_score).round(2)
      end

      def analyze_items(transactions)
        item_stats = {}
        
        transactions.each do |transaction|
          transaction.items.each do |item|
            item_name = item['name']
            item_stats[item_name] ||= { count: 0, revenue: 0, transactions: 0 }
            item_stats[item_name][:count] += item['quantity'] || 1
            item_stats[item_name][:revenue] += (item['price'] || 0) * (item['quantity'] || 1)
            item_stats[item_name][:transactions] += 1
          end
        end

        {
          top_selling: item_stats.sort_by { |_, data| -data[:count] }.first(10),
          low_performing: item_stats.sort_by { |_, data| data[:revenue] }.first(10),
          revenue_by_category: categorize_items(item_stats)
        }
      end

      def categorize_items(item_stats)
        # Simple categorization based on item names
        categories = {}
        
        item_stats.each do |item_name, data|
          category = determine_category(item_name)
          categories[category] ||= { count: 0, revenue: 0 }
          categories[category][:count] += data[:count]
          categories[category][:revenue] += data[:revenue]
        end

        categories.sort_by { |_, data| -data[:revenue] }
      end

      def determine_category(item_name)
        name_lower = item_name.downcase
        
        case name_lower
        when /pizza|burger|sandwich|wrap/
          'Main Course'
        when /fries|salad|soup|appetizer/
          'Side Dish'
        when /drink|beverage|juice|soda/
          'Beverage'
        when /dessert|cake|ice cream/
          'Dessert'
        else
          'Other'
        end
      end

      def generate_inventory_recommendations(item_analysis)
        recommendations = []
        
        # High-performing items
        top_items = item_analysis[:top_selling].first(5)
        recommendations << {
          type: 'increase_stock',
          items: top_items.map { |name, _| name },
          reason: 'These items are selling well and may need increased stock levels'
        }

        # Low-performing items
        low_items = item_analysis[:low_performing].first(3)
        if low_items.any?
          recommendations << {
            type: 'review_pricing',
            items: low_items.map { |name, _| name },
            reason: 'Consider adjusting prices or promotions for these items'
          }
        end

        recommendations
      end

      def calculate_trends(start_date, end_date)
        # Calculate week-over-week growth
        current_week = start_date.beginning_of_week..end_date.end_of_week
        previous_week = (start_date - 1.week).beginning_of_week..(start_date - 1.week).end_of_week

        current_sales = @restaurant.transactions.completed
                                   .where(transaction_time: current_week)
                                   .sum(:amount)
        previous_sales = @restaurant.transactions.completed
                                    .where(transaction_time: previous_week)
                                    .sum(:amount)

        growth_rate = previous_sales > 0 ? ((current_sales - previous_sales) / previous_sales * 100).round(2) : 0

        {
          week_over_week_growth: growth_rate,
          trend_direction: growth_rate > 0 ? 'up' : growth_rate < 0 ? 'down' : 'stable'
        }
      end

      def generate_csv(data, report_type)
        require 'csv'
        
        CSV.generate do |csv|
          case report_type
          when 'sales'
            csv << ['Date', 'Sales', 'Transactions', 'Average Transaction']
            data[:data].each do |date, sales|
              csv << [date, sales, data[:summary][:total_transactions], data[:summary][:average_transaction]]
            end
          when 'employees'
            csv << ['Employee', 'Position', 'Transactions', 'Total Sales', 'Performance Score']
            data[:employees].each do |emp|
              csv << [emp[:name], emp[:position], emp[:transaction_count], emp[:total_sales], emp[:performance_score]]
            end
          when 'financial'
            csv << ['Metric', 'Value']
            csv << ['Total Revenue', data[:revenue][:total]]
            csv << ['Total Transactions', data[:transactions][:total]]
            csv << ['Average Transaction', data[:transactions][:average]]
          end
        end
      end
    end
  end
end
