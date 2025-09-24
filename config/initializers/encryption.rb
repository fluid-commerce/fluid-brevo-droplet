# frozen_string_literal: true

# Rails Active Record Encryption Configuration
# Uses environment variables for encryption keys

Rails.application.configure do
  # Set encryption keys from environment variables
  config.active_record.encryption.deterministic_key = ENV['RAILS_DB_DETERMINISTIC_KEY']
  config.active_record.encryption.key_derivation_salt = ENV['RAILS_DB_KEY_DERIVATION_SALT']
  config.active_record.encryption.primary_key = ENV['RAILS_DB_PRIMARY_KEY']

  # Additional encryption settings
  config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA256
  config.active_record.encryption.support_sha1_for_non_deterministic_encryption = false
end

# Also set the configuration directly on the encryption module
Rails.application.config.after_initialize do
  Rails.application.config.active_record.encryption.deterministic_key = ENV['RAILS_DB_DETERMINISTIC_KEY']
  Rails.application.config.active_record.encryption.key_derivation_salt = ENV['RAILS_DB_KEY_DERIVATION_SALT']
  Rails.application.config.active_record.encryption.primary_key = ENV['RAILS_DB_PRIMARY_KEY']
end
