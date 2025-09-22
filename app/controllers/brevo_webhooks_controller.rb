# frozen_string_literal: true

class BrevoWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:receive]
  before_action :verify_webhook_signature, only: [:receive]

  def receive
    case webhook_type
    when 'transactional'
      handle_transactional_webhook
    when 'marketing'
      handle_marketing_webhook
    when 'inbound'
      handle_inbound_webhook
    else
      Rails.logger.warn "Unknown webhook type: #{webhook_type}"
      head :ok
    end

    head :ok
  rescue => e
    Rails.logger.error "Brevo webhook error: #{e.message}"
    head :unprocessable_entity
  end

  private

  def verify_webhook_signature
    return true if Rails.env.development? # Skip verification in development
    
    signature = request.headers['X-Brevo-Signature']
    return head :unauthorized unless signature

    expected_signature = calculate_signature(request.body.read)
    return head :unauthorized unless Rack::Utils.secure_compare(signature, expected_signature)
  end

  def calculate_signature(payload)
    secret = Rails.application.config.brevo.webhook_secret
    return nil unless secret

    OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
  end

  def webhook_type
    params[:type] || 'transactional'
  end

  def handle_transactional_webhook
    # Handle transactional email events (sent, delivered, opened, clicked, etc.)
    event_data = {
      event: params[:event],
      email: params[:email],
      message_id: params[:messageId],
      timestamp: params[:timestamp],
      company_id: find_company_by_email(params[:email])
    }

    # Process the event (e.g., update database, trigger other actions)
    Rails.logger.info "Transactional webhook received: #{event_data}"
    
    # You can add specific logic here based on the event type
    case params[:event]
    when 'sent'
      handle_email_sent(event_data)
    when 'delivered'
      handle_email_delivered(event_data)
    when 'opened'
      handle_email_opened(event_data)
    when 'clicked'
      handle_email_clicked(event_data)
    when 'bounced'
      handle_email_bounced(event_data)
    when 'complained'
      handle_email_complained(event_data)
    end
  end

  def handle_marketing_webhook
    # Handle marketing campaign events
    event_data = {
      event: params[:event],
      email: params[:email],
      campaign_id: params[:campaignId],
      timestamp: params[:timestamp],
      company_id: find_company_by_email(params[:email])
    }

    Rails.logger.info "Marketing webhook received: #{event_data}"
    
    case params[:event]
    when 'opened'
      handle_campaign_opened(event_data)
    when 'clicked'
      handle_campaign_clicked(event_data)
    when 'unsubscribed'
      handle_campaign_unsubscribed(event_data)
    end
  end

  def handle_inbound_webhook
    # Handle inbound email parsing webhooks
    event_data = {
      event: params[:event],
      from: params[:from],
      to: params[:to],
      subject: params[:subject],
      text_content: params[:textContent],
      html_content: params[:htmlContent],
      attachments: params[:attachments],
      timestamp: params[:timestamp]
    }

    Rails.logger.info "Inbound webhook received: #{event_data}"
    # Process inbound email
  end

  def find_company_by_email(email)
    # Find company based on email domain or other logic
    # This is a placeholder - implement based on your business logic
    Company.joins(:integration_settings)
           .where("integration_settings.credentials->>'brevo'->>'api_key' IS NOT NULL")
           .first&.id
  end

  # Event handlers - implement based on your business requirements
  def handle_email_sent(event_data)
    # Track email sent event
  end

  def handle_email_delivered(event_data)
    # Track email delivered event
  end

  def handle_email_opened(event_data)
    # Track email opened event
  end

  def handle_email_clicked(event_data)
    # Track email clicked event
  end

  def handle_email_bounced(event_data)
    # Handle bounced email
  end

  def handle_email_complained(event_data)
    # Handle spam complaint
  end

  def handle_campaign_opened(event_data)
    # Track campaign opened event
  end

  def handle_campaign_clicked(event_data)
    # Track campaign clicked event
  end

  def handle_campaign_unsubscribed(event_data)
    # Handle unsubscription
  end
end
