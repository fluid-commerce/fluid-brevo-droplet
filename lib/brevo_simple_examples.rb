# frozen_string_literal: true

# Simple Brevo Integration Examples
# This file demonstrates the simplified service class usage

class BrevoSimpleExamples
  # Example 1: Send a transactional email
  def self.send_welcome_email(company, user_email, user_name)
    return false unless company.integration_setting&.credentials&.dig('brevo', 'api_key').present?

    email_service = Brevo::EmailService.new(company.integration_setting.credentials.dig('brevo', 'api_key'))
    
    html_content = <<~HTML
      <h1>Welcome to #{company.name}!</h1>
      <p>Hello #{user_name},</p>
      <p>Thank you for joining us. We're excited to have you on board!</p>
    HTML

    email_service.send_transactional_email(
      sender_name: company.name,
      sender_email: "noreply@#{company.fluid_shop}",
      recipients: [{ email: user_email, name: user_name }],
      subject: "Welcome to #{company.name}!",
      html_content: html_content
    )
  rescue BrevoApiError => e
    Rails.logger.error "Failed to send welcome email: #{e.message}"
    false
  end

  # Example 2: Create a contact
  def self.create_customer_contact(company, email, first_name, last_name, phone = nil)
    return false unless company.integration_setting&.credentials&.dig('brevo', 'api_key').present?

    contact_service = Brevo::ContactService.new(company.integration_setting.credentials.dig('brevo', 'api_key'))
    
    contact_service.create_contact(
      email: email,
      attributes: {
        'FIRSTNAME' => first_name,
        'LASTNAME' => last_name,
        'SMS' => phone
      }.compact,
      list_ids: [1], # Replace with your actual list ID
      update_enabled: true
    )
  rescue BrevoApiError => e
    Rails.logger.error "Failed to create contact: #{e.message}"
    false
  end

  # Example 3: Test API connection
  def self.test_connection(company)
    return false unless company.integration_setting&.credentials&.dig('brevo', 'api_key').present?

    brevo_client = BrevoClient.new(company.integration_setting.credentials.dig('brevo', 'api_key'))
    account_info = brevo_client.get_account
    account_limits = brevo_client.get_account_limits
    
    {
      valid: true,
      account: account_info,
      limits: account_limits
    }
  rescue BrevoApiError => e
    {
      valid: false,
      error: e.message,
      status_code: e.status_code
    }
  end

  # Example 4: Get available lists
  def self.get_available_lists(company)
    return false unless company.integration_setting&.credentials&.dig('brevo', 'api_key').present?

    brevo_client = BrevoClient.new(company.integration_setting.credentials.dig('brevo', 'api_key'))
    lists_response = brevo_client.get_lists
    lists_response['lists'] || []
  rescue BrevoApiError => e
    Rails.logger.error "Failed to get lists: #{e.message}"
    []
  end

  # Example 5: Sync customers in batch
  def self.sync_customers_batch(company, customers, list_id)
    return false unless company.integration_setting&.credentials&.dig('brevo', 'api_key').present?

    # Transform customers to Brevo format
    brevo_contacts = customers.map do |customer|
      {
        email: customer.email,
        attributes: {
          'FIRSTNAME' => customer.first_name,
          'LASTNAME' => customer.last_name,
          'SMS' => customer.phone,
          'COMPANY' => customer.company_name,
          'CUSTOMER_TYPE' => customer.customer_type,
          'RANK' => customer.rank,
          'SPONSOR_ID' => customer.sponsor_id,
          'FLUID_SHOP' => customer.fluid_shop
        }.compact
      }
    end

    brevo_client = BrevoClient.new(company.integration_setting.credentials.dig('brevo', 'api_key'))
    brevo_client.create_contacts_batch({
      contacts: brevo_contacts,
      listIds: [list_id],
      updateExistingContacts: true
    })
  rescue BrevoApiError => e
    Rails.logger.error "Failed to sync customers: #{e.message}"
    false
  end
end
