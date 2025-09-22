# frozen_string_literal: true

class Brevo::ConfigurationService
  def initialize(api_key)
    @api_key = api_key
    @brevo_client = BrevoClient.new(api_key)
  end

  def validate_api_key
    begin
      account_info = @brevo_client.get_account
      account_limits = @brevo_client.get_account_limits
      
      {
        valid: true,
        account: {
          email: account_info['email'],
          firstName: account_info['firstName'],
          lastName: account_info['lastName'],
          companyName: account_info['companyName']
        },
        limits: {
          email: account_limits['email'],
          sms: account_limits['sms']
        }
      }
    rescue BrevoApiError => e
      {
        valid: false,
        error: e.message,
        status_code: e.status_code
      }
    end
  end

  def get_account_info
    begin
      account_info = @brevo_client.get_account
      account_limits = @brevo_client.get_account_limits
      
      {
        account: account_info,
        limits: account_limits
      }
    rescue BrevoApiError => e
      raise BrevoApiError.new("Failed to get account info: #{e.message}")
    end
  end

  def get_available_lists
    begin
      lists_response = @brevo_client.get_lists
      lists_response['lists'] || []
    rescue BrevoApiError => e
      raise BrevoApiError.new("Failed to get available lists: #{e.message}")
    end
  end

  def get_available_templates
    begin
      templates_response = @brevo_client.get_templates
      templates_response['templates'] || []
    rescue BrevoApiError => e
      raise BrevoApiError.new("Failed to get available templates: #{e.message}")
    end
  end

  def setup_default_configuration
    begin
      # Create MLM attributes
      fluid_sync_service = Brevo::FluidContactSyncService.new(@api_key)
      fluid_sync_service.setup_mlm_attributes
      
      # Create default lists
      fluid_sync_service.create_fluid_lists
      
      # Get the created lists
      lists_response = @brevo_client.get_lists
      fluid_lists = lists_response['lists'].select { |list| list['name'].start_with?('Fluid') }
      
      {
        success: true,
        created_lists: fluid_lists,
        message: "Default configuration setup completed successfully"
      }
    rescue => e
      raise BrevoApiError.new("Failed to setup default configuration: #{e.message}")
    end
  end

end
