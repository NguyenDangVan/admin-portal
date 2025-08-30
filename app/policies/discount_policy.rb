class DiscountPolicy < ApplicationPolicy
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

  def calculate?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    return true if user.staff? && same_restaurant?
    false
  end

  def summary?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def bulk_update?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def activate?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def deactivate?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def extend?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def view_analytics?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end
end
