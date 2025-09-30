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

  # Segment mapping methods
  def segment_mappings
    settings&.dig('segment_mappings') || {}
  end

  def segment_mappings=(mappings)
    self.settings ||= {}
    self.settings['segment_mappings'] = mappings
  end

  def everyone_list_id
    segment_mappings['everyone_list_id']
  end

  def everyone_list_id=(list_id)
    mappings = segment_mappings.dup
    mappings['everyone_list_id'] = list_id
    self.segment_mappings = mappings
  end

  def customer_list_id
    segment_mappings['customer_list_id']
  end

  def customer_list_id=(list_id)
    mappings = segment_mappings.dup
    mappings['customer_list_id'] = list_id
    self.segment_mappings = mappings
  end

  def rep_list_id
    segment_mappings['rep_list_id']
  end

  def rep_list_id=(list_id)
    mappings = segment_mappings.dup
    mappings['rep_list_id'] = list_id
    self.segment_mappings = mappings
  end

  def get_list_name(list_id)
    return nil unless list_id.present?
    
    list = brevo_lists.find { |l| l['id'] == list_id.to_i }
    list&.dig('name')
  end

  # Folder management methods
  def brevo_folder_id
    settings&.dig('brevo_folder_id')
  end

  def brevo_folder_id=(folder_id)
    self.settings ||= {}
    self.settings['brevo_folder_id'] = folder_id
  end

  def get_or_create_brevo_folder!
    return brevo_folder_id if brevo_folder_id.present?
    
    begin
      # Try to find existing folder with our name
      folders_response = brevo_client.get_folders
      folders = folders_response['folders'] || []
      
      existing_folder = folders.find { |folder| folder['name'] == 'FluidBrevoDropletContacts' }
      
      if existing_folder
        self.brevo_folder_id = existing_folder['id']
        save!
        return existing_folder['id']
      else
        # Create new folder
        folder_response = brevo_client.create_folder({ name: 'FluidBrevoDropletContacts' })
        
        if folder_response && folder_response['id']
          self.brevo_folder_id = folder_response['id']
          save!
          return folder_response['id']
        else
          raise "Failed to create folder: #{folder_response}"
        end
      end
    rescue => e
      Rails.logger.error "Error getting or creating Brevo folder: #{e.message}"
      raise "Failed to get or create folder: #{e.message}"
    end
  end
end
