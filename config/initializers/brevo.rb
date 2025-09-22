# frozen_string_literal: true

# Brevo API Configuration
Rails.application.configure do
  # Brevo API configuration
  config.brevo = ActiveSupport::OrderedOptions.new
  
  # Default API key from environment variables
  config.brevo.api_key = ENV['BREVO_API_KEY']
  
  # Default sender information
  config.brevo.default_sender = {
    name: ENV['BREVO_DEFAULT_SENDER_NAME'] || 'Your App',
    email: ENV['BREVO_DEFAULT_SENDER_EMAIL']
  }
  
  # Webhook configuration
  config.brevo.webhook_secret = ENV['BREVO_WEBHOOK_SECRET']
  
  # Rate limiting configuration
  config.brevo.rate_limit = {
    requests_per_minute: 100,
    burst_limit: 10
  }
end
