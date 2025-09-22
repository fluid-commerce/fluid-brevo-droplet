# frozen_string_literal: true

# Brevo Integration Examples
# This file demonstrates how to use the Brevo integration in your Rails application

class BrevoIntegrationExamples
  # Example 1: Send a transactional email
  def self.send_welcome_email(company, user_email, user_name)
    html_content = <<~HTML
      <h1>Welcome to #{company.name}!</h1>
      <p>Hello #{user_name},</p>
      <p>Thank you for joining us. We're excited to have you on board!</p>
      <p>Best regards,<br>The #{company.name} Team</p>
    HTML

    text_content = <<~TEXT
      Welcome to #{company.name}!
      
      Hello #{user_name},
      
      Thank you for joining us. We're excited to have you on board!
      
      Best regards,
      The #{company.name} Team
    TEXT

    result = Brevo::EmailService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'send_transactional',
      sender_name: company.name,
      sender_email: "noreply@#{company.fluid_shop}",
      recipients: [{ email: user_email, name: user_name }],
      subject: "Welcome to #{company.name}!",
      html_content: html_content,
      text_content: text_content
    )

    if result.success?
      Rails.logger.info "Welcome email sent to #{user_email}"
      result.email_result
    else
      Rails.logger.error "Failed to send welcome email: #{result.message}"
      nil
    end
  end

  # Example 2: Create a contact
  def self.create_customer_contact(company, email, attributes = {})
    contact_attributes = {
      'FIRSTNAME' => attributes[:first_name],
      'LASTNAME' => attributes[:last_name],
      'SMS' => attributes[:phone],
      'COMPANY' => attributes[:company_name],
      'WEBSITE' => attributes[:website]
    }.compact

    result = Brevo::ContactService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'create',
      email: email,
      attributes: contact_attributes,
      list_ids: [1], # Replace with your actual list ID
      update_enabled: true
    )

    if result.success?
      Rails.logger.info "Contact created for #{email}"
      result.contact_result
    else
      Rails.logger.error "Failed to create contact: #{result.message}"
      nil
    end
  end

  # Example 3: Create and send an email campaign
  def self.send_newsletter_campaign(company, subject, html_content, recipient_list_id)
    # First, create the campaign
    campaign_result = Brevo::CampaignService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'create',
      name: "Newsletter - #{Date.current.strftime('%B %Y')}",
      subject: subject,
      sender_name: company.name,
      sender_email: "newsletter@#{company.fluid_shop}",
      html_content: html_content,
      recipients: { listIds: [recipient_list_id] },
      type: 'classic'
    )

    if campaign_result.success?
      campaign_id = campaign_result.campaign_result['id']
      
      # Then send the campaign
      send_result = Brevo::CampaignService.call(
        api_key: company.integration_setting.brevo_api_key,
        action: 'send',
        campaign_id: campaign_id
      )

      if send_result.success?
        Rails.logger.info "Newsletter campaign sent successfully"
        send_result.campaign_result
      else
        Rails.logger.error "Failed to send campaign: #{send_result.message}"
        nil
      end
    else
      Rails.logger.error "Failed to create campaign: #{campaign_result.message}"
      nil
    end
  end

  # Example 4: Set up webhooks for tracking
  def self.setup_tracking_webhooks(company)
    webhook_url = Rails.application.routes.url_helpers.brevo_webhook_url(host: Rails.application.config.action_mailer.default_url_options[:host])
    
    # Create webhook for transactional emails
    transactional_webhook = Brevo::WebhookService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'create',
      url: webhook_url,
      events: ['sent', 'delivered', 'opened', 'clicked', 'bounced', 'complained'],
      description: "Transactional email tracking for #{company.name}",
      type: 'transactional'
    )

    # Create webhook for marketing campaigns
    marketing_webhook = Brevo::WebhookService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'create',
      url: webhook_url,
      events: ['opened', 'clicked', 'unsubscribed'],
      description: "Marketing campaign tracking for #{company.name}",
      type: 'marketing'
    )

    if transactional_webhook.success? && marketing_webhook.success?
      Rails.logger.info "Webhooks set up successfully for #{company.name}"
      {
        transactional_webhook: transactional_webhook.webhook_result,
        marketing_webhook: marketing_webhook.webhook_result
      }
    else
      Rails.logger.error "Failed to set up webhooks: #{transactional_webhook.message} | #{marketing_webhook.message}"
      nil
    end
  end

  # Example 5: Import contacts from CSV
  def self.import_contacts_from_csv(company, csv_file_path, list_id)
    # Read and process CSV file
    csv_data = CSV.read(csv_file_path, headers: true)
    
    # Convert CSV to Brevo format
    contacts_data = csv_data.map do |row|
      {
        email: row['email'],
        attributes: {
          'FIRSTNAME' => row['first_name'],
          'LASTNAME' => row['last_name'],
          'SMS' => row['phone']
        }.compact
      }
    end

    # Prepare import parameters
    import_params = {
      fileBody: contacts_data.to_json,
      listIds: [list_id],
      updateExistingContacts: true,
      emptyContactsAttributes: false
    }

    result = Brevo::ContactService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'import',
      file_body: contacts_data.to_json,
      list_ids: [list_id],
      update_existing_contacts: true
    )

    if result.success?
      Rails.logger.info "Contacts imported successfully"
      result.contact_result
    else
      Rails.logger.error "Failed to import contacts: #{result.message}"
      nil
    end
  end

  # Example 6: Get campaign analytics
  def self.get_campaign_analytics(company, campaign_id)
    result = Brevo::CampaignService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'report',
      campaign_id: campaign_id
    )

    if result.success?
      report = result.campaign_result
      {
        sent: report['sent'],
        delivered: report['delivered'],
        opened: report['opened'],
        clicked: report['clicked'],
        bounced: report['bounced'],
        complained: report['complained'],
        unsubscribed: report['unsubscribed']
      }
    else
      Rails.logger.error "Failed to get campaign analytics: #{result.message}"
      nil
    end
  end

  # Example 7: Update contact information
  def self.update_customer_contact(company, email, new_attributes)
    result = Brevo::ContactService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'update',
      identifier: email,
      attributes: new_attributes,
      update_enabled: true
    )

    if result.success?
      Rails.logger.info "Contact updated for #{email}"
      result.contact_result
    else
      Rails.logger.error "Failed to update contact: #{result.message}"
      nil
    end
  end

  # Example 8: Send batch emails with personalization
  def self.send_personalized_batch_emails(company, recipients_data)
    recipients = recipients_data.map do |data|
      {
        email: data[:email],
        name: data[:name],
        params: {
          'FIRSTNAME' => data[:first_name],
          'LASTNAME' => data[:last_name],
          'ORDER_NUMBER' => data[:order_number]
        }
      }
    end

    html_content = <<~HTML
      <h1>Hello {{ params.FIRSTNAME }},</h1>
      <p>Thank you for your order #{{ params.ORDER_NUMBER }}!</p>
      <p>We'll keep you updated on your order status.</p>
    HTML

    result = Brevo::EmailService.call(
      api_key: company.integration_setting.brevo_api_key,
      action: 'send_batch',
      sender_name: company.name,
      sender_email: "orders@#{company.fluid_shop}",
      recipients: recipients,
      subject: "Order Confirmation #{{ params.ORDER_NUMBER }}",
      html_content: html_content
    )

    if result.success?
      Rails.logger.info "Batch emails sent to #{recipients.length} recipients"
      result.email_result
    else
      Rails.logger.error "Failed to send batch emails: #{result.message}"
      nil
    end
  end
end
