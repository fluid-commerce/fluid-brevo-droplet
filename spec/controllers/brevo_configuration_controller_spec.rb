# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BrevoConfigurationController, type: :controller do
  let(:company) { create(:company, :with_brevo_credentials) }
  let(:droplet_installation_uuid) { company.droplet_installation_uuid }

  before do
    # Set the session for authentication
    session[:droplet_installation_uuid] = droplet_installation_uuid
  end

  describe 'authentication' do
    context 'when droplet installation UUID is missing' do
      before do
        session[:droplet_installation_uuid] = nil
      end

      it 'returns unauthorized for HTML requests' do
        get :show

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for JSON requests' do
        get :show, format: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Authentication')
      end
    end

    context 'when droplet installation UUID is provided' do
      it 'authenticates successfully' do
        get :show

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET #show' do
    it 'returns company data with integration settings' do
      get :show, format: :json

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)

      expect(json_response).to have_key('company')
      expect(json_response).to have_key('lists')
      expect(json_response).to have_key('segment_mappings')
    end

    context 'when company has a Brevo folder', :vcr do
      let(:company) { create(:company, :with_brevo_credentials) }

      before do
        company.integration_setting.update(
          settings: { 'brevo_folder_id' => 123 }
        )
      end

      it 'includes folder info in the response' do
        get :show, format: :json

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('folder_info')
      end
    end

    it 'returns HTML view' do
      get :show

      expect(response).to have_http_status(:success)
      expect(response).to render_template(:show)
    end
  end

  describe 'POST #update' do
    context 'with valid API key' do
      let(:api_key) { 'valid_brevo_api_key' }

      it 'updates the Brevo API key' do
        post :update, params: { brevo_api_key: api_key }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['message']).to include('updated successfully')

        company.integration_setting.reload
        expect(company.integration_setting.credentials.dig('brevo', 'api_key')).to eq(api_key)
      end

      it 'creates integration_setting if it does not exist' do
        company.integration_setting&.destroy
        company.reload

        post :update, params: { brevo_api_key: api_key }, format: :json

        expect(response).to have_http_status(:success)
        company.reload
        expect(company.integration_setting).to be_present
        expect(company.integration_setting.credentials.dig('brevo', 'api_key')).to eq(api_key)
      end
    end

    context 'without API key' do
      it 'returns error' do
        post :update, params: {}, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('required')
      end
    end
  end

  describe 'POST #verify_connection', :vcr do
    context 'with valid credentials' do
      it 'verifies the connection successfully' do
        post :verify_connection, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['message']).to include('verified')
      end

      it 'activates eCommerce platform' do
        post :verify_connection, format: :json

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('ecommerce_activation')
      end
    end

    context 'with invalid credentials' do
      before do
        company.integration_setting.update(
          credentials: { 'brevo' => { 'api_key' => 'invalid_key' } }
        )
      end

      it 'returns error', :vcr do
        post :verify_connection, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to be_present
      end
    end

    context 'without credentials' do
      before do
        company.integration_setting.update(credentials: {})
      end

      it 'returns error for missing credentials' do
        post :verify_connection, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('API key')
      end
    end
  end

  describe 'POST #sync_lists', :vcr do
    it 'syncs lists from Brevo' do
      post :sync_lists, format: :json

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response).to have_key('lists')
    end

    context 'when sync fails' do
      before do
        allow_any_instance_of(IntegrationSetting).to receive(:sync_brevo_lists!).and_return(false)
      end

      it 'returns error' do
        post :sync_lists, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'POST #update_default_list' do
    let(:list_id) { 123 }

    before do
      company.integration_setting.update(
        settings: {
          'lists' => [
            { 'id' => 123, 'name' => 'Test List' }
          ]
        }
      )
    end

    it 'updates the default list' do
      post :update_default_list, params: { default_list_id: list_id }, format: :json

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true

      company.integration_setting.reload
      expect(company.integration_setting.default_list_id).to eq(list_id)
    end

    context 'without list_id' do
      it 'returns error' do
        post :update_default_list, params: {}, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'POST #update_segment_mapping' do
    let(:list_id) { '123' }
    let(:segment) { 'everyone_list_id' }

    it 'updates segment mapping' do
      post :update_segment_mapping, params: { segment: segment, list_id: list_id }, format: :json

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true

      company.integration_setting.reload
      expect(company.integration_setting.everyone_list_id).to eq(list_id)
    end

    context 'with invalid segment type' do
      it 'returns error' do
        post :update_segment_mapping, params: { segment: 'invalid_segment', list_id: list_id }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('Invalid segment')
      end
    end

    it 'allows clearing a segment mapping' do
      post :update_segment_mapping, params: { segment: segment, list_id: nil }, format: :json

      expect(response).to have_http_status(:success)
      company.integration_setting.reload
      expect(company.integration_setting.everyone_list_id).to be_nil
    end
  end

  describe 'POST #create_list', :vcr do
    let(:list_name) { 'Test List' }
    let(:segment) { 'everyone_list_id' }

    it 'creates a new list and updates segment mapping' do
      post :create_list, params: { list_name: list_name, segment: segment }, format: :json

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['message']).to include('Created list')
    end

    context 'without list name' do
      it 'returns error' do
        post :create_list, params: { segment: segment }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end

    context 'with invalid segment' do
      it 'returns error' do
        post :create_list, params: { list_name: list_name, segment: 'invalid' }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'POST #sync_segment' do
    let(:segment) { 'everyone_list_id' }
    let(:list_id) { '123' }

    before do
      company.integration_setting.update(
        settings: {
          'segment_mappings' => {
            'everyone_list_id' => list_id
          }
        }
      )
    end

    it 'starts customer import job' do
      expect(CustomerImportJob).to receive(:perform_later).and_return(double(job_id: 'test-job-id'))

      post :sync_segment, params: { segment: segment }, format: :json

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['message']).to include('started')
      expect(json_response).to have_key('job_id')
    end

    context 'without list configured' do
      before do
        company.integration_setting.update(
          settings: { 'segment_mappings' => {} }
        )
      end

      it 'returns error' do
        post :sync_segment, params: { segment: segment }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('No list configured')
      end
    end

    context 'with invalid segment' do
      it 'returns error' do
        post :sync_segment, params: { segment: 'invalid_segment' }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'GET #import_progress' do
    let(:job_id) { SecureRandom.uuid }

    context 'when progress data exists' do
      before do
        Rails.cache.write("import_progress_#{job_id}", {
          percentage: 50,
          message: 'Importing...',
          status: 'running'
        })
      end

      it 'returns progress data' do
        get :import_progress, params: { job_id: job_id }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['progress']['percentage']).to eq(50)
        expect(json_response['progress']['status']).to eq('running')
      end
    end

    context 'when final result exists' do
      before do
        Rails.cache.write("import_result_#{job_id}", {
          message: 'Completed successfully',
          total_imported: 100
        })
      end

      it 'returns final result with completed status' do
        get :import_progress, params: { job_id: job_id }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['progress']['percentage']).to eq(100)
        expect(json_response['progress']['status']).to eq('completed')
      end
    end

    context 'when no progress data exists' do
      it 'returns in_progress status' do
        get :import_progress, params: { job_id: job_id }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['progress']['status']).to eq('in_progress')
      end
    end

    context 'without job_id' do
      it 'returns error' do
        get :import_progress, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'GET #get_folder_info', :vcr do
    context 'when folder exists' do
      before do
        company.integration_setting.update(
          settings: { 'brevo_folder_id' => 123 }
        )
      end

      it 'returns folder information' do
        get :get_folder_info, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response).to have_key('folder')
      end
    end

    context 'when no folder configured' do
      before do
        company.integration_setting.update(settings: {})
      end

      it 'returns error' do
        get :get_folder_info, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('No folder')
      end
    end
  end

  describe 'POST #import_products' do
    it 'starts product import job' do
      expect(ProductImportJob).to receive(:perform_later).and_return(double(job_id: 'test-job-id'))

      post :import_products, format: :json

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['message']).to include('started')
      expect(json_response).to have_key('job_id')
    end
  end

  describe 'POST #import_categories' do
    it 'starts category import job' do
      expect(CategoryImportJob).to receive(:perform_later).and_return(double(job_id: 'test-job-id'))

      post :import_categories, format: :json

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['message']).to include('started')
      expect(json_response).to have_key('job_id')
    end
  end

  describe 'POST #import_orders' do
    it 'starts order import job' do
      expect(OrderImportJob).to receive(:perform_later).and_return(double(job_id: 'test-job-id'))

      post :import_orders, format: :json

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['message']).to include('started')
      expect(json_response).to have_key('job_id')
    end
  end

  describe 'error handling' do
    context 'when company does not exist' do
      before do
        session[:droplet_installation_uuid] = 'non-existent-uuid'
      end

      it 'returns not found' do
        get :show, format: :json

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('not found')
      end
    end

    context 'when credentials are missing for protected actions' do
      before do
        company.integration_setting.update(credentials: {})
      end

      it 'returns error for verify_connection' do
        post :verify_connection, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('API key')
      end

      it 'returns error for import_products' do
        post :import_products, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('API key')
      end
    end
  end

  describe 'session persistence' do
    it 'stores droplet_installation_uuid in session' do
      session[:droplet_installation_uuid] = nil

      get :show, params: { dri: droplet_installation_uuid }

      expect(session[:droplet_installation_uuid]).to eq(droplet_installation_uuid)
    end

    it 'uses session uuid if parameter not provided' do
      session[:droplet_installation_uuid] = droplet_installation_uuid

      get :show

      expect(response).to have_http_status(:success)
    end
  end
end

