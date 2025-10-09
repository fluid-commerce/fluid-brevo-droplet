# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderImportJob, type: :job do
  let(:company) { create(:company, :with_brevo_credentials, authentication_token: ENV['FLUID_AUTH_TOKEN'] || 'test_token') }
  let(:job_id) { SecureRandom.uuid }

  before do
    # Clear any cached progress data
    Rails.cache.clear
  end

  describe '#perform', :vcr do
    it 'imports orders from Fluid to Brevo' do
      expect {
        described_class.new.perform(company.id, job_id)
      }.not_to raise_error

      # Check progress was updated
      progress = Rails.cache.read("import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:status]).to eq('completed')
      expect(progress[:percentage]).to eq(100)
    end

    it 'updates progress throughout the import' do
      described_class.new.perform(company.id, job_id)

      progress = Rails.cache.read("import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:message]).to include('completed')
    end

    context 'when an error occurs' do
      let(:invalid_company) { create(:company, authentication_token: 'invalid_token') }

      before do
        # Create integration setting with invalid credentials
        create(:integration_setting, company: invalid_company, credentials: { 'brevo' => { 'api_key' => 'invalid' } })
      end

      it 'updates progress to failed status', :vcr do
        expect {
          described_class.new.perform(invalid_company.id, job_id)
        }.to raise_error

        progress = Rails.cache.read("import_progress_#{job_id}")
        expect(progress).to be_present
        expect(progress[:message]).to include('failed')
      end
    end
  end

  describe '#extract_total_count' do
    let(:job) { described_class.new }

    it 'extracts total count from pagination metadata' do
      orders_response = {
        'meta' => {
          'pagination' => {
            'total_count' => 150
          }
        }
      }

      count = job.send(:extract_total_count, orders_response, 50)
      expect(count).to eq(150)
    end

    it 'estimates from total pages when total_count is not available' do
      orders_response = {
        'meta' => {
          'pagination' => {
            'total_pages' => 5,
            'per_page' => 50
          }
        }
      }

      count = job.send(:extract_total_count, orders_response, 50)
      expect(count).to eq(250)
    end

    it 'falls back to current count when no metadata is available' do
      orders_response = {}

      count = job.send(:extract_total_count, orders_response, 25)
      expect(count).to eq(25)
    end
  end

  describe '#last_page?' do
    let(:job) { described_class.new }

    it 'returns true when current page equals total pages' do
      orders_response = {
        'meta' => {
          'pagination' => {
            'current_page' => 5,
            'total_pages' => 5
          }
        }
      }

      result = job.send(:last_page?, orders_response, 50, 50, 5)
      expect(result).to be true
    end

    it 'returns true when orders count is less than per_page' do
      orders_response = {}

      result = job.send(:last_page?, orders_response, 25, 50, 3)
      expect(result).to be true
    end

    it 'returns false when more pages are available' do
      orders_response = {
        'meta' => {
          'pagination' => {
            'current_page' => 2,
            'total_pages' => 5
          }
        }
      }

      result = job.send(:last_page?, orders_response, 50, 50, 2)
      expect(result).to be false
    end
  end

  describe '#calculate_progress' do
    let(:job) { described_class.new }

    it 'calculates progress percentage within range' do
      percentage = job.send(:calculate_progress, 50, 100, 10, 90)
      expect(percentage).to eq(50)
    end

    it 'returns min percentage when current is 0' do
      percentage = job.send(:calculate_progress, 0, 100, 10, 90)
      expect(percentage).to eq(10)
    end

    it 'caps at max percentage' do
      percentage = job.send(:calculate_progress, 150, 100, 10, 90)
      expect(percentage).to eq(90)
    end

    it 'returns min percentage when total is 0' do
      percentage = job.send(:calculate_progress, 50, 0, 10, 90)
      expect(percentage).to eq(10)
    end
  end

  describe '#transform_orders_to_brevo_format' do
    let(:job) { described_class.new }
    let(:company) { create(:company, :with_brevo_credentials, fluid_company_id: 123) }

    before do
      job.instance_variable_set(:@company, company)
    end

    it 'transforms Fluid orders to Brevo format' do
      orders = [
        {
          'id' => '1',
          'created_at' => '2024-01-01T00:00:00Z',
          'updated_at' => '2024-01-01T00:00:00Z',
          'status' => 'awaiting_shipment',
          'amount' => 99.99,
          'email' => 'customer@example.com',
          'items' => [
            {
              'id' => '1',
              'quantity' => 2,
              'price' => 49.99
            }
          ],
          'bill_to' => {
            'address1' => '123 Main St',
            'city' => 'Test City',
            'country_code' => 'US',
            'postal_code' => '12345'
          }
        }
      ]

      result = job.send(:transform_orders_to_brevo_format, orders)

      expect(result).to be_an(Array)
      expect(result.length).to eq(1)
      expect(result.first[:id]).to eq('1')
      expect(result.first[:status]).to eq('confirmed')
      expect(result.first[:amount]).to eq(99.99)
      expect(result.first[:identifiers]).to have_key(:email_id)
      expect(result.first[:products]).to be_an(Array)
    end

    it 'skips orders without contact identifiers' do
      orders = [
        {
          'id' => '1',
          'created_at' => '2024-01-01T00:00:00Z',
          'updated_at' => '2024-01-01T00:00:00Z',
          'status' => 'pending',
          'amount' => 99.99,
          'items' => []
        }
      ]

      result = job.send(:transform_orders_to_brevo_format, orders)

      expect(result).to be_empty
    end
  end

  describe '#map_order_status' do
    let(:job) { described_class.new }

    it 'maps Fluid statuses to Brevo statuses' do
      expect(job.send(:map_order_status, 'awaiting_payment')).to eq('pending')
      expect(job.send(:map_order_status, 'awaiting_shipment')).to eq('confirmed')
      expect(job.send(:map_order_status, 'shipped')).to eq('shipped')
      expect(job.send(:map_order_status, 'delivered')).to eq('delivered')
      expect(job.send(:map_order_status, 'cancelled')).to eq('cancelled')
      expect(job.send(:map_order_status, 'failed_payment')).to eq('failed')
      expect(job.send(:map_order_status, 'unknown')).to eq('pending')
    end
  end

  describe '#build_identifiers' do
    let(:job) { described_class.new }

    it 'builds identifiers from order data' do
      order = {
        'email' => 'customer@example.com',
        'customer' => {
          'phone' => '+1234567890',
          'external_id' => 'ext_123'
        }
      }

      identifiers = job.send(:build_identifiers, order)

      expect(identifiers[:email_id]).to eq('customer@example.com')
      expect(identifiers[:phone_id]).to eq('+1234567890')
      expect(identifiers[:ext_id]).to eq('ext_123')
    end

    it 'returns empty hash when no identifiers are present' do
      order = {}

      identifiers = job.send(:build_identifiers, order)

      expect(identifiers).to be_empty
    end
  end

  describe '#build_billing_info' do
    let(:job) { described_class.new }

    it 'builds billing information from order' do
      order = {
        'bill_to' => {
          'address1' => '123 Main St',
          'address2' => 'Apt 4',
          'city' => 'Test City',
          'country_code' => 'US',
          'phone' => '+1234567890',
          'postal_code' => '12345',
          'state' => 'CA'
        }
      }

      billing = job.send(:build_billing_info, order)

      expect(billing[:address]).to include('123 Main St')
      expect(billing[:city]).to eq('Test City')
      expect(billing[:countryCode]).to eq('US')
      expect(billing[:country]).to eq('United States')
      expect(billing[:postCode]).to eq('12345')
    end
  end

  describe '#get_country_name' do
    let(:job) { described_class.new }

    it 'maps country codes to names' do
      expect(job.send(:get_country_name, 'US')).to eq('United States')
      expect(job.send(:get_country_name, 'CA')).to eq('Canada')
      expect(job.send(:get_country_name, 'GB')).to eq('United Kingdom')
    end

    it 'returns the code if no mapping exists' do
      expect(job.send(:get_country_name, 'XX')).to eq('XX')
    end

    it 'returns nil for blank codes' do
      expect(job.send(:get_country_name, nil)).to be_nil
    end
  end

  describe '#transform_order_products' do
    let(:job) { described_class.new }

    it 'transforms order items to Brevo product format' do
      items = [
        {
          'variant' => {
            'product' => { 'id' => '123' },
            'id' => '456'
          },
          'quantity' => 2,
          'price' => 49.99
        }
      ]

      products = job.send(:transform_order_products, items)

      expect(products).to be_an(Array)
      expect(products.first[:productId]).to eq('123')
      expect(products.first[:variantId]).to eq('456')
      expect(products.first[:quantity]).to eq(2)
      expect(products.first[:price]).to eq(49.99)
    end

    it 'falls back to item id when product id is not available' do
      items = [
        {
          'id' => '789',
          'quantity' => 1,
          'price' => 29.99
        }
      ]

      products = job.send(:transform_order_products, items)

      expect(products.first[:productId]).to eq('789')
      expect(products.first).not_to have_key(:variantId)
    end
  end

  describe '#update_progress' do
    let(:job) { described_class.new }

    before do
      job.instance_variable_set(:@job_id, job_id)
    end

    it 'stores progress in cache' do
      job.send(:update_progress, 50, 'Processing...')

      progress = Rails.cache.read("import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:percentage]).to eq(50)
      expect(progress[:message]).to eq('Processing...')
      expect(progress[:status]).to eq('in_progress')
    end

    it 'marks as completed when percentage is 100' do
      job.send(:update_progress, 100, 'Done!')

      progress = Rails.cache.read("import_progress_#{job_id}")
      expect(progress[:status]).to eq('completed')
    end
  end
end

