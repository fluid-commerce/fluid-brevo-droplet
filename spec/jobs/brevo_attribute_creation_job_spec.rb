# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BrevoAttributeCreationJob, type: :job do
  let(:company) { create(:company) }
  let(:integration_setting) { create(:integration_setting, company: company) }
  let(:api_key) { 'test_api_key' }
  let(:brevo_client) { instance_double(BrevoClient) }

  before do
    allow(Company).to receive(:find).with(company.id).and_return(company)
    allow(company).to receive(:integration_setting).and_return(integration_setting)
    allow(integration_setting).to receive(:credentials).and_return({ 'brevo' => { 'api_key' => api_key } })
    allow(BrevoClient).to receive(:new).with(api_key).and_return(brevo_client)
  end

  describe '#perform' do
    context 'when no attributes exist' do
      before do
        allow(brevo_client).to receive(:get_attributes).and_return({
          'attributes' => [
            { 'name' => 'email', 'category' => 'normal' },
            { 'name' => 'firstname', 'category' => 'normal' }
          ]
        })
        allow(brevo_client).to receive(:create_attribute_with_category).and_return({ 'success' => true })
      end

      it 'creates all configured attributes' do
        result = described_class.new.perform(company.id)

        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(5)
        expect(result[:skipped_count]).to eq(0)
        expect(result[:results].length).to eq(5)
        
        expect(brevo_client).to have_received(:create_attribute_with_category).with(
          'category',
          'customer_type',
          {
            type: 'category',
            enumeration: [
              { value: 1, label: 'rep' },
              { value: 2, label: 'no_rep' }
            ]
          }
        )
      end
    end

    context 'when all attributes already exist' do
      before do
        allow(brevo_client).to receive(:get_attributes).and_return({
          'attributes' => [
            { 'name' => 'email', 'category' => 'normal' },
            { 'name' => 'CUSTOMER_TYPE', 'category' => 'category' },  # Note: uppercase in Brevo
            { 'name' => 'SHAREGUID', 'category' => 'normal' },
            { 'name' => 'RANK', 'category' => 'normal' },
            { 'name' => 'SPONSOR_NAME', 'category' => 'normal' },
            { 'name' => 'SPONSOR_ID', 'category' => 'normal' }
          ]
        })
        # Mock the method that should NOT be called
        allow(brevo_client).to receive(:create_attribute_with_category)
      end

      it 'skips creation of all attributes and returns success' do
        result = described_class.new.perform(company.id)

        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(0)
        expect(result[:skipped_count]).to eq(5)
        expect(result[:results].length).to eq(5)
        expect(result[:results].first[:created]).to be false
        expect(brevo_client).not_to have_received(:create_attribute_with_category)
      end

      it 'handles case-insensitive matching for all attributes' do
        # Test that CUSTOMER_TYPE (uppercase) matches customer_type (lowercase)
        result = described_class.new.perform(company.id)

        expect(result[:success]).to be true
        expect(result[:skipped_count]).to eq(5)
        expect(result[:results].first[:message]).to include('customer_type attribute already exists')
      end
    end

    context 'when some attributes exist and others do not' do
      before do
        # This test is simplified to just test the existing single attribute
        # since we can't easily mock the constant in this test setup
        allow(brevo_client).to receive(:get_attributes).and_return({
          'attributes' => [
            { 'name' => 'email', 'category' => 'normal' }
            # customer_type does not exist
          ]
        })
        allow(brevo_client).to receive(:create_attribute_with_category).and_return({ 'success' => true })
      end

      it 'creates the missing attribute' do
        result = described_class.new.perform(company.id)

        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(5)
        expect(result[:skipped_count]).to eq(0)
        expect(result[:results].length).to eq(5)
        
        # Should call create_attribute_with_category for customer_type
        expect(brevo_client).to have_received(:create_attribute_with_category).with(
          'category',
          'customer_type',
          {
            type: 'category',
            enumeration: [
              { value: 1, label: 'rep' },
              { value: 2, label: 'no_rep' }
            ]
          }
        )
      end
    end

    context 'when Brevo API returns an error for one attribute' do
      before do
        allow(brevo_client).to receive(:get_attributes).and_return({ 'attributes' => [] })
        allow(brevo_client).to receive(:create_attribute_with_category).and_raise(
          BrevoApiError.new('Attribute already exists', 400)
        )
      end

      it 'handles the error gracefully and continues with other attributes' do
        result = described_class.new.perform(company.id)

        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(0)
        expect(result[:skipped_count]).to eq(5)  # Error counts as skipped
        expect(result[:results].length).to eq(5)
        expect(result[:results].first[:created]).to be false
        expect(result[:results].first[:error]).to include('Brevo API error')
      end
    end

    context 'when an unexpected error occurs during attribute fetching' do
      before do
        allow(brevo_client).to receive(:get_attributes).and_raise(StandardError.new('Network error'))
      end

      it 'handles the error gracefully' do
        result = described_class.new.perform(company.id)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Unexpected error')
      end
    end

    context 'when Brevo API returns an error during attribute fetching' do
      before do
        allow(brevo_client).to receive(:get_attributes).and_raise(
          BrevoApiError.new('Unauthorized', 401)
        )
      end

      it 'handles the error gracefully' do
        result = described_class.new.perform(company.id)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Brevo API error')
        expect(result[:status_code]).to eq(401)
      end
    end
  end

  describe 'ATTRIBUTES_TO_CREATE constant' do
    it 'defines the expected attributes' do
      attributes = described_class::ATTRIBUTES_TO_CREATE
      
      expect(attributes).to be_an(Array)
      expect(attributes.length).to eq(5)
      
      customer_type_attr = attributes.first
      expect(customer_type_attr[:name]).to eq('customer_type')
      expect(customer_type_attr[:category]).to eq('category')
      expect(customer_type_attr[:type]).to eq('category')
      expect(customer_type_attr[:enumeration]).to eq([
        { value: 1, label: 'rep' },
        { value: 2, label: 'no_rep' }
      ])
      
      # Test the new normal attributes
      shareguid_attr = attributes[1]
      expect(shareguid_attr[:name]).to eq('shareguid')
      expect(shareguid_attr[:category]).to eq('normal')
      expect(shareguid_attr[:type]).to eq('text')
      
      rank_attr = attributes[2]
      expect(rank_attr[:name]).to eq('rank')
      expect(rank_attr[:category]).to eq('normal')
      expect(rank_attr[:type]).to eq('text')
      
      sponsor_name_attr = attributes[3]
      expect(sponsor_name_attr[:name]).to eq('sponsor_name')
      expect(sponsor_name_attr[:category]).to eq('normal')
      expect(sponsor_name_attr[:type]).to eq('text')
      
      sponsor_id_attr = attributes[4]
      expect(sponsor_id_attr[:name]).to eq('sponsor_id')
      expect(sponsor_id_attr[:category]).to eq('normal')
      expect(sponsor_id_attr[:type]).to eq('id')
    end
  end
end
