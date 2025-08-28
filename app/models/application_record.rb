class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Include UUID support
  before_create :generate_uuid, if: :uuid_primary_key?

  private

  def generate_uuid
    self.id = SecureRandom.uuid if id.blank?
  end

  def uuid_primary_key?
    self.class.primary_key_type == :uuid
  end
end
