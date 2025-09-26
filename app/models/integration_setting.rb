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
    brevo_api_key.present?
  end

  def brevo_client
    return nil unless brevo_enabled?
    
    @brevo_client ||= BrevoClient.new(brevo_api_key)
  end

  # List management methods
  def brevo_lists
    settings&.dig('lists') || []
  end

  def brevo_lists=(lists)
    self.settings ||= {}
    self.settings['lists'] = lists
  end

  def default_list_id
    settings&.dig('default_list_id')
  end

  def default_list_id=(list_id)
    self.settings ||= {}
    self.settings['default_list_id'] = list_id
  end

  def default_list_name
    return nil unless default_list_id.present?
    
    list = brevo_lists.find { |l| l['id'] == default_list_id }
    list&.dig('name')
  end

  def available_lists
    brevo_lists
  end

  def list_data_fresh?
    return false unless updated_at.present?
    updated_at > 1.hour.ago
  end

  def sync_brevo_lists!
    return false unless brevo_enabled?
    
    begin
      lists_response = brevo_client.get_lists
      self.brevo_lists = lists_response['lists'] || []
      save!
      true
    rescue => e
      Rails.logger.error "Failed to sync Brevo lists: #{e.message}"
      false
    end
  end
end
