module Api
  module V1
    class TransactionsController < ApplicationController
      before_action :set_restaurant
      before_action :set_transaction, only: [:show, :update, :destroy]
      before_action :authorize_transaction_access!, only: [:show]
      before_action :authorize_transaction_management!, only: [:create, :update, :destroy]

      def index
        @transactions = @restaurant.transactions
                                  .includes(:employee)
                                  .order(transaction_time: :desc)

        # Apply filters
        @transactions = @transactions.by_date(params[:date]) if params[:date].present?
        @transactions = @transactions.by_employee(params[:employee_id]) if params[:employee_id].present?
        @transactions = @transactions.by_payment_method(params[:payment_method]) if params[:payment_method].present?
        @transactions = @transactions.by_status(params[:status]) if params[:status].present?
        @transactions = @transactions.high_value if params[:high_value] == 'true'
        @transactions = @transactions.recent if params[:recent] == 'true'

        render_paginated @transactions
      end

      def show
        render json: {
          transaction: @transaction,
          employee: @transaction.employee,
          restaurant: @transaction.restaurant
        }
      end

      def create
        @transaction = @restaurant.transactions.build(transaction_params)
        @transaction.employee_id ||= current_user.employee&.id
        
        if @transaction.save
          render json: @transaction, status: :created
        else
          render json: { errors: @transaction.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @transaction.update(transaction_params)
          render json: @transaction
        else
          render json: { errors: @transaction.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @transaction.update(status: :cancelled)
        head :no_content
      end

      def daily_sales_report
        date = params[:date]&.to_date || Date.current
        
        # Try to get from cache first
        cache_key = "daily_sales_#{@restaurant.id}_#{date}"
        cached_report = Rails.cache.read(cache_key)
        
        if cached_report
          render json: cached_report
          return
        end

        # Generate report
        report = generate_daily_sales_report(date)
        
        # Cache for 5 minutes
        Rails.cache.write(cache_key, report, expires_in: 5.minutes)
        
        render json: report
      end

      def sales_summary
        start_date = params[:start_date]&.to_date || 30.days.ago.to_date
        end_date = params[:end_date]&.to_date || Date.current

        summary = {
          period: { start_date: start_date, end_date: end_date },
          totals: {
            transactions: @restaurant.transactions.completed
                                    .where(transaction_time: start_date.beginning_of_day..end_date.end_of_day)
                                    .count,
            sales: @restaurant.transactions.completed
                              .where(transaction_time: start_date.beginning_of_day..end_date.end_of_day)
                              .sum(:amount),
            average_transaction: @restaurant.transactions.completed
                                           .where(transaction_time: start_date.beginning_of_day..end_date.end_of_day)
                                           .average(:amount)
          },
          by_payment_method: @restaurant.transactions.completed
                                        .where(transaction_time: start_date.beginning_of_day..end_date.end_of_day)
                                        .group(:payment_method)
                                        .sum(:amount),
          by_employee: @restaurant.transactions.completed
                                  .joins(:employee)
                                  .where(transaction_time: start_date.beginning_of_day..end_date.end_of_day)
                                  .group('employees.id')
                                  .select('employees.first_name, employees.last_name, 
                                          COUNT(transactions.id) as transaction_count,
                                          SUM(transactions.amount) as total_sales')
        }

        render json: summary
      end

      def import
        if params[:file].present?
          ImportTransactionsJob.perform_later(@restaurant.id, params[:file].path)
          render json: { message: 'Import job started. You will be notified when complete.' }
        else
          render json: { error: 'No file provided' }, status: :unprocessable_entity
        end
      end

      private

      def set_restaurant
        @restaurant = current_restaurant
        head :forbidden unless @restaurant
      end

      def set_transaction
        @transaction = @restaurant.transactions.find(params[:id])
      end

      def transaction_params
        params.require(:transaction).permit(
          :employee_id, :transaction_id, :amount, :payment_method,
          :status, :transaction_time, :items, :notes
        )
      end

      def authorize_transaction_access!
        unless current_user.can_access_restaurant?(@restaurant.id)
          raise Pundit::NotAuthorizedError, "Access denied to transaction data"
        end
      end

      def authorize_transaction_management!
        unless current_user.manager? || current_user.admin? || current_user.super_admin?
          raise Pundit::NotAuthorizedError, "Only managers and admins can manage transactions"
        end
      end

      def generate_daily_sales_report(date)
        transactions = @restaurant.transactions.completed
                                  .where(transaction_time: date.beginning_of_day..date.end_of_day)

        {
          date: date,
          summary: {
            total_transactions: transactions.count,
            total_sales: transactions.sum(:amount),
            average_transaction: transactions.average(:amount)&.round(2) || 0
          },
          by_payment_method: transactions.group(:payment_method).sum(:amount),
          by_hour: transactions.group("EXTRACT(hour FROM transaction_time)").sum(:amount),
          top_items: extract_top_items(transactions),
          employee_performance: transactions.joins(:employee)
                                           .group('employees.id')
                                           .select('employees.first_name, employees.last_name,
                                                   COUNT(transactions.id) as transaction_count,
                                                   SUM(transactions.amount) as total_sales')
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
    end
  end
end
