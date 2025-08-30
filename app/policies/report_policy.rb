class ReportPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.admin? || user.manager?
        scope.where(restaurant_id: user.restaurant_id)
      else
        scope.none
      end
    end
  end

  def dashboard?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def sales_analytics?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def employee_performance?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def inventory_insights?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def financial_summary?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def export_report?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def view_revenue_data?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def view_employee_salaries?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def view_customer_data?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def generate_custom_reports?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def schedule_reports?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end
end
