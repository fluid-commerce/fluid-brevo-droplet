# frozen_string_literal: true

FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Test Company #{n}" }
    sequence(:fluid_shop) { |n| "testshop#{n}.fluid.app" }
    sequence(:authentication_token) { |n| "test_auth_token_#{n}_#{SecureRandom.hex(16)}" }
    sequence(:fluid_company_id) { |n| n }
    sequence(:company_droplet_uuid) { |n| "company-droplet-uuid-#{n}" }
    sequence(:droplet_installation_uuid) { |n| "droplet-installation-uuid-#{n}" }
    active { true }
    installed_callback_ids { [] }
    
    trait :with_integration_setting do
      after(:create) do |company|
        create(:integration_setting, company: company)
      end
    end
    
    trait :with_brevo_credentials do
      after(:create) do |company|
        create(:integration_setting, :with_brevo, company: company)
      end
    end
  end
end

