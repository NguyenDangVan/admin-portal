class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  private

  def admin?
    user.admin? || user.super_admin?
  end

  def manager?
    user.manager? || user.admin? || user.super_admin?
  end

  def super_admin?
    user.super_admin?
  end

  def same_restaurant?
    return true if user.super_admin?
    return true if record.respond_to?(:restaurant_id) && record.restaurant_id == user.restaurant_id
    return true if record.respond_to?(:restaurant) && record.restaurant.id == user.restaurant_id
    false
  end
end
