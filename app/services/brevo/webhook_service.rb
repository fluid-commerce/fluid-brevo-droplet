# frozen_string_literal: true

class Brevo::WebhookService
  def initialize(api_key)
    @api_key = api_key
    @brevo_client = BrevoClient.new(api_key)
  end

  def create_webhook(url:, events: [], description: nil, type: 'transactional', is_active: true, batched: false, auth: {}, headers: {})
    webhook_params = build_webhook_params(
      url: url,
      events: events,
      description: description,
      type: type,
      is_active: is_active,
      batched: batched,
      auth: auth,
      headers: headers
    )
    
    @brevo_client.create_webhook(webhook_params)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to create webhook: #{e.message}")
  end

  def get_webhooks
    @brevo_client.get_webhooks
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to get webhooks: #{e.message}")
  end

  def update_webhook(webhook_id:, url: nil, events: nil, description: nil, type: nil, is_active: nil, batched: nil, auth: nil, headers: nil)
    webhook_params = build_webhook_params(
      url: url,
      events: events,
      description: description,
      type: type,
      is_active: is_active,
      batched: batched,
      auth: auth,
      headers: headers
    ).compact
    
    @brevo_client.update_webhook(webhook_id, webhook_params)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to update webhook: #{e.message}")
  end

  def delete_webhook(webhook_id)
    @brevo_client.delete_webhook(webhook_id)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to delete webhook: #{e.message}")
  end

  private

  def build_webhook_params(url:, events:, description:, type:, is_active:, batched:, auth:, headers:)
    {
      'url' => url,
      'description' => description,
      'events' => events || [],
      'type' => type || 'transactional',
      'isActive' => is_active || true,
      'batched' => batched || false,
      'auth' => auth || {},
      'headers' => headers || {}
    }.compact
  end
end
