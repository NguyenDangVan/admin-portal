class TransactionPolicy < ApplicationPolicy
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

  def index?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    return true if user.staff? && same_restaurant?
    false
  end

  def show?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    return true if user.staff? && same_restaurant?
    false
  end

  def create?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    return true if user.staff? && same_restaurant?
    false
  end

  def update?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def destroy?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def daily_sales_report?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def sales_summary?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def import?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def refund?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def void?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def view_sensitive_data?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end
end
