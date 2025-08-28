class AuditLog < ApplicationRecord
  # Associations
  belongs_to :restaurant, optional: true
  belongs_to :user, optional: true

  # Validations
  validates :action, presence: true
  validates :changes, presence: true

  # Scopes
  scope :by_restaurant, ->(restaurant_id) { where(restaurant_id: restaurant_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_auditable, ->(type, id) { where(auditable_type: type, auditable_id: id) }
  scope :recent, -> { where('created_at >= ?', 24.hours.ago) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date.beginning_of_day..end_date.end_of_day) }

  # Callbacks
  before_create :generate_uuid
  before_create :set_metadata

  # Instance methods
  def auditable_summary
    return 'Unknown' unless auditable_type && auditable_id
    
    case auditable_type
    when 'User'
      "User #{auditable_id}"
    when 'Employee'
      "Employee #{auditable_id}"
    when 'Transaction'
      "Transaction #{auditable_id}"
    when 'Discount'
      "Discount #{auditable_id}"
    when 'Restaurant'
      "Restaurant #{auditable_id}"
    else
      "#{auditable_type} #{auditable_id}"
    end
  end

  def user_summary
    return 'System' unless user
    user.full_name
  end

  def restaurant_summary
    return 'System' unless restaurant
    restaurant.name
  end

  def formatted_changes
    changes.map do |field, values|
      if values.is_a?(Array)
        "#{field}: #{values[0]} → #{values[1]}"
      else
        "#{field}: #{values}"
      end
    end.join(', ')
  end

  def summary
    {
      id: id,
      action: action.humanize,
      user: user_summary,
      restaurant: restaurant_summary,
      auditable: auditable_summary,
      changes: formatted_changes,
      timestamp: created_at.strftime('%Y-%m-%d %H:%M:%S'),
      ip_address: metadata['ip_address'],
      user_agent: metadata['user_agent']
    }
  end

  def self.log_action(action, auditable, user = nil, changes = {}, additional_metadata = {})
    create!(
      restaurant_id: auditable.respond_to?(:restaurant_id) ? auditable.restaurant_id : nil,
      user_id: user&.id,
      action: action,
      auditable_type: auditable.class.name,
      auditable_id: auditable.id,
      changes: changes,
      metadata: additional_metadata
    )
  end

  def self.user_activity_log(user_id, start_date = 30.days.ago, end_date = Date.current)
    where(user_id: user_id)
      .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      .order(created_at: :desc)
  end

  def self.restaurant_activity_log(restaurant_id, start_date = 30.days.ago, end_date = Date.current)
    where(restaurant_id: restaurant_id)
      .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      .order(created_at: :desc)
  end

  def self.gdpr_export(user_id)
    where(user_id: user_id)
      .includes(:restaurant, :user)
      .order(created_at: :desc)
  end

  def self.anonymize_user_data(user_id)
    where(user_id: user_id).update_all(
      user_id: nil,
      metadata: { anonymized: true, original_user_id: user_id }
    )
  end

  private

  def generate_uuid
    self.id = SecureRandom.uuid if id.blank?
  end

  def set_metadata
    self.metadata ||= {}
    self.metadata['timestamp'] = Time.current.iso8601
    self.metadata['user_agent'] ||= 'System'
    self.metadata['ip_address'] ||= 'System'
  end
end
