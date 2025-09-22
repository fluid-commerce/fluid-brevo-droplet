# frozen_string_literal: true

module BrevoHelper
  # Send a transactional email
  def send_brevo_email(company, recipients, subject, html_content, text_content = nil, template_params = {})
    return false unless company.integration_setting&.brevo_enabled?

    email_service = Brevo::EmailService.new(company.integration_setting.brevo_api_key)
    email_service.send_transactional_email(
      sender_name: Rails.application.config.brevo.default_sender[:name],
      sender_email: Rails.application.config.brevo.default_sender[:email],
      recipients: recipients,
      subject: subject,
      html_content: html_content,
      text_content: text_content,
      template_params: template_params
    )
  end

  # Create a contact in Brevo
  def create_brevo_contact(company, email, attributes = {}, list_ids = [])
    return false unless company.integration_setting&.brevo_enabled?

    contact_service = Brevo::ContactService.new(company.integration_setting.brevo_api_key)
    contact_service.create_contact(
      email: email,
      attributes: attributes,
      list_ids: list_ids
    )
  end

  # Update a contact in Brevo
  def update_brevo_contact(company, identifier, attributes = {})
    return false unless company.integration_setting&.brevo_enabled?

    contact_service = Brevo::ContactService.new(company.integration_setting.brevo_api_key)
    contact_service.update_contact(
      identifier: identifier,
      attributes: attributes
    )
  end

  # Create an email campaign
  def create_brevo_campaign(company, name, subject, html_content, recipients = {})
    return false unless company.integration_setting&.brevo_enabled?

    Brevo::CampaignService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'create',
      name: name,
      subject: subject,
      sender_name: Rails.application.config.brevo.default_sender[:name],
      sender_email: Rails.application.config.brevo.default_sender[:email],
      html_content: html_content,
      recipients: recipients
    )
  end

  # Send a campaign
  def send_brevo_campaign(company, campaign_id)
    return false unless company.integration_setting&.brevo_enabled?

    Brevo::CampaignService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'send',
      campaign_id: campaign_id
    )
  end

  # Create a webhook
  def create_brevo_webhook(company, url, events = ['sent', 'delivered', 'opened', 'clicked'])
    return false unless company.integration_setting&.brevo_enabled?

    Brevo::WebhookService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'create',
      url: url,
      events: events,
      description: "Webhook for #{company.name}"
    )
  end

  # Get campaign report
  def get_brevo_campaign_report(company, campaign_id)
    return false unless company.integration_setting&.brevo_enabled?

    Brevo::CampaignService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'report',
      campaign_id: campaign_id
    )
  end

  # Fluid-specific helper methods

  # Test Brevo connection
  def test_brevo_connection(company)
    return false unless company.integration_setting&.brevo_enabled?

    config_service = Brevo::ConfigurationService.new(company.integration_setting.brevo_api_key)
    config_service.validate_api_key
  end

  # Sync Fluid customers to Brevo
  def sync_fluid_customers(company, customers, list_id = nil)
    return false unless company.integration_setting&.brevo_enabled?

    sync_service = Brevo::FluidContactSyncService.new(company.integration_setting.brevo_api_key)
    sync_service.sync_customers(customers: customers, list_id: list_id)
  end

  # Sync Fluid contacts to Brevo
  def sync_fluid_contacts(company, contacts, list_id = nil)
    return false unless company.integration_setting&.brevo_enabled?

    sync_service = Brevo::FluidContactSyncService.new(company.integration_setting.brevo_api_key)
    sync_service.sync_contacts(contacts: contacts, list_id: list_id)
  end

  # Setup MLM attributes in Brevo
  def setup_brevo_mlm_attributes(company)
    return false unless company.integration_setting&.brevo_enabled?

    sync_service = Brevo::FluidContactSyncService.new(company.integration_setting.brevo_api_key)
    sync_service.setup_mlm_attributes
  end

  # Create Fluid-specific lists in Brevo
  def create_brevo_fluid_lists(company)
    return false unless company.integration_setting&.brevo_enabled?

    sync_service = Brevo::FluidContactSyncService.new(company.integration_setting.brevo_api_key)
    sync_service.create_fluid_lists
  end

  # Get available Brevo lists
  def get_brevo_lists(company)
    return false unless company.integration_setting&.brevo_enabled?

    config_service = Brevo::ConfigurationService.new(company.integration_setting.brevo_api_key)
    config_service.get_available_lists
  end

  # Get available Brevo templates
  def get_brevo_templates(company)
    return false unless company.integration_setting&.brevo_enabled?

    config_service = Brevo::ConfigurationService.new(company.integration_setting.brevo_api_key)
    config_service.get_available_templates
  end

  # Setup default Brevo configuration for Fluid
  def setup_brevo_default_configuration(company)
    return false unless company.integration_setting&.brevo_enabled?

    config_service = Brevo::ConfigurationService.new(company.integration_setting.brevo_api_key)
    config_service.setup_default_configuration
  end
end
