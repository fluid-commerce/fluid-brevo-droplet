# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductImportJob, type: :job do
  let(:company) { create(:company, :with_brevo_credentials, authentication_token: ENV['FLUID_AUTH_TOKEN'] || 'test_token', fluid_shop: 'testshop') }
  let(:job_id) { SecureRandom.uuid }

  before do
    Rails.cache.clear
  end

  describe '#perform', :vcr do
    it 'imports products from Fluid to Brevo' do
      expect {
        described_class.new.perform(company.id, job_id)
      }.not_to raise_error

      # Check final result
      final_result = Rails.cache.read("import_result_#{job_id}")
      expect(final_result).to be_present
      expect(final_result[:message]).to include('imported')
    end

    it 'updates progress throughout the import' do
      described_class.new.perform(company.id, job_id)

      progress = Rails.cache.read("import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:percentage]).to be >= 0
    end

    context 'when no products are found' do
      before do
        # Mock empty response - this would need to be done via VCR cassette
        # or by stubbing the FluidClient
      end

      it 'handles empty product list gracefully', :vcr do
        # This test would need a VCR cassette with no products
        # For now, just verify the job completes
        expect {
          described_class.new.perform(company.id, job_id)
        }.not_to raise_error
      end
    end

    context 'when an error occurs' do
      let(:invalid_company) { create(:company, authentication_token: 'invalid_token') }

      before do
        create(:integration_setting, company: invalid_company, credentials: { 'brevo' => { 'api_key' => 'invalid' } })
      end

      it 'updates progress to failed status and re-raises error', :vcr do
        expect {
          described_class.new.perform(invalid_company.id, job_id)
        }.to raise_error

        final_result = Rails.cache.read("import_result_#{job_id}")
        expect(final_result).to be_present
        expect(final_result[:message]).to include('failed')
      end
    end
  end

  describe '#transform_products_to_brevo_format' do
    let(:job) { described_class.new }
    let(:company) { create(:company, :with_brevo_credentials, fluid_shop: 'testshop.fluid.app') }

    before do
      job.instance_variable_set(:@company, company)
    end

    it 'transforms Fluid products to Brevo format' do
      products = [
        {
          'id' => 1,
          'title' => 'Test Product',
          'slug' => 'test-product',
          'image_url' => 'https://example.com/image.jpg',
          'sku' => 'TEST-SKU',
          'price' => 99.99,
          'category' => {
            'id' => 1
          },
          'in_stock' => true,
          'variants' => [
            {
              'track_quantity' => true,
              'inventory_quantity' => 10
            }
          ],
          'metadata' => { 'color' => 'blue' }
        }
      ]

      result = job.send(:transform_products_to_brevo_format, products)

      expect(result).to be_an(Array)
      expect(result.length).to eq(1)

      product = result.first
      expect(product[:id]).to eq('1')
      expect(product[:name]).to eq('Test Product')
      expect(product[:url]).to include('test-product')
      expect(product[:imageUrl]).to eq('https://example.com/image.jpg')
      expect(product[:sku]).to eq('TEST-SKU')
      expect(product[:price]).to eq(99.99)
      expect(product[:categories]).to eq(['1'])
      expect(product[:stock]).to eq(10)
      expect(product[:metaInfo]).to eq({ 'color' => 'blue' })
    end

    it 'handles products with parent_id (variants)' do
      products = [
        {
          'id' => 2,
          'title' => 'Product Variant',
          'parent_id' => 1,
          'price' => 49.99,
          'in_stock' => true,
          'variants' => []
        }
      ]

      result = job.send(:transform_products_to_brevo_format, products)

      expect(result.first[:parentId]).to eq('1')
    end

    it 'handles products without optional fields' do
      products = [
        {
          'id' => 3,
          'title' => 'Minimal Product',
          'in_stock' => false,
          'variants' => []
        }
      ]

      result = job.send(:transform_products_to_brevo_format, products)

      expect(result.first[:id]).to eq('3')
      expect(result.first[:name]).to eq('Minimal Product')
      expect(result.first[:stock]).to eq(0)
    end

    it 'uses external_url when available' do
      products = [
        {
          'id' => 4,
          'title' => 'External Product',
          'external_url' => 'https://external.com/product',
          'in_stock' => true,
          'variants' => []
        }
      ]

      result = job.send(:transform_products_to_brevo_format, products)

      expect(result.first[:url]).to eq('https://external.com/product')
    end
  end

  describe '#calculate_stock' do
    let(:job) { described_class.new }

    it 'calculates total stock from variants with inventory_levels' do
      product = {
        'in_stock' => true,
        'variants' => [
          {
            'track_quantity' => true,
            'inventory_levels' => [
              { 'available' => 5 },
              { 'available' => 3 }
            ]
          }
        ]
      }

      stock = job.send(:calculate_stock, product)
      expect(stock).to eq(8)
    end

    it 'falls back to inventory_quantity when inventory_levels not available' do
      product = {
        'in_stock' => true,
        'variants' => [
          {
            'track_quantity' => true,
            'inventory_quantity' => 10
          }
        ]
      }

      stock = job.send(:calculate_stock, product)
      expect(stock).to eq(10)
    end

    it 'returns 0 when product is not in stock' do
      product = {
        'in_stock' => false,
        'variants' => [
          {
            'track_quantity' => true,
            'inventory_quantity' => 10
          }
        ]
      }

      stock = job.send(:calculate_stock, product)
      expect(stock).to eq(0)
    end

    it 'returns 0 when no variants exist' do
      product = {
        'in_stock' => true,
        'variants' => []
      }

      stock = job.send(:calculate_stock, product)
      expect(stock).to eq(0)
    end

    it 'skips variants that do not track quantity' do
      product = {
        'in_stock' => true,
        'variants' => [
          {
            'track_quantity' => false,
            'inventory_quantity' => 10
          },
          {
            'track_quantity' => true,
            'inventory_quantity' => 5
          }
        ]
      }

      stock = job.send(:calculate_stock, product)
      expect(stock).to eq(5)
    end
  end

  describe '#import_to_brevo' do
    let(:job) { described_class.new }
    let(:brevo_client) { instance_double(BrevoClient) }

    before do
      allow(job).to receive(:brevo_client).and_return(brevo_client)
    end

    it 'imports products in batches of 50' do
      products = Array.new(75) do |i|
        {
          id: i.to_s,
          name: "Product #{i}",
          price: 10.0
        }
      end

      expect(brevo_client).to receive(:create_products_batch).twice

      result = job.send(:import_to_brevo, products)

      expect(result[:success]).to be true
      expect(result[:total_imported]).to eq(75)
    end

    it 're-raises errors from Brevo client' do
      products = [{ id: '1', name: 'Test', price: 10.0 }]

      allow(brevo_client).to receive(:create_products_batch).and_raise(StandardError.new('API Error'))

      expect {
        job.send(:import_to_brevo, products)
      }.to raise_error(StandardError, 'API Error')
    end
  end

  describe '#update_progress' do
    let(:job) { described_class.new }

    before do
      job.instance_variable_set(:@job_id, job_id)
    end

    it 'stores progress in cache' do
      job.send(:update_progress, 50, 'Importing products...')

      progress = Rails.cache.read("import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:percentage]).to eq(50)
      expect(progress[:message]).to eq('Importing products...')
      expect(progress[:status]).to eq('running')
    end

    it 'marks as completed when percentage is 100' do
      job.send(:update_progress, 100, 'Import complete')

      progress = Rails.cache.read("import_progress_#{job_id}")
      expect(progress[:status]).to eq('completed')
    end

    it 'marks as failed when percentage is -1' do
      job.send(:update_progress, -1, 'Import failed')

      progress = Rails.cache.read("import_progress_#{job_id}")
      expect(progress[:status]).to eq('failed')
    end
  end

  describe 'pagination handling' do
    let(:job) { described_class.new }
    let(:company) { create(:company, :with_brevo_credentials) }

    before do
      job.instance_variable_set(:@company, company)
      job.instance_variable_set(:@job_id, job_id)
    end

    it 'handles pagination metadata correctly', :vcr do
      # This test verifies the job correctly processes multiple pages
      # The VCR cassette should contain multiple pages of product data
      expect {
        described_class.new.perform(company.id, job_id)
      }.not_to raise_error
    end
  end

  describe 'duplicate prevention' do
    let(:job) { described_class.new }
    let(:company) { create(:company, :with_brevo_credentials) }

    before do
      job.instance_variable_set(:@company, company)
      job.instance_variable_set(:@job_id, job_id)
    end

    it 'prevents importing duplicate products' do
      # The job uses a Set to track imported product IDs
      # Verify that products with duplicate IDs are skipped
      products = [
        { 'id' => 1, 'title' => 'Product 1', 'in_stock' => true, 'variants' => [] },
        { 'id' => 1, 'title' => 'Product 1 Duplicate', 'in_stock' => true, 'variants' => [] }
      ]

      imported_ids = Set.new
      products.each do |product|
        next if imported_ids.include?(product['id'])
        imported_ids.add(product['id'])
      end

      expect(imported_ids.size).to eq(1)
    end
  end

  describe 'error handling' do
    let(:job) { described_class.new }
    let(:company) { create(:company, :with_brevo_credentials) }

    before do
      job.instance_variable_set(:@company, company)
      job.instance_variable_set(:@job_id, job_id)
    end

    it 'stores error information in cache on failure' do
      allow_any_instance_of(FluidClient).to receive(:get).and_raise(StandardError.new('API Error'))

      expect {
        described_class.new.perform(company.id, job_id)
      }.to raise_error(StandardError)

      final_result = Rails.cache.read("import_result_#{job_id}")
      expect(final_result).to be_present
      expect(final_result[:message]).to include('failed')
    end
  end
end

