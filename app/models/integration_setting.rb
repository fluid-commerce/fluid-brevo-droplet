# frozen_string_literal: true

class IntegrationSetting < ApplicationRecord
  belongs_to :company

  validates :company_id, presence: true

  encrypts :credentials, deterministic: true

  # Brevo integration methods
  def brevo_api_key
    credentials&.dig('brevo', 'api_key')
  end

  def brevo_api_key=(api_key)
    self.credentials ||= {}
    self.credentials['brevo'] ||= {}
    self.credentials['brevo']['api_key'] = api_key
  end

  def brevo_enabled?
    enabled? && brevo_api_key.present?
  end

  def brevo_client
    return nil unless brevo_enabled?
    
    @brevo_client ||= BrevoClient.new(brevo_api_key)
  end
end
