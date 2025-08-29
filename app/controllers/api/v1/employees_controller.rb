module Api
  module V1
    class EmployeesController < ApplicationController
      before_action :set_restaurant
      before_action :set_employee, only: [:show, :update, :destroy]
      before_action :authorize_employee_access!, only: [:show]
      before_action :authorize_employee_management!, only: [:create, :update, :destroy]

      def index
        @employees = @restaurant.employees
                               .includes(:transactions)
                               .order(:first_name, :last_name)

        # Apply filters
        @employees = @employees.by_position(params[:position]) if params[:position].present?
        @employees = @employees.active if params[:active] == 'true'
        @employees = @employees.recently_hired if params[:recently_hired] == 'true'

        render_paginated @employees
      end

      def show
        render json: {
          employee: @employee,
          performance: {
            total_transactions: @employee.total_transactions,
            total_sales: @employee.total_sales,
            average_transaction_value: @employee.average_transaction_value,
            today_transactions: @employee.today_transactions.count,
            today_sales: @employee.today_sales,
            years_of_service: @employee.years_of_service,
            monthly_salary: @employee.monthly_salary
          },
          recent_transactions: @employee.transactions.recent.limit(10)
        }
      end

      def create
        @employee = @restaurant.employees.build(employee_params)
        
        if @employee.save
          render json: @employee, status: :created
        else
          render json: { errors: @employee.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @employee.update(employee_params)
          render json: @employee
        else
          render json: { errors: @employee.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @employee.update(active: false)
        head :no_content
      end

      def performance_report
        start_date = params[:start_date]&.to_date || 30.days.ago.to_date
        end_date = params[:end_date]&.to_date || Date.current

        @employees = @restaurant.employees
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

        render json: {
          period: { start_date: start_date, end_date: end_date },
          employees: @employees.map do |emp|
            {
              id: emp.id,
              name: emp.full_name,
              position: emp.position,
              transaction_count: emp.transaction_count,
              total_sales: emp.total_sales,
              avg_transaction_value: emp.avg_transaction_value,
              performance_score: calculate_performance_score(emp)
            }
          end.sort_by { |emp| -emp[:performance_score] }
        }
      end

      def import
        if params[:file].present?
          ImportEmployeesJob.perform_later(@restaurant.id, params[:file].path)
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

      def set_employee
        @employee = @restaurant.employees.find(params[:id])
      end

      def employee_params
        params.require(:employee).permit(
          :employee_id, :first_name, :last_name, :email, :phone,
          :position, :hourly_rate, :hire_date, :active
        )
      end

      def authorize_employee_access!
        unless current_user.can_access_restaurant?(@restaurant.id)
          raise Pundit::NotAuthorizedError, "Access denied to employee data"
        end
      end

      def authorize_employee_management!
        unless current_user.manager? || current_user.admin? || current_user.super_admin?
          raise Pundit::NotAuthorizedError, "Only managers and admins can manage employees"
        end
      end

      def calculate_performance_score(employee)
        # Simple performance scoring based on sales and transaction count
        sales_score = (employee.total_sales / 1000.0) * 50 # Max 50 points for sales
        transaction_score = [employee.transaction_count * 2, 30].min # Max 30 points for transactions
        efficiency_score = [employee.avg_transaction_value / 10.0, 20].min # Max 20 points for efficiency
        
        (sales_score + transaction_score + efficiency_score).round(2)
      end
    end
  end
end
