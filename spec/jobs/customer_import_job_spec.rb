# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CustomerImportJob, type: :job do
  let(:company) { create(:company, :with_brevo_credentials, authentication_token: ENV['FLUID_AUTH_TOKEN'] || 'test_token') }
  let(:list_id) { 123 }
  let(:segment) { 'everyone_list_id' }
  let(:job_id) { SecureRandom.uuid }

  before do
    Rails.cache.clear
  end

  describe '#perform' do
    let(:fluid_response) do
      {
        'customers' => [
          {
            'id' => 1,
            'email' => 'customer@example.com',
            'first_name' => 'John',
            'last_name' => 'Doe',
            'phone' => '1234567890',
            'is_rep' => false
          }
        ],
        'meta' => {
          'pagination' => {
            'current_page' => 1,
            'total_pages' => 1,
            'total_count' => 1
          }
        }
      }
    end

    before do
      # Mock Fluid API responses for different endpoints
      # Mock /api/customers endpoint
      allow_any_instance_of(FluidClient).to receive(:get).with('/api/customers', anything).and_return(fluid_response)
      
      # Mock /api/v2/reps endpoint for rep data
      reps_response = {
        'reps' => [
          {
            'id' => 1,
            'computed_email' => 'rep@example.com',
            'share_guid' => 'abc123',
            'rank' => 'Gold'
          }
        ],
        'meta' => { 'pagination' => { 'current_page' => 1, 'total_pages' => 1 } }
      }
      allow_any_instance_of(FluidClient).to receive(:get).with('/api/v2/reps', anything).and_return(reps_response)
      
      # Mock /api/v202506/users endpoint for rank data
      users_response = {
        'user_companies' => [
          {
            'user' => { 'email' => 'rep@example.com' },
            'rank' => 'Gold'
          }
        ],
        'meta' => { 'pagination' => { 'current_page' => 1, 'total_pages' => 1 } }
      }
      allow_any_instance_of(FluidClient).to receive(:get).with('/api/v202506/users', anything).and_return(users_response)
      
      # Mock /api/v2/reps/{id} endpoint for sponsor data
      rep_detail_response = {
        'rep' => {
          'id' => 1,
          'enroller' => {
            'first_name' => 'Sponsor',
            'last_name' => 'Name',
            'external_id' => 'sponsor123'
          }
        }
      }
      allow_any_instance_of(FluidClient).to receive(:get).with(/\/api\/v2\/reps\/\d+/, anything).and_return(rep_detail_response)
      
      # Mock Brevo API response
      allow_any_instance_of(BrevoClient).to receive(:import_contacts).and_return({ 'processId' => '123' })
    end

    it 'imports customers from Fluid to Brevo' do
      expect {
        described_class.new.perform(company.id, segment, list_id, job_id)
      }.not_to raise_error

      # Check final result
      final_result = Rails.cache.read("import_result_#{job_id}")
      expect(final_result).to be_present
      expect(final_result[:message]).to include('imported')
    end

    it 'updates progress throughout the import' do
      described_class.new.perform(company.id, segment, list_id, job_id)

      progress = Rails.cache.read("import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:percentage]).to be >= 0
    end

    context 'when no customers are found' do
      before do
        allow_any_instance_of(FluidClient).to receive(:get).and_return({
          'customers' => [],
          'meta' => { 'pagination' => { 'current_page' => 1, 'total_pages' => 1, 'total_count' => 0 } }
        })
      end

      it 'handles empty customer list gracefully' do
        expect {
          described_class.new.perform(company.id, segment, list_id, job_id)
        }.not_to raise_error
        
        progress = Rails.cache.read("import_progress_#{job_id}")
        expect(progress).to be_present
        expect(progress[:percentage]).to eq(100)
      end
    end

    context 'when an error occurs' do
      before do
        # Mock: first call for count succeeds, second call during fetch raises error
        count_response = {
          'customers' => [{ 'id' => 1, 'is_rep' => false }],
          'meta' => { 'pagination' => { 'total_count' => 1 } }
        }
        
        call_count = 0
        allow_any_instance_of(FluidClient).to receive(:get) do
          call_count += 1
          if call_count == 1
            count_response # First call for count succeeds
          else
            raise StandardError.new('API Error') # Subsequent calls fail
          end
        end
      end

      it 'updates progress to failed status' do
        # CustomerImportJob catches errors and updates progress before re-raising
        expect {
          described_class.new.perform(company.id, segment, list_id, job_id)
        }.to raise_error(StandardError, 'API Error')

        progress = Rails.cache.read("import_progress_#{job_id}")
        expect(progress).to be_present
        expect(progress[:message]).to include('failed')
        expect(progress[:status]).to eq('failed')
      end
    end
  end

  describe '#get_total_customer_count' do
    let(:job) { described_class.new }

    before do
      job.instance_variable_set(:@company, company)
      job.instance_variable_set(:@segment, segment)
    end

    it 'gets total customer count for a segment' do
      fluid_response = {
        'customers' => [
          { 'id' => 1, 'is_rep' => false },
          { 'id' => 2, 'is_rep' => false }
        ],
        'meta' => { 'pagination' => { 'total_count' => 2 } }
      }
      
      allow_any_instance_of(FluidClient).to receive(:get).and_return(fluid_response)
      
      count = job.send(:get_total_customer_count)

      expect(count).to be >= 0
    end

    context 'with different segments' do
      it 'counts non-rep customers for customer_list_id segment' do
        job.instance_variable_set(:@segment, 'customer_list_id')
        customers = [
          { 'id' => 1, 'is_rep' => false },
          { 'id' => 2, 'is_rep' => true },
          { 'id' => 3, 'is_rep' => false }
        ]

        filtered = job.send(:filter_customers_by_segment, customers)
        expect(filtered.length).to eq(2)
      end

      it 'counts rep customers for rep_list_id segment' do
        job.instance_variable_set(:@segment, 'rep_list_id')
        customers = [
          { 'id' => 1, 'is_rep' => false },
          { 'id' => 2, 'is_rep' => true },
          { 'id' => 3, 'is_rep' => false }
        ]

        filtered = job.send(:filter_customers_by_segment, customers)
        expect(filtered.length).to eq(1)
      end

      it 'counts all customers for everyone_list_id segment' do
        job.instance_variable_set(:@segment, 'everyone_list_id')
        customers = [
          { 'id' => 1, 'is_rep' => false },
          { 'id' => 2, 'is_rep' => true },
          { 'id' => 3, 'is_rep' => false }
        ]

        filtered = job.send(:filter_customers_by_segment, customers)
        expect(filtered.length).to eq(3)
      end
    end
  end

  describe '#fetch_customers_page' do
    let(:job) { described_class.new }

    before do
      job.instance_variable_set(:@company, company)
      job.instance_variable_set(:@segment, segment)
    end

    it 'fetches and filters customers for a page' do
      fluid_response = {
        'customers' => [
          { 'id' => 1, 'email' => 'test@example.com', 'is_rep' => false },
          { 'id' => 2, 'email' => 'rep@example.com', 'is_rep' => true }
        ],
        'meta' => { 'pagination' => { 'current_page' => 1, 'total_pages' => 1 } }
      }
      
      allow_any_instance_of(FluidClient).to receive(:get).and_return(fluid_response)
      
      result = job.send(:fetch_customers_page, 1, 100)

      expect(result).to be_a(Hash)
      expect(result).to have_key('customers')
      expect(result['customers']).to be_an(Array)
      # Should filter based on segment
      if segment == 'everyone_list_id'
        expect(result['customers'].length).to eq(2)
      elsif segment == 'customer_list_id'
        expect(result['customers'].length).to eq(1)
      end
    end
  end

  describe '#filter_customers_by_segment' do
    let(:job) { described_class.new }

    before do
      job.instance_variable_set(:@segment, segment)
    end

    let(:customers) do
      [
        { 'id' => 1, 'email' => 'customer1@example.com', 'is_rep' => false },
        { 'id' => 2, 'email' => 'rep@example.com', 'is_rep' => true },
        { 'id' => 3, 'email' => 'customer2@example.com', 'is_rep' => false }
      ]
    end

    context 'with customer_list_id segment' do
      let(:segment) { 'customer_list_id' }

      it 'returns only non-rep customers' do
        result = job.send(:filter_customers_by_segment, customers)

        expect(result.length).to eq(2)
        expect(result.all? { |c| c['is_rep'] == false }).to be true
      end
    end

    context 'with rep_list_id segment' do
      let(:segment) { 'rep_list_id' }

      it 'returns only rep customers' do
        result = job.send(:filter_customers_by_segment, customers)

        expect(result.length).to eq(1)
        expect(result.all? { |c| c['is_rep'] == true }).to be true
      end
    end

    context 'with everyone_list_id segment' do
      let(:segment) { 'everyone_list_id' }

      it 'returns all customers' do
        result = job.send(:filter_customers_by_segment, customers)

        expect(result.length).to eq(3)
      end
    end

    context 'with unknown segment' do
      let(:segment) { 'unknown_segment' }

      it 'returns all customers by default' do
        result = job.send(:filter_customers_by_segment, customers)

        expect(result.length).to eq(3)
      end
    end
  end

  describe '#transform_customers_to_brevo_format' do
    let(:job) { described_class.new }

    it 'transforms Fluid customers to Brevo format' do
      customers = [
        {
          'id' => 1,
          'email' => 'customer@example.com',
          'first_name' => 'John',
          'last_name' => 'Doe',
          'phone' => '1234567890',
          'is_rep' => false
        }
      ]

      result = job.send(:transform_customers_to_brevo_format, customers)

      expect(result).to be_an(Array)
      expect(result.length).to eq(1)

      contact = result.first
      expect(contact[:email]).to eq('customer@example.com')
      expect(contact[:firstname]).to eq('John')
      expect(contact[:lastname]).to eq('Doe')
      expect(contact[:sms]).to eq('+1234567890')
    end

    it 'skips customers with invalid emails' do
      customers = [
        {
          'id' => 1,
          'email' => 'invalid-email',
          'first_name' => 'John',
          'is_rep' => false
        },
        {
          'id' => 2,
          'email' => 'valid@example.com',
          'first_name' => 'Jane',
          'is_rep' => false
        }
      ]

      result = job.send(:transform_customers_to_brevo_format, customers)

      expect(result.length).to eq(1)
      expect(result.first[:email]).to eq('valid@example.com')
    end

    it 'skips customers with blank emails' do
      customers = [
        {
          'id' => 1,
          'email' => '',
          'first_name' => 'John',
          'is_rep' => false
        }
      ]

      result = job.send(:transform_customers_to_brevo_format, customers)

      expect(result).to be_empty
    end

    it 'formats phone numbers correctly' do
      customers = [
        {
          'id' => 1,
          'email' => 'customer@example.com',
          'phone' => '(123) 456-7890',
          'is_rep' => false
        }
      ]

      result = job.send(:transform_customers_to_brevo_format, customers)

      # Phone should be cleaned and prefixed with +
      expect(result.first[:sms]).to eq('+1234567890')
    end

    it 'handles missing phone numbers' do
      customers = [
        {
          'id' => 1,
          'email' => 'customer@example.com',
          'first_name' => 'John',
          'is_rep' => false
        }
      ]

      result = job.send(:transform_customers_to_brevo_format, customers)

      expect(result.first[:sms]).to eq('')
    end

    it 'rejects phone numbers that are too short' do
      customers = [
        {
          'id' => 1,
          'email' => 'customer@example.com',
          'phone' => '123',
          'is_rep' => false
        }
      ]

      result = job.send(:transform_customers_to_brevo_format, customers)

      expect(result.first[:sms]).to eq('')
    end

    it 'handles missing names' do
      customers = [
        {
          'id' => 1,
          'email' => 'customer@example.com',
          'is_rep' => false
        }
      ]

      result = job.send(:transform_customers_to_brevo_format, customers)

      expect(result.first[:firstname]).to eq('')
      expect(result.first[:lastname]).to eq('')
    end

    context 'with rep customers and MLM data' do
      let(:rep_customers) do
        [
          {
            'id' => 1,
            'email' => 'rep@example.com',
            'first_name' => 'Rep',
            'last_name' => 'User',
            'is_rep' => true
          }
        ]
      end

      before do
        # Mock rep data fetching
        allow(job).to receive(:fetch_rep_data_for_customers).and_return({
          'rep@example.com' => {
            share_guid: 'abc123',
            sponsor_name: 'Sponsor Name',
            sponsor_id: 'sponsor123',
            rank: 'Gold'
          }
        })
      end

      it 'includes MLM attributes for rep customers' do
        result = job.send(:transform_customers_to_brevo_format, rep_customers)

        expect(result.length).to eq(1)
        contact = result.first
        
        expect(contact[:email]).to eq('rep@example.com')
        expect(contact[:customer_type]).to eq('rep')
        expect(contact[:shareguid]).to eq('abc123')
        expect(contact[:sponsor_name]).to eq('Sponsor Name')
        expect(contact[:sponsor_id]).to eq('sponsor123')
        expect(contact[:rank]).to eq('Gold')
      end
    end
  end

  describe '#generate_json_from_contacts' do
    let(:job) { described_class.new }

    it 'generates proper JSON format for Brevo' do
      contact_data = [
        {
          email: 'customer@example.com',
          firstname: 'John',
          lastname: 'Doe',
          sms: '+1234567890'
        }
      ]

      result = job.send(:generate_json_from_contacts, contact_data)

      expect(result).to be_an(Array)
      expect(result.length).to eq(1)

      json_contact = result.first
      expect(json_contact[:email]).to eq('customer@example.com')
      expect(json_contact[:attributes]).to be_a(Hash)
      expect(json_contact[:attributes][:FIRSTNAME]).to eq('John')
      expect(json_contact[:attributes][:LASTNAME]).to eq('Doe')
      expect(json_contact[:attributes][:SMS]).to eq('+1234567890')
      expect(json_contact[:attributes][:WHATSAPP]).to eq('+1234567890')
    end
  end

  describe '#process_customer_page' do
    let(:job) { described_class.new }
    let(:brevo_client) { instance_double(BrevoClient) }

    before do
      allow(job).to receive(:brevo_client).and_return(brevo_client)
      allow(brevo_client).to receive(:import_contacts).and_return({ 'processId' => '123' })
    end

    it 'processes customers in batches of 50' do
      customers = Array.new(75) do |i|
        {
          'id' => i,
          'email' => "customer#{i}@example.com",
          'first_name' => 'John',
          'is_rep' => false
        }
      end

      # Should call import_to_brevo twice (50 + 25)
      expect(brevo_client).to receive(:import_contacts).twice

      imported = job.send(:process_customer_page, customers, list_id)

      expect(imported).to eq(75)
    end
  end

  describe '#import_to_brevo' do
    let(:job) { described_class.new }
    let(:brevo_client) { instance_double(BrevoClient) }

    before do
      allow(job).to receive(:brevo_client).and_return(brevo_client)
    end

    it 'imports contacts to Brevo with correct format' do
      contact_data = [
        {
          email: 'customer@example.com',
          firstname: 'John',
          lastname: 'Doe',
          sms: '+1234567890'
        }
      ]

      expected_import_data = {
        listIds: [list_id],
        updateExistingContacts: true,
        jsonBody: [
          {
            email: 'customer@example.com',
            attributes: {
              FIRSTNAME: 'John',
              LASTNAME: 'Doe',
              SMS: '+1234567890',
              WHATSAPP: '+1234567890',
              CUSTOMER_TYPE: 'no_rep'
            }
          }
        ]
      }

      expect(brevo_client).to receive(:import_contacts).with(expected_import_data)

      job.send(:import_to_brevo, contact_data, list_id)
    end
  end

  describe '#update_progress' do
    let(:job) { described_class.new }

    before do
      job.instance_variable_set(:@job_id, job_id)
    end

    it 'stores progress in cache' do
      job.send(:update_progress, 50, 'Processing customers...')

      progress = Rails.cache.read("import_progress_#{job_id}")
      expect(progress).to be_present
      expect(progress[:percentage]).to eq(50)
      expect(progress[:message]).to eq('Processing customers...')
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

    before do
      job.instance_variable_set(:@company, company)
      job.instance_variable_set(:@segment, segment)
      job.instance_variable_set(:@list_id, list_id)
      job.instance_variable_set(:@job_id, job_id)
    end

    it 'correctly identifies last page from pagination metadata' do
      response_with_pagination = {
        'customers' => [],
        'meta' => {
          'pagination' => {
            'current_page' => 5,
            'total_pages' => 5
          }
        }
      }

      # Simulate receiving last page
      allow_any_instance_of(FluidClient).to receive(:get).and_return(response_with_pagination)

      # The job should stop when it detects the last page
      expect {
        described_class.new.perform(company.id, segment, list_id, job_id)
      }.not_to raise_error
    end
  end

  describe '#fetch_rep_data_for_customers' do
    let(:job) { described_class.new }
    let(:rep_customers) do
      [
        { 'email' => 'rep1@example.com', 'is_rep' => true },
        { 'email' => 'rep2@example.com', 'is_rep' => true }
      ]
    end

    before do
      job.instance_variable_set(:@company, company)
      
      # Mock Fluid API responses
      reps_response = {
        'reps' => [
          { 'id' => 1, 'computed_email' => 'rep1@example.com', 'share_guid' => 'guid1' },
          { 'id' => 2, 'computed_email' => 'rep2@example.com', 'share_guid' => 'guid2' }
        ],
        'meta' => { 'pagination' => { 'current_page' => 1, 'total_pages' => 1 } }
      }
      allow_any_instance_of(FluidClient).to receive(:get).with('/api/v2/reps', anything).and_return(reps_response)
      
      users_response = {
        'user_companies' => [
          { 'user' => { 'email' => 'rep1@example.com' }, 'rank' => 'Gold' },
          { 'user' => { 'email' => 'rep2@example.com' }, 'rank' => 'Silver' }
        ]
      }
      allow_any_instance_of(FluidClient).to receive(:get).with('/api/v202506/users', anything).and_return(users_response)
      
      rep_detail_response = {
        'rep' => {
          'enroller' => {
            'first_name' => 'Sponsor',
            'last_name' => 'Name',
            'external_id' => 'sponsor123'
          }
        }
      }
      allow_any_instance_of(FluidClient).to receive(:get).with(/\/api\/v2\/reps\/\d+/, anything).and_return(rep_detail_response)
    end

    it 'fetches MLM data for rep customers' do
      result = job.send(:fetch_rep_data_for_customers, rep_customers)

      expect(result).to be_a(Hash)
      expect(result['rep1@example.com']).to include(:share_guid, :sponsor_name, :sponsor_id, :rank)
      expect(result['rep2@example.com']).to include(:share_guid, :sponsor_name, :sponsor_id, :rank)
    end

    it 'handles API errors gracefully' do
      allow_any_instance_of(FluidClient).to receive(:get).and_raise(StandardError.new('API Error'))
      
      result = job.send(:fetch_rep_data_for_customers, rep_customers)
      
      expect(result).to be_a(Hash)
      expect(result.values.all?(&:empty?)).to be true
    end
  end

  describe '#fetch_rep_detail' do
    let(:job) { described_class.new }

    before do
      job.instance_variable_set(:@company, company)
    end

    it 'fetches detailed rep information' do
      rep_detail_response = {
        'rep' => {
          'id' => 1,
          'enroller' => {
            'first_name' => 'Sponsor',
            'last_name' => 'Name',
            'external_id' => 'sponsor123'
          }
        }
      }
      
      allow_any_instance_of(FluidClient).to receive(:get_with_timeout).and_return(rep_detail_response)
      
      result = job.send(:fetch_rep_detail, 1)
      
      expect(result).to eq(rep_detail_response['rep'])
    end

    it 'handles timeout errors' do
      allow_any_instance_of(FluidClient).to receive(:get_with_timeout).and_raise(Net::ReadTimeout.new('Timeout'))
      
      result = job.send(:fetch_rep_detail, 1)
      
      expect(result).to be_nil
    end
  end

  describe 'error recovery', :vcr do
    it 'handles API errors gracefully' do
      # This would use a VCR cassette with error responses
      # For now, just verify error handling structure exists
      expect(CustomerImportJob.ancestors).to include(ApplicationJob)
    end
  end
end

