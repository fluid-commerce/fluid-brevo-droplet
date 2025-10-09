# frozen_string_literal: true

FactoryBot.define do
  factory :integration_setting do
    company
    credentials { {} }
    settings { {} }
    
    trait :with_brevo do
      credentials do
        {
          'brevo' => {
            'api_key' => ENV['BREVO_API_KEY'] || 'test_brevo_api_key'
          }
        }
      end
    end
    
    trait :with_lists do
      settings do
        {
          'lists' => [
            { 'id' => 1, 'name' => 'Everyone List' },
            { 'id' => 2, 'name' => 'Customer List' },
            { 'id' => 3, 'name' => 'Rep List' }
          ]
        }
      end
    end
    
    trait :with_segment_mappings do
      settings do
        {
          'segment_mappings' => {
            'everyone_list_id' => '1',
            'customer_list_id' => '2',
            'rep_list_id' => '3'
          }
        }
      end
    end
    
    trait :with_folder do
      settings do
        {
          'brevo_folder_id' => 123
        }
      end
    end
    
    trait :complete_setup do
      with_brevo
      with_lists
      with_segment_mappings
      with_folder
    end
  end
end

