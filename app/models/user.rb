class User < ApplicationRecord
  # Associations
  belongs_to :restaurant, optional: true
  has_many :audit_logs, dependent: :destroy

  # Validations
  validates :supabase_uid, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :role, presence: true

  # Enums
  enum role: { staff: 0, manager: 1, admin: 2, super_admin: 3 }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_role, ->(role) { where(role: role) }
  scope :by_restaurant, ->(restaurant_id) { where(restaurant_id: restaurant_id) }

  # Callbacks
  before_create :generate_uuid
  after_create :log_user_creation

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def admin?
    role.in?(%w[admin super_admin])
  end

  def manager?
    role.in?(%w[manager admin super_admin])
  end

  def can_manage_restaurant?(restaurant_id)
    return true if super_admin?
    return true if admin? && self.restaurant_id == restaurant_id
    return true if manager? && self.restaurant_id == restaurant_id
    false
  end

  def can_access_restaurant?(restaurant_id)
    return true if super_admin?
    return true if self.restaurant_id == restaurant_id
    false
  end

  def permissions
    case role
    when 'staff'
      %w[read_own_data read_restaurant_basic]
    when 'manager'
      %w[read_own_data read_restaurant_basic read_employees read_transactions read_reports manage_employees]
    when 'admin'
      %w[read_own_data read_restaurant_basic read_employees read_transactions read_reports manage_employees manage_restaurant_settings]
    when 'super_admin'
      %w[read_own_data read_restaurant_basic read_employees read_transactions read_reports manage_employees manage_restaurant_settings manage_all_restaurants]
    else
      []
    end
  end

  private

  def generate_uuid
    self.id = SecureRandom.uuid if id.blank?
  end

  def log_user_creation
    AuditLog.create!(
      restaurant_id: restaurant_id,
      user_id: id,
      action: 'user_created',
      auditable_type: 'User',
      auditable_id: id,
      changes: { email: email, role: role, restaurant_id: restaurant_id },
      metadata: { ip_address: 'system', user_agent: 'system' }
    )
  end
end
