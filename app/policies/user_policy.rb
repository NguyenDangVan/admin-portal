class UserPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.admin?
        scope.where(restaurant_id: user.restaurant_id)
      else
        scope.none
      end
    end
  end

  def index?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    false
  end

  def show?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if record.id == user.id # Users can view their own profile
    false
  end

  def create?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    false
  end

  def update?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if record.id == user.id # Users can update their own profile
    false
  end

  def destroy?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return false if record.id == user.id # Users cannot delete themselves
    false
  end

  def change_role?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    false
  end

  def manage_permissions?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    false
  end

  def view_activity_log?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if record.id == user.id # Users can view their own activity
    false
  end

  def reset_password?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if record.id == user.id # Users can reset their own password
    false
  end

  def deactivate?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return false if record.id == user.id # Users cannot deactivate themselves
    false
  end

  def reactivate?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    false
  end

  def export_data?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if record.id == user.id # Users can export their own data
    false
  end

  def delete_data?
    return true if user.super_admin?
    return true if user.admin? && same_restaurant?
    return true if record.id == user.id # Users can delete their own data (GDPR)
    false
  end
end
