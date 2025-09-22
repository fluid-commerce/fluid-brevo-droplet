# frozen_string_literal: true

class Brevo::CampaignService
  def initialize(api_key)
    @api_key = api_key
    @brevo_client = BrevoClient.new(api_key)
  end

  def create_campaign(name:, subject:, sender_name:, sender_email:, html_content:, text_content: nil, recipients: {}, type: 'classic', scheduled_at: nil, inline_image_activation: false, mirror_active: false, recurring: false, footer: '', header: '', utm_campaign: nil, params: {})
    campaign_params = build_campaign_params(
      name: name,
      subject: subject,
      sender_name: sender_name,
      sender_email: sender_email,
      html_content: html_content,
      text_content: text_content,
      recipients: recipients,
      type: type,
      scheduled_at: scheduled_at,
      inline_image_activation: inline_image_activation,
      mirror_active: mirror_active,
      recurring: recurring,
      footer: footer,
      header: header,
      utm_campaign: utm_campaign,
      params: params
    )
    
    @brevo_client.create_campaign(campaign_params)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to create campaign: #{e.message}")
  end

  def get_campaign(campaign_id)
    @brevo_client.get_campaign(campaign_id)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to get campaign: #{e.message}")
  end

  def update_campaign(campaign_id:, name: nil, subject: nil, sender_name: nil, sender_email: nil, html_content: nil, text_content: nil, recipients: nil, type: nil, scheduled_at: nil, inline_image_activation: nil, mirror_active: nil, recurring: nil, footer: nil, header: nil, utm_campaign: nil, params: nil)
    campaign_params = build_campaign_params(
      name: name,
      subject: subject,
      sender_name: sender_name,
      sender_email: sender_email,
      html_content: html_content,
      text_content: text_content,
      recipients: recipients,
      type: type,
      scheduled_at: scheduled_at,
      inline_image_activation: inline_image_activation,
      mirror_active: mirror_active,
      recurring: recurring,
      footer: footer,
      header: header,
      utm_campaign: utm_campaign,
      params: params
    ).compact
    
    @brevo_client.update_campaign(campaign_id, campaign_params)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to update campaign: #{e.message}")
  end

  def send_campaign(campaign_id)
    @brevo_client.send_campaign(campaign_id)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to send campaign: #{e.message}")
  end

  def get_campaign_report(campaign_id)
    @brevo_client.get_campaign_report(campaign_id)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to get campaign report: #{e.message}")
  end

  private

  def build_campaign_params(name:, subject:, sender_name:, sender_email:, html_content:, text_content:, recipients:, type:, scheduled_at:, inline_image_activation:, mirror_active:, recurring:, footer:, header:, utm_campaign:, params:)
    {
      'name' => name,
      'subject' => subject,
      'sender' => {
        'name' => sender_name,
        'email' => sender_email
      },
      'type' => type || 'classic',
      'htmlContent' => html_content,
      'textContent' => text_content,
      'recipients' => recipients || {},
      'scheduledAt' => scheduled_at,
      'inlineImageActivation' => inline_image_activation || false,
      'mirrorActive' => mirror_active || false,
      'recurring' => recurring || false,
      'footer' => footer || '',
      'header' => header || '',
      'utmCampaign' => utm_campaign,
      'params' => params || {}
    }.compact
  end
end
