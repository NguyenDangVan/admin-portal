class Employee < ApplicationRecord
  # Associations
  belongs_to :restaurant
  has_many :transactions, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  # Validations
  validates :employee_id, presence: true, uniqueness: { scope: :restaurant_id }
  validates :first_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :hourly_rate, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :hire_date, presence: true

  # Enums
  enum position: { 
    cashier: 0, 
    server: 1, 
    cook: 2, 
    manager: 3, 
    supervisor: 4, 
    host: 5, 
    bartender: 6 
  }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_position, ->(position) { where(position: position) }
  scope :by_restaurant, ->(restaurant_id) { where(restaurant_id: restaurant_id) }
  scope :recently_hired, -> { where('hire_date >= ?', 30.days.ago) }

  # Callbacks
  before_create :generate_uuid
  after_create :log_employee_creation
  after_update :log_employee_update

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def total_transactions
    transactions.count
  end

  def total_sales
    transactions.sum(:amount)
  end

  def average_transaction_value
    return 0 if transactions.empty?
    total_sales / total_transactions
  end

  def today_transactions
    transactions.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
  end

  def today_sales
    today_transactions.sum(:amount)
  end

  def years_of_service
    return 0 unless hire_date
    ((Time.current - hire_date.to_time) / 1.year).floor
  end

  def monthly_salary
    return 0 unless hourly_rate
    hourly_rate * 160 # Assuming 40 hours per week, 4 weeks per month
  end

  private

  def generate_uuid
    self.id = SecureRandom.uuid if id.blank?
  end

  def log_employee_creation
    AuditLog.create!(
      restaurant_id: restaurant_id,
      user_id: nil, # Will be set by the current user context
      action: 'employee_created',
      auditable_type: 'Employee',
      auditable_id: id,
      changes: { 
        employee_id: employee_id, 
        first_name: first_name, 
        last_name: last_name, 
        position: position,
        restaurant_id: restaurant_id 
      },
      metadata: { ip_address: 'system', user_agent: 'system' }
    )
  end

  def log_employee_update
    AuditLog.create!(
      restaurant_id: restaurant_id,
      user_id: nil, # Will be set by the current user context
      action: 'employee_updated',
      auditable_type: 'Employee',
      auditable_id: id,
      changes: changes,
      metadata: { ip_address: 'system', user_agent: 'system' }
    )
  end
end
