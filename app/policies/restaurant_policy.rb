class RestaurantPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.admin?
        scope.where(id: user.restaurant_id)
      else
        scope.none
      end
    end
  end

  def index?
    user.present?
  end

  def show?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    return true if user.staff? && same_restaurant?
    false
  end

  def create?
    user.admin? || user.super_admin?
  end

  def update?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    false
  end

  def destroy?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    false
  end

  def dashboard?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def manage_settings?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    false
  end

  def view_analytics?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end

  def export_data?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if user.manager? && same_restaurant?
    false
  end
end
