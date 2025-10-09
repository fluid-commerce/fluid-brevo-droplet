# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BrevoClient do
  let(:api_key) { ENV['BREVO_API_KEY'] || 'test_api_key' }
  let(:client) { described_class.new(api_key) }

  describe '#initialize' do
    it 'sets the api key' do
      expect(client.api_key).to eq(api_key)
    end

    context 'when no api key is provided' do
      let(:client) { described_class.new }

      it 'falls back to environment variable' do
        expect(client.api_key).to eq(ENV['BREVO_API_KEY'])
      end
    end
  end

  describe 'Contacts API methods', :vcr do
    # Use fixed email for VCR cassette matching
    let(:test_email) { 'test_vcr_contact@example.com' }

    describe '#create_contact' do
      it 'creates a new contact' do
        contact_params = {
          email: test_email,
          attributes: {
            FIRSTNAME: 'Test',
            LASTNAME: 'User'
          },
          listIds: []
        }

        response = client.create_contact(contact_params)

        expect(response).to be_a(Hash)
        expect(response).to have_key('id')
      end
    end

    describe '#get_contacts' do
      it 'retrieves list of contacts' do
        response = client.get_contacts(limit: 10, offset: 0)

        expect(response).to be_a(Hash)
        expect(response).to have_key('contacts')
        expect(response['contacts']).to be_an(Array)
      end
    end

    describe '#import_contacts' do
      it 'imports contacts in bulk' do
        # First create a list to import contacts into
        list_response = client.get_lists(limit: 1)
        list_id = list_response.dig('lists', 0, 'id')

        import_params = {
          jsonBody: [
            {
              email: 'import_test_vcr@example.com',
              attributes: {
                FIRSTNAME: 'Bulk',
                LASTNAME: 'Import'
              }
            }
          ],
          listIds: list_id ? [list_id] : [],
          updateExistingContacts: true
        }

        response = client.import_contacts(import_params)

        expect(response).to be_a(Hash)
        expect(response).to have_key('processId')
      end
    end
  end

  describe 'Lists API methods', :vcr do
    # Use fixed list name for VCR cassette matching
    let(:test_list_name) { 'Test List VCR' }

    describe '#create_list' do
      it 'creates a new contact list' do
        # First get or create a folder
        folders_response = client.get_folders
        folder_id = if folders_response['folders']&.any?
          folders_response['folders'].first['id']
        else
          folder_response = client.create_folder(name: 'Test Folder VCR')
          folder_response['id']
        end

        list_params = {
          name: test_list_name,
          folderId: folder_id
        }

        response = client.create_list(list_params)

        expect(response).to be_a(Hash)
        expect(response).to have_key('id')
        expect(response['id']).to be_a(Integer)
      end
    end

    describe '#get_lists' do
      it 'retrieves all contact lists' do
        response = client.get_lists(limit: 50, offset: 0)

        expect(response).to be_a(Hash)
        expect(response).to have_key('lists')
        expect(response['lists']).to be_an(Array)
      end
    end
  end

  describe 'Folders API methods', :vcr do
    # Use fixed folder name for VCR cassette matching
    let(:test_folder_name) { 'Test Folder VCR' }

    describe '#create_folder' do
      it 'creates a new folder' do
        folder_params = { name: test_folder_name }

        response = client.create_folder(folder_params)

        expect(response).to be_a(Hash)
        expect(response).to have_key('id')
      end
    end
  end

  describe 'eCommerce API methods', :vcr do
    describe '#create_products_batch' do
      it 'creates products in batch' do
        products = [
          {
            id: 'test_product_vcr_123',
            name: 'Test Product VCR',
            url: 'https://example.com/product',
            price: 99.99,
            categories: ['1']
          }
        ]

        response = client.create_products_batch(products)

        expect(response).to be_a(Hash)
      end
    end

    describe '#create_categories_batch' do
      it 'creates categories in batch' do
        categories = [
          {
            id: 'test_category_vcr_123',
            name: 'Test Category VCR',
            url: 'https://example.com/category'
          }
        ]

        response = client.create_categories_batch(categories)

        expect(response).to be_a(Hash)
      end
    end

    describe '#create_orders_batch' do
      it 'creates orders in batch' do
        orders = [
          {
            id: 'test_order_vcr_123',
            createdAt: '2025-01-01T12:00:00Z',
            updatedAt: '2025-01-01T12:00:00Z',
            status: 'pending',
            amount: 99.99,
            identifiers: {
              email_id: 'test@example.com'
            },
            products: [
              {
                productId: '1',
                quantity: 1,
                price: 99.99
              }
            ]
          }
        ]

        response = client.create_orders_batch(orders)

        # Response can be a Hash or String (JSON) depending on Brevo's response
        expect([Hash, String]).to include(response.class)
        
        # If it's a string, it should be valid JSON
        if response.is_a?(String)
          parsed = JSON.parse(response)
          expect(parsed).to be_a(Hash)
        end
      end
    end
  end
end
