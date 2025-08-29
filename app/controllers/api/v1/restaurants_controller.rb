module Api
  module V1
    class RestaurantsController < ApplicationController
      before_action :set_restaurant, only: [:show, :update, :destroy]
      before_action :authorize_restaurant_access!, only: [:show]
      before_action :authorize_restaurant_management!, only: [:create, :update, :destroy]

      def index
        @restaurants = if current_user.super_admin?
          Restaurant.all
        elsif current_user.admin?
          Restaurant.where(id: current_user.restaurant_id)
        else
          Restaurant.none
        end

        render_paginated @restaurants
      end

      def show
        render json: @restaurant
      end

      def create
        @restaurant = Restaurant.new(restaurant_params)
        
        if @restaurant.save
          render json: @restaurant, status: :created
        else
          render json: { errors: @restaurant.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @restaurant.update(restaurant_params)
          render json: @restaurant
        else
          render json: { errors: @restaurant.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @restaurant.destroy
        head :no_content
      end

      def dashboard
        @restaurant = current_restaurant
        return head :forbidden unless @restaurant

        dashboard_data = {
          restaurant: @restaurant,
          stats: {
            total_employees: @restaurant.total_employees,
            total_transactions_today: @restaurant.total_transactions_today,
            daily_sales_today: @restaurant.daily_sales_today,
            active_discounts: @restaurant.discounts.active.count
          },
          recent_transactions: @restaurant.transactions.recent.limit(5),
          top_employees: @restaurant.employees.joins(:transactions)
                                   .group('employees.id')
                                   .order('SUM(transactions.amount) DESC')
                                   .limit(5)
        }

        render json: dashboard_data
      end

      private

      def set_restaurant
        @restaurant = Restaurant.find(params[:id])
      end

      def restaurant_params
        params.require(:restaurant).permit(:name, :address, :phone, :email, :status, :settings)
      end

      def authorize_restaurant_access!
        unless current_user.can_access_restaurant?(@restaurant.id)
          raise Pundit::NotAuthorizedError, "Access denied to restaurant"
        end
      end

      def authorize_restaurant_management!
        unless current_user.admin? || current_user.super_admin?
          raise Pundit::NotAuthorizedError, "Only admins can manage restaurants"
        end
      end
    end
  end
end
