# frozen_string_literal: true

require 'vcr'

VCR.configure do |config|
  # Cassettes are saved to spec/fixtures/vcr_cassettes
  config.cassette_library_dir = Rails.root.join('spec', 'fixtures', 'vcr_cassettes')
  
  # Use webmock to intercept HTTP requests
  config.hook_into :webmock
  
  # Allow connections to localhost (for testing servers)
  config.ignore_localhost = true
  
  # Configure VCR to filter sensitive data in cassettes
  # Replace actual API keys with placeholders
  config.filter_sensitive_data('<BREVO_API_KEY>') { ENV['BREVO_API_KEY'] }
  config.filter_sensitive_data('<FLUID_AUTH_TOKEN>') { ENV['FLUID_AUTH_TOKEN'] }
  
  # You can also filter specific headers
  config.filter_sensitive_data('<BREVO_API_KEY>') do |interaction|
    if interaction.request.headers['Api-Key']
      interaction.request.headers['Api-Key'].first
    end
  end
  
  config.filter_sensitive_data('<FLUID_AUTH_TOKEN>') do |interaction|
    if auth_header = interaction.request.headers['Authorization']&.first
      auth_header.gsub(/Bearer\s+/, '')
    end
  end
  
  # Configure cassette matching
  # Match requests by method, URI, and body
  config.default_cassette_options = {
    record: :once, # Only record new interactions once
    match_requests_on: [:method, :uri, :body],
    allow_unused_http_interactions: false,
    serialize_with: :json,
    decode_compressed_response: true
  }
  
  # Configure for better error messages
  config.debug_logger = File.open(Rails.root.join('log', 'vcr_debug.log'), 'w') if ENV['VCR_DEBUG']
  
  # Allow real HTTP connections when cassettes are being recorded
  # This is useful when you're generating cassettes with real credentials
  config.allow_http_connections_when_no_cassette = false
  
  # Configure to re-record cassettes periodically (e.g., every 7 days)
  # Useful for keeping test data fresh
  config.configure_rspec_metadata!
  
  # Preserve exact body content for accurate matching
  config.preserve_exact_body_bytes do |http_message|
    http_message.body.encoding.name == 'ASCII-8BIT' ||
    !http_message.body.valid_encoding?
  end
end

# RSpec configuration for VCR
RSpec.configure do |config|
  # Automatically use VCR for all specs that have :vcr metadata
  # Usage: it 'does something', :vcr do ... end
  config.around(:each, :vcr) do |example|
    # Use the spec description as the cassette name
    cassette_name = example.metadata[:full_description]
      .downcase
      .gsub(/[^\w\s]/, '')
      .gsub(/\s+/, '_')
    
    VCR.use_cassette(cassette_name) do
      example.run
    end
  end
end

