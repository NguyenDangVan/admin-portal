class Restaurant < ApplicationRecord
  # Associations
  has_many :users, dependent: :destroy
  has_many :employees, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :discounts, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true
  validates :status, inclusion: { in: %w[active inactive suspended] }

  # Enums
  enum status: { active: 0, inactive: 1, suspended: 2 }

  # Scopes
  scope :active, -> { where(status: :active) }
  scope :by_name, ->(name) { where('name ILIKE ?', "%#{name}%") }

  # Callbacks
  before_create :generate_uuid
  after_create :create_default_settings

  # Instance methods
  def full_address
    [address, city, state, zip_code].compact.join(', ')
  end

  def total_employees
    employees.active.count
  end

  def total_transactions_today
    transactions.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day).count
  end

  def daily_sales_today
    transactions.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day).sum(:amount)
  end

  private

  def generate_uuid
    self.id = SecureRandom.uuid if id.blank?
  end

  def create_default_settings
    self.settings = {
      timezone: 'UTC',
      currency: 'USD',
      tax_rate: 0.0,
      service_charge: 0.0,
      business_hours: {
        monday: { open: '09:00', close: '17:00' },
        tuesday: { open: '09:00', close: '17:00' },
        wednesday: { open: '09:00', close: '17:00' },
        thursday: { open: '09:00', close: '17:00' },
        friday: { open: '09:00', close: '17:00' },
        saturday: { open: '10:00', close: '16:00' },
        sunday: { open: '10:00', close: '16:00' }
      }
    }
  end
end
