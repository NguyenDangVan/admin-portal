module Api
  module V1
    class DiscountsController < ApplicationController
      before_action :set_restaurant
      before_action :set_discount, only: [:show, :update, :destroy]
      before_action :authorize_discount_access!, only: [:show]
      before_action :authorize_discount_management!, only: [:create, :update, :destroy]

      def index
        @discounts = @restaurant.discounts.order(:start_date, :end_date)

        # Apply filters
        @discounts = @discounts.by_type(params[:discount_type]) if params[:discount_type].present?
        @discounts = @discounts.active if params[:active] == 'true'
        @discounts = @discounts.current if params[:current] == 'true'
        @discounts = @discounts.expired if params[:expired] == 'true'
        @discounts = @discounts.upcoming if params[:upcoming] == 'true'

        render_paginated @discounts
      end

      def show
        render json: {
          discount: @discount,
          status: @discount.status_summary,
          days_remaining: @discount.days_remaining
        }
      end

      def create
        @discount = @restaurant.discounts.build(discount_params)
        
        if @discount.save
          render json: @discount, status: :created
        else
          render json: { errors: @discount.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @discount.update(discount_params)
          render json: @discount
        else
          render json: { errors: @discount.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @discount.update(active: false)
        head :no_content
      end

      def calculate
        amount = params[:amount]&.to_f
        return render json: { error: 'Amount is required' }, status: :unprocessable_entity unless amount

        applicable_discounts = @restaurant.discounts.active.current.select do |discount|
          discount.conditions['min_order'].to_f <= amount
        end

        if applicable_discounts.empty?
          render json: { 
            original_amount: amount,
            final_amount: amount,
            discount_applied: 0,
            applicable_discounts: []
          }
          return
        end

        # Find the best discount (highest savings)
        best_discount = applicable_discounts.max_by { |discount| discount.calculate_discount(amount) }
        discount_amount = best_discount.calculate_discount(amount)
        final_amount = best_discount.final_price(amount)

        render json: {
          original_amount: amount,
          final_amount: final_amount,
          discount_applied: discount_amount,
          discount_used: best_discount.summary,
          applicable_discounts: applicable_discounts.map(&:summary)
        }
      end

      def summary
        summary = {
          total_discounts: @restaurant.discounts.count,
          active_discounts: @restaurant.discounts.active.count,
          current_discounts: @restaurant.discounts.current.count,
          expired_discounts: @restaurant.discounts.expired.count,
          upcoming_discounts: @restaurant.discounts.upcoming.count,
          by_type: @restaurant.discounts.group(:discount_type).count,
          expiring_soon: @restaurant.discounts.active
                                    .where('end_date <= ?', 7.days.from_now)
                                    .order(:end_date)
                                    .limit(5)
        }

        render json: summary
      end

      def bulk_update
        discount_ids = params[:discount_ids]
        action = params[:action_type]

        return render json: { error: 'Invalid action' }, status: :unprocessable_entity unless %w[activate deactivate extend].include?(action)

        discounts = @restaurant.discounts.where(id: discount_ids)
        
        case action
        when 'activate'
          discounts.update_all(active: true)
        when 'deactivate'
          discounts.update_all(active: false)
        when 'extend'
          extension_days = params[:extension_days]&.to_i || 30
          discounts.each { |d| d.update(end_date: d.end_date + extension_days.days) }
        end

        render json: { message: "#{action.humanize} completed for #{discounts.count} discounts" }
      end

      private

      def set_restaurant
        @restaurant = current_restaurant
        head :forbidden unless @restaurant
      end

      def set_discount
        @discount = @restaurant.discounts.find(params[:id])
      end

      def discount_params
        params.require(:discount).permit(
          :name, :description, :discount_type, :value, :is_percentage,
          :start_date, :end_date, :active, :conditions
        )
      end

      def authorize_discount_access!
        unless current_user.can_access_restaurant?(@restaurant.id)
          raise Pundit::NotAuthorizedError, "Access denied to discount data"
        end
      end

      def authorize_discount_management!
        unless current_user.manager? || current_user.admin? || current_user.super_admin?
          raise Pundit::NotAuthorizedError, "Only managers and admins can manage discounts"
        end
      end
    end
  end
end
