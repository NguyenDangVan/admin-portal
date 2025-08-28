class Transaction < ApplicationRecord
  # Associations
  belongs_to :restaurant
  belongs_to :employee
  has_many :audit_logs, dependent: :destroy

  # Validations
  validates :transaction_id, presence: true, uniqueness: { scope: :restaurant_id }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_method, presence: true
  validates :status, presence: true
  validates :transaction_time, presence: true
  validates :items, presence: true

  # Enums
  enum payment_method: { 
    cash: 0, 
    credit_card: 1, 
    debit_card: 2, 
    mobile_payment: 3, 
    gift_card: 4, 
    check: 5 
  }

  enum status: { 
    pending: 0, 
    completed: 1, 
    failed: 2, 
    refunded: 3, 
    cancelled: 4 
  }

  # Scopes
  scope :completed, -> { where(status: :completed) }
  scope :by_date, ->(date) { where(transaction_time: date.beginning_of_day..date.end_of_day) }
  scope :by_employee, ->(employee_id) { where(employee_id: employee_id) }
  scope :by_payment_method, ->(method) { where(payment_method: method) }
  scope :high_value, -> { where('amount > ?', 100) }
  scope :recent, -> { where('transaction_time >= ?', 24.hours.ago) }

  # Callbacks
  before_create :generate_uuid
  after_create :log_transaction_creation
  after_update :log_transaction_update

  # Instance methods
  def total_items
    items.sum { |item| item['quantity'] || 1 }
  end

  def item_count
    items.length
  end

  def is_high_value?
    amount > 100
  end

  def is_recent?
    transaction_time >= 24.hours.ago
  end

  def formatted_amount
    "$#{format('%.2f', amount)}"
  end

  def formatted_transaction_time
    transaction_time.strftime('%Y-%m-%d %H:%M:%S')
  end

  def summary
    {
      id: transaction_id,
      amount: formatted_amount,
      employee: employee.full_name,
      payment_method: payment_method.humanize,
      status: status.humanize,
      time: formatted_transaction_time,
      items_count: item_count
    }
  end

  def self.daily_sales_report(restaurant_id, date = Date.current)
    where(restaurant_id: restaurant_id, status: :completed)
      .where(transaction_time: date.beginning_of_day..date.end_of_day)
      .group(:payment_method)
      .sum(:amount)
  end

  def self.employee_performance(restaurant_id, start_date = 30.days.ago, end_date = Date.current)
    where(restaurant_id: restaurant_id, status: :completed)
      .where(transaction_time: start_date.beginning_of_day..end_date.end_of_day)
      .group(:employee_id)
      .select('employee_id, COUNT(*) as transaction_count, SUM(amount) as total_sales, AVG(amount) as avg_transaction')
  end

  private

  def generate_uuid
    self.id = SecureRandom.uuid if id.blank?
  end

  def log_transaction_creation
    AuditLog.create!(
      restaurant_id: restaurant_id,
      user_id: nil, # Will be set by the current user context
      action: 'transaction_created',
      auditable_type: 'Transaction',
      auditable_id: id,
      changes: { 
        transaction_id: transaction_id, 
        amount: amount, 
        employee_id: employee_id,
        restaurant_id: restaurant_id 
      },
      metadata: { ip_address: 'system', user_agent: 'system' }
    )
  end

  def log_transaction_update
    AuditLog.create!(
      restaurant_id: restaurant_id,
      user_id: nil, # Will be set by the current user context
      action: 'transaction_updated',
      auditable_type: 'Transaction',
      auditable_id: id,
      changes: changes,
      metadata: { ip_address: 'system', user_agent: 'system' }
    )
  end
end
