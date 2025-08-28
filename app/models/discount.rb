class Discount < ApplicationRecord
  # Associations
  belongs_to :restaurant
  has_many :audit_logs, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :discount_type, presence: true
  validates :value, presence: true, numericality: { greater_than: 0 }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date
  validate :value_within_bounds

  # Enums
  enum discount_type: { 
    percentage: 0, 
    fixed_amount: 1, 
    buy_one_get_one: 2, 
    free_delivery: 3, 
    loyalty_reward: 4 
  }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Date.current, Date.current) }
  scope :by_type, ->(type) { where(discount_type: type) }
  scope :expired, -> { where('end_date < ?', Date.current) }
  scope :upcoming, -> { where('start_date > ?', Date.current) }

  # Callbacks
  before_create :generate_uuid
  after_create :log_discount_creation
  after_update :log_discount_update

  # Instance methods
  def is_current?
    start_date <= Date.current && end_date >= Date.current
  end

  def is_expired?
    end_date < Date.current
  end

  def is_upcoming?
    start_date > Date.current
  end

  def formatted_value
    if percentage?
      "#{value}%"
    else
      "$#{format('%.2f', value)}"
    end
  end

  def calculate_discount(original_amount)
    case discount_type
    when 'percentage'
      (original_amount * value / 100.0).round(2)
    when 'fixed_amount'
      [value, original_amount].min
    when 'buy_one_get_one'
      original_amount / 2.0
    when 'free_delivery'
      0 # Delivery fee would be subtracted elsewhere
    when 'loyalty_reward'
      value
    else
      0
    end
  end

  def final_price(original_amount)
    discount_amount = calculate_discount(original_amount)
    (original_amount - discount_amount).round(2)
  end

  def days_remaining
    return 0 if is_expired?
    (end_date - Date.current).to_i
  end

  def status_summary
    if is_expired?
      'Expired'
    elsif is_upcoming?
      "Starts in #{days_remaining} days"
    else
      "Active for #{days_remaining} more days"
    end
  end

  def summary
    {
      id: id,
      name: name,
      type: discount_type.humanize,
      value: formatted_value,
      status: status_summary,
      start_date: start_date.strftime('%Y-%m-%d'),
      end_date: end_date.strftime('%Y-%m-%d'),
      active: active
    }
  end

  private

  def generate_uuid
    self.id = SecureRandom.uuid if id.blank?
  end

  def end_date_after_start_date
    return unless start_date && end_date
    if end_date <= start_date
      errors.add(:end_date, 'must be after start date')
    end
  end

  def value_within_bounds
    return unless value
    case discount_type
    when 'percentage'
      if value > 100
        errors.add(:value, 'percentage cannot exceed 100%')
      end
    when 'fixed_amount'
      if value > 1000
        errors.add(:value, 'fixed amount cannot exceed $1000')
      end
    end
  end

  def log_discount_creation
    AuditLog.create!(
      restaurant_id: restaurant_id,
      user_id: nil, # Will be set by the current user context
      action: 'discount_created',
      auditable_type: 'Discount',
      auditable_id: id,
      changes: { 
        name: name, 
        discount_type: discount_type, 
        value: value,
        restaurant_id: restaurant_id 
      },
      metadata: { ip_address: 'system', user_agent: 'system' }
    )
  end

  def log_discount_update
    AuditLog.create!(
      restaurant_id: restaurant_id,
      user_id: nil, # Will be set by the current user context
      action: 'discount_updated',
      auditable_type: 'Discount',
      auditable_id: id,
      changes: changes,
      metadata: { ip_address: 'system', user_agent: 'system' }
    )
  end
end
