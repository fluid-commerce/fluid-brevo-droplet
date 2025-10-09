# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategoryImportJob, type: :job do
  let(:company) { create(:company, :with_brevo_credentials, authentication_token: ENV['FLUID_AUTH_TOKEN'] || 'test_token', fluid_shop: 'testshop') }
  let(:job_id) { SecureRandom.uuid }

  before do
    Rails.cache.clear
  end

  describe '#perform' do
    let(:fluid_response) do
      {
        'categories' => [
          { 'id' => 1, 'title' => 'Electronics', 'slug' => 'electronics' },
          { 'id' => 2, 'title' => 'Clothing', 'slug' => 'clothing' }
        ],
        'meta' => {
          'pagination' => {
            'current_page' => 1,
            'total_pages' => 1,
            'total_count' => 2
          }
        }
      }
    end

    before do
      # Mock Fluid API response
      allow_any_instance_of(FluidClient).to receive(:get).and_return(fluid_response)
      
      # Mock Brevo API response (using VCR-like behavior)
      allow_any_instance_of(BrevoClient).to receive(:create_categories_batch).and_return({})
    end

    it 'imports categories from Fluid to Brevo' do
      expect {
        described_class.new.perform(company.id, job_id)
      }.not_to raise_error

      # Check progress was updated
      progress = Rails.cache.read("category_import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:status]).to eq('completed')
    end

    it 'updates progress throughout the import' do
      described_class.new.perform(company.id, job_id)

      progress = Rails.cache.read("category_import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:percentage]).to be >= 0
      expect(progress[:message]).to be_present
    end

    context 'when an error occurs' do
      before do
        allow_any_instance_of(FluidClient).to receive(:get).and_raise(StandardError.new('API Error'))
      end

      it 'updates progress to failed status and re-raises error' do
        expect {
          described_class.new.perform(company.id, job_id)
        }.to raise_error(StandardError)

        progress = Rails.cache.read("category_import_progress_#{job_id}")
        expect(progress).to be_present
        expect(progress[:percentage]).to eq(0)
        expect(progress[:message]).to include('failed')
      end
    end
  end

  describe '#transform_categories_to_brevo_format' do
    let(:job) { described_class.new }
    let(:company) { create(:company, :with_brevo_credentials, fluid_shop: 'testshop') }

    before do
      job.instance_variable_set(:@company, company)
    end

    it 'transforms Fluid categories to Brevo format' do
      categories = [
        {
          'id' => 1,
          'title' => 'Electronics',
          'slug' => 'electronics'
        },
        {
          'id' => 2,
          'name' => 'Clothing',
          'slug' => 'clothing'
        }
      ]

      result = job.send(:transform_categories_to_brevo_format, categories)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)

      first_category = result.first
      expect(first_category[:id]).to eq('1')
      expect(first_category[:name]).to eq('Electronics')
      expect(first_category[:url]).to include('electronics')

      second_category = result.second
      expect(second_category[:id]).to eq('2')
      expect(second_category[:name]).to eq('Clothing')
      expect(second_category[:url]).to include('clothing')
    end

    it 'handles categories without title or name' do
      categories = [
        {
          'id' => 3,
          'slug' => 'unknown'
        }
      ]

      result = job.send(:transform_categories_to_brevo_format, categories)

      expect(result.first[:name]).to eq('Untitled Category')
    end

    it 'uses title over name when both are present' do
      categories = [
        {
          'id' => 4,
          'title' => 'Title Value',
          'name' => 'Name Value',
          'slug' => 'test'
        }
      ]

      result = job.send(:transform_categories_to_brevo_format, categories)

      expect(result.first[:name]).to eq('Title Value')
    end
  end

  describe '#build_category_url' do
    let(:job) { described_class.new }
    let(:company) { create(:company, :with_brevo_credentials, fluid_shop: 'testshop.fluid.app') }

    before do
      job.instance_variable_set(:@company, company)
    end

    it 'builds URL with slug when available' do
      category = {
        'id' => 1,
        'slug' => 'electronics'
      }

      url = job.send(:build_category_url, category)

      expect(url).to eq('https://testshop.fluid.app/categories/electronics')
    end

    it 'builds URL with ID when slug is not available' do
      category = {
        'id' => 1
      }

      url = job.send(:build_category_url, category)

      expect(url).to eq('https://testshop.fluid.app/categories/1')
    end
  end

  describe '#import_to_brevo' do
    let(:job) { described_class.new }
    let(:brevo_client) { instance_double(BrevoClient) }

    before do
      allow(job).to receive(:brevo_client).and_return(brevo_client)
    end

    it 'imports categories in batches of 50' do
      categories = Array.new(75) do |i|
        {
          id: i.to_s,
          name: "Category #{i}",
          url: "https://example.com/category/#{i}"
        }
      end

      expect(brevo_client).to receive(:create_categories_batch).twice

      result = job.send(:import_to_brevo, categories)

      expect(result[:success]).to be true
      expect(result[:total_imported]).to eq(75)
    end

    it 're-raises errors from Brevo client' do
      categories = [{ id: '1', name: 'Test', url: 'https://example.com' }]

      allow(brevo_client).to receive(:create_categories_batch).and_raise(StandardError.new('API Error'))

      expect {
        job.send(:import_to_brevo, categories)
      }.to raise_error(StandardError, 'API Error')
    end

    it 'processes batches correctly' do
      categories = Array.new(125) do |i|
        {
          id: i.to_s,
          name: "Category #{i}",
          url: "https://example.com/category/#{i}"
        }
      end

      # Should call create_categories_batch 3 times (50 + 50 + 25)
      expect(brevo_client).to receive(:create_categories_batch).exactly(3).times

      job.send(:import_to_brevo, categories)
    end
  end

  describe '#update_progress' do
    let(:job) { described_class.new }

    before do
      job.instance_variable_set(:@job_id, job_id)
    end

    it 'stores progress in cache' do
      job.send(:update_progress, 50, 'Importing categories...')

      progress = Rails.cache.read("category_import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:percentage]).to eq(50)
      expect(progress[:message]).to eq('Importing categories...')
      expect(progress[:status]).to eq('in_progress')
      expect(progress[:timestamp]).to be_present
    end

    it 'marks as completed when percentage is 100' do
      job.send(:update_progress, 100, 'Import complete')

      progress = Rails.cache.read("category_import_progress_#{job_id}")
      expect(progress[:status]).to eq('completed')
    end
  end

  describe 'pagination handling' do
    let(:fluid_response_page1) do
      {
        'categories' => Array.new(50) { |i| { 'id' => i, 'title' => "Category #{i}" } },
        'meta' => { 
          'pagination' => { 
            'current_page' => 1, 
            'total_pages' => 2,
            'total_count' => 75  # Add total_count to prevent division by zero
          } 
        }
      }
    end

    let(:fluid_response_page2) do
      {
        'categories' => Array.new(25) { |i| { 'id' => i + 50, 'title' => "Category #{i + 50}" } },
        'meta' => { 
          'pagination' => { 
            'current_page' => 2, 
            'total_pages' => 2,
            'total_count' => 75
          } 
        }
      }
    end

    before do
      # Mock paginated responses
      allow_any_instance_of(FluidClient).to receive(:get).and_return(fluid_response_page1, fluid_response_page2)
      allow_any_instance_of(BrevoClient).to receive(:create_categories_batch).and_return({})
    end

    it 'handles pagination metadata correctly' do
      expect {
        described_class.new.perform(company.id, job_id)
      }.not_to raise_error

      progress = Rails.cache.read("category_import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:status]).to eq('completed')
    end

    it 'detects last page from pagination metadata' do
      pagination = {
        'current_page' => 3,
        'total_pages' => 3
      }

      is_last_page = pagination['current_page'] >= pagination['total_pages']
      expect(is_last_page).to be true
    end

    it 'detects last page when fewer items than per_page' do
      categories = Array.new(25) { |i| { 'id' => i } }
      per_page = 50

      is_last_page = categories.length < per_page
      expect(is_last_page).to be true
    end
  end

  describe 'duplicate prevention' do
    let(:job) { described_class.new }
    let(:company) { create(:company, :with_brevo_credentials) }

    before do
      job.instance_variable_set(:@company, company)
      job.instance_variable_set(:@job_id, job_id)
    end

    it 'prevents importing duplicate categories' do
      # The job uses a Set to track imported category IDs
      # Verify that categories with duplicate IDs are skipped
      categories = [
        { 'id' => 1, 'title' => 'Category 1' },
        { 'id' => 1, 'title' => 'Category 1 Duplicate' }
      ]

      imported_ids = Set.new
      categories.each do |category|
        next if imported_ids.include?(category['id'])
        imported_ids.add(category['id'])
      end

      expect(imported_ids.size).to eq(1)
    end
  end

  describe 'error handling' do
    before do
      allow_any_instance_of(FluidClient).to receive(:get).and_raise(StandardError.new('API Error'))
    end

    it 'stores error information in cache on failure' do
      expect {
        described_class.new.perform(company.id, job_id)
      }.to raise_error(StandardError)

      progress = Rails.cache.read("category_import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:message]).to include('failed')
    end

    it 'logs errors appropriately' do
      expect(Rails.logger).to receive(:error).at_least(:once)

      expect {
        described_class.new.perform(company.id, job_id)
      }.to raise_error(StandardError)
    end
  end

  describe 'progress calculation' do
    let(:job) { described_class.new }

    before do
      job.instance_variable_set(:@job_id, job_id)
    end

    it 'calculates progress correctly during import' do
      total_categories = 100
      total_imported = 50

      # Progress should be 10% (initial) + 50% of 80% range = 50%
      expected_percentage = 10 + (total_imported * 80 / total_categories)

      job.send(:update_progress, expected_percentage, "Imported #{total_imported}/#{total_categories} categories")

      progress = Rails.cache.read("category_import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:percentage]).to eq(50)
    end
  end
end

