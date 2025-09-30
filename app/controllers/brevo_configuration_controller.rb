# frozen_string_literal: true

class BrevoConfigurationController < ApplicationController
  before_action :authenticate_dri
  before_action :set_company
  before_action :ensure_company_exist
  before_action :ensure_credentials_exist, only: [:verify_connection, :verify_email, :manual_sync]

  def show
    # Get folder info if available
    folder_info = nil
    if @company.integration_setting&.brevo_folder_id.present?
      begin
        brevo_client = BrevoClient.new(@company.integration_setting.credentials.dig('brevo', 'api_key'))
        folder_info = brevo_client.get_folder(@company.integration_setting.brevo_folder_id)
      rescue => e
        Rails.logger.warn "Failed to get folder info: #{e.message}"
      end
    end

    @company_data = {
      company: @company.as_json(include: :integration_setting),
      lists: @company.integration_setting&.brevo_lists || [],
      segment_mappings: @company.integration_setting&.segment_mappings || {},
      folder_info: folder_info
    }

    respond_to do |format|
      format.html
      format.json { render json: @company_data }
    end
  end

  def update
    # Handle API key parameter separately
    if params[:brevo_api_key].present?
      # Create integration_setting if it doesn't exist
      @company.integration_setting ||= @company.build_integration_setting
      @company.integration_setting.credentials ||= {}
      @company.integration_setting.credentials['brevo'] ||= {}
      @company.integration_setting.credentials['brevo']['api_key'] = params[:brevo_api_key]
      
      # Save the integration_setting
      if @company.integration_setting.save
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, notice: 'Brevo API key updated successfully!' }
          format.json { render json: { success: true, message: 'Brevo API key updated successfully!' } }
        end
      else
        respond_to do |format|
          format.html { render :show, status: :unprocessable_entity, locals: { error: "Failed to save API key: #{@company.integration_setting.errors.full_messages.join(', ')}" } }
          format.json { render json: { success: false, error: "Failed to save API key: #{@company.integration_setting.errors.full_messages.join(', ')}" }, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.html { render :show, status: :unprocessable_entity, locals: { error: "API key is required." } }
        format.json { render json: { success: false, error: "API key is required." }, status: :unprocessable_entity }
      end
    end
  end

  def verify_connection
    api_key = @company.integration_setting.credentials.dig('brevo', 'api_key')
    Rails.logger.info "Starting Brevo connection verification with API key: #{api_key.present? ? "#{api_key[0..10]}..." : 'nil'}"
    
    config_service = Brevo::ConfigurationService.new(api_key)
    result = config_service.validate_api_key
    
    Rails.logger.info "Brevo connection result: #{result.inspect}"
    
    if result[:valid]
        success_message = if result[:lists_count] && result[:lists_count] > 0
          "Brevo connection verified successfully! Found #{result[:lists_count]} contact lists."
        else
          "Brevo connection verified successfully!"
        end
        
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, notice: success_message }
          format.json { render json: { success: true, message: success_message } }
        end
      else
      user_friendly_error = case result[:error]
      when /Invalid API key/i, /Unauthorized/i
        "Invalid API key. Please check your Brevo API key and try again."
      when /Rate Limited/i
        "Too many requests. Please wait a moment and try again."
      when /Server Error/i
        "Brevo service is temporarily unavailable. Please try again later."
      else
        "Connection failed. Please check your API key and try again."
      end
      
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: user_friendly_error }
        format.json { render json: { success: false, error: user_friendly_error }, status: :unprocessable_entity }
      end
    end
  rescue => e
    user_friendly_error = "Connection failed. Please check your API key and try again."
    Rails.logger.error "Brevo connection error: #{e.class.name}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
    
    respond_to do |format|
      format.html { redirect_to brevo_configuration_path, alert: user_friendly_error }
      format.json { render json: { success: false, error: user_friendly_error }, status: :unprocessable_entity }
    end
  end

  def verify_email
    # Send a test email to verify the sender email works
    test_email = params[:test_email].presence || @company.fluid_shop&.split('.')&.first || 'test'
    
    email_service = Brevo::EmailService.new(@company.integration_setting.credentials.dig('brevo', 'api_key'))
    
    result = email_service.send_transactional_email(
      sender_name: @company.name,
      sender_email: "#{test_email}@#{@company.fluid_shop}",
      recipients: [{ email: @company.fluid_shop&.split('.')&.first || 'test@example.com', name: 'Test' }],
      subject: "Brevo Email Verification - #{@company.name}",
      html_content: "<h1>Email Verification Successful!</h1><p>This email confirms that your Brevo integration is working correctly.</p>",
      text_content: "Email Verification Successful!\n\nThis email confirms that your Brevo integration is working correctly."
    )
    
    respond_to do |format|
      format.html { redirect_to brevo_configuration_path, notice: 'Test email sent successfully! Check your inbox.' }
      format.json { render json: { success: true, message: 'Test email sent successfully! Check your inbox.' } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to brevo_configuration_path, alert: "Email verification failed: #{e.message}" }
      format.json { render json: { success: false, error: "Email verification failed: #{e.message}" }, status: :unprocessable_entity }
    end
  end

  def manual_sync
    # Placeholder for manual sync - just show a message for now
    respond_to do |format|
      format.html { redirect_to brevo_configuration_path, notice: 'Manual sync feature will be implemented soon!' }
      format.json { render json: { success: true, message: 'Manual sync feature will be implemented soon!' } }
    end
  end

  def sync_lists
    Rails.logger.info "Syncing Brevo lists for company #{@company.id}"
    
    if @company.integration_setting&.sync_brevo_lists!
      lists = @company.integration_setting.available_lists
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, notice: "Successfully synced #{lists.length} lists from Brevo!" }
        format.json { render json: { success: true, message: "Successfully synced #{lists.length} lists from Brevo!", lists: lists } }
      end
    else
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: 'Failed to sync lists. Please check your API key and try again.' }
        format.json { render json: { success: false, error: 'Failed to sync lists. Please check your API key and try again.' }, status: :unprocessable_entity }
      end
    end
  end

  def update_default_list
    list_id = params[:default_list_id]
    
    if list_id.present?
      @company.integration_setting.default_list_id = list_id.to_i
      
      if @company.integration_setting.save
        list_name = @company.integration_setting.default_list_name
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, notice: "Default list updated to: #{list_name}" }
          format.json { render json: { success: true, message: "Default list updated to: #{list_name}" } }
        end
      else
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, alert: 'Failed to update default list.' }
          format.json { render json: { success: false, error: 'Failed to update default list.' }, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: 'Please select a valid list.' }
        format.json { render json: { success: false, error: 'Please select a valid list.' }, status: :unprocessable_entity }
      end
    end
  end

  def preview_customers
    limit = params[:limit]&.to_i || 10
    offset = params[:offset]&.to_i || 0
    
    begin
      import_service = Brevo::CustomerImportService.new(@company)
      customers = import_service.preview_customers(limit: limit, offset: offset)
      
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, notice: "Found #{customers.length} customers" }
        format.json { render json: { success: true, customers: customers, count: customers.length } }
      end
    rescue => e
      Rails.logger.error "Error previewing customers: #{e.message}"
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: "Failed to preview customers: #{e.message}" }
        format.json { render json: { success: false, error: "Failed to preview customers: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end

  def import_customers
    limit = params[:limit]&.to_i || 50
    offset = params[:offset]&.to_i || 0
    
    begin
      import_service = Brevo::CustomerImportService.new(@company)
      result = import_service.import_customers(limit: limit, offset: offset)
      
      if result[:success]
        message = "Successfully imported #{result[:imported_count]} customers to Brevo"
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, notice: message }
          format.json { render json: { success: true, message: message, result: result } }
        end
      else
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, alert: result[:error] }
          format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error "Error importing customers: #{e.message}"
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: "Failed to import customers: #{e.message}" }
        format.json { render json: { success: false, error: "Failed to import customers: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end

  def update_segment_mapping
    segment = params[:segment]
    list_id = params[:list_id]
    
    unless %w[everyone_list_id customer_list_id rep_list_id].include?(segment)
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: 'Invalid segment type.' }
        format.json { render json: { success: false, error: 'Invalid segment type.' }, status: :unprocessable_entity }
      end
      return
    end
    
    begin
      @company.integration_setting.send("#{segment}=", list_id)
      
      if @company.integration_setting.save
        list_name = @company.integration_setting.get_list_name(list_id) if list_id.present?
        message = list_name ? "Updated #{segment.humanize} to: #{list_name}" : "Cleared #{segment.humanize}"
        
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, notice: message }
          format.json { render json: { success: true, message: message } }
        end
      else
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, alert: 'Failed to update segment mapping.' }
          format.json { render json: { success: false, error: 'Failed to update segment mapping.' }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error "Error updating segment mapping: #{e.message}"
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: "Failed to update segment mapping: #{e.message}" }
        format.json { render json: { success: false, error: "Failed to update segment mapping: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end

  def create_list
    list_name = params[:list_name]
    segment = params[:segment]
    
    unless list_name.present? && %w[everyone_list_id customer_list_id rep_list_id].include?(segment)
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: 'List name and segment are required.' }
        format.json { render json: { success: false, error: 'List name and segment are required.' }, status: :unprocessable_entity }
      end
      return
    end
    
    begin
      # Get or create the FluidBrevoDropletContacts folder
      folder_id = @company.integration_setting.get_or_create_brevo_folder!
      
      brevo_client = BrevoClient.new(@company.integration_setting.credentials.dig('brevo', 'api_key'))
      
      list_response = brevo_client.create_list({ 
        name: list_name, 
        folderId: folder_id 
      })
      
      if list_response && list_response['id']
        # Update the segment mapping with the new list
        @company.integration_setting.send("#{segment}=", list_response['id'].to_s)
        
        if @company.integration_setting.save
          # Refresh the lists to include the new one
          @company.integration_setting.sync_brevo_lists!
          
          respond_to do |format|
            format.html { redirect_to brevo_configuration_path, notice: "Created list '#{list_name}' and updated #{segment.humanize}" }
            format.json { render json: { success: true, message: "Created list '#{list_name}'", list: list_response } }
          end
        else
          respond_to do |format|
            format.html { redirect_to brevo_configuration_path, alert: 'List created but failed to update segment mapping.' }
            format.json { render json: { success: false, error: 'List created but failed to update segment mapping.' }, status: :unprocessable_entity }
          end
        end
      else
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, alert: 'Failed to create list in Brevo.' }
          format.json { render json: { success: false, error: 'Failed to create list in Brevo.' }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error "Error creating list: #{e.message}"
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: "Failed to create list: #{e.message}" }
        format.json { render json: { success: false, error: "Failed to create list: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end

  def preview_segment
    segment = params[:segment]
    
    unless %w[everyone_list_id customer_list_id rep_list_id].include?(segment)
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: 'Invalid segment type.' }
        format.json { render json: { success: false, error: 'Invalid segment type.' }, status: :unprocessable_entity }
      end
      return
    end
    
    begin
      import_service = Brevo::CustomerImportService.new(@company)
      customers = import_service.preview_customers_for_segment(segment)
      
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, notice: "Found #{customers.length} customers for #{segment.humanize}" }
        format.json { render json: { success: true, customers: customers, count: customers.length } }
      end
    rescue => e
      Rails.logger.error "Error previewing segment #{segment}: #{e.message}"
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: "Failed to preview customers: #{e.message}" }
        format.json { render json: { success: false, error: "Failed to preview customers: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end

  def sync_segment
    segment = params[:segment]
    
    unless %w[everyone_list_id customer_list_id rep_list_id].include?(segment)
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: 'Invalid segment type.' }
        format.json { render json: { success: false, error: 'Invalid segment type.' }, status: :unprocessable_entity }
      end
      return
    end
    
    begin
      import_service = Brevo::CustomerImportService.new(@company)
      result = import_service.import_customers_for_segment(segment)
      
      if result[:success]
        message = "Successfully synced #{result[:imported_count]} customers to #{segment.humanize}"
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, notice: message }
          format.json { render json: { success: true, message: message, result: result } }
        end
      else
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, alert: result[:error] }
          format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error "Error syncing segment #{segment}: #{e.message}"
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: "Failed to sync customers: #{e.message}" }
        format.json { render json: { success: false, error: "Failed to sync customers: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end

  def get_folder_info
    begin
      folder_id = @company.integration_setting.brevo_folder_id
      
      if folder_id.present?
        brevo_client = BrevoClient.new(@company.integration_setting.credentials.dig('brevo', 'api_key'))
        folder_info = brevo_client.get_folder(folder_id)
        
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, notice: "Folder: #{folder_info['name']}" }
          format.json { render json: { success: true, folder: folder_info } }
        end
      else
        respond_to do |format|
          format.html { redirect_to brevo_configuration_path, alert: 'No folder configured' }
          format.json { render json: { success: false, error: 'No folder configured' }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error "Error getting folder info: #{e.message}"
      respond_to do |format|
        format.html { redirect_to brevo_configuration_path, alert: "Failed to get folder info: #{e.message}" }
        format.json { render json: { success: false, error: "Failed to get folder info: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end

  private


  def authenticate_dri
    droplet_installation_uuid = params[:dri] || session[:droplet_installation_uuid]

    unless droplet_installation_uuid.present?
      respond_to do |format|
        format.html { render :show, status: :unauthorized, locals: { error: "Authentication required. Please provide a valid droplet installation UUID." } }
        format.json { render json: { error: "Authentication droplet_installation_uuid missing" }, status: :unauthorized }
      end
      return
    end

    session[:droplet_installation_uuid] = droplet_installation_uuid
  end

  def ensure_company_exist
    # First check if company exists
    unless @company
      respond_to do |format|
        format.html { render :show, status: :not_found, locals: { error: "Company does not exist." } }
        format.json { render json: { error: "Company does not exist." }, status: :not_found }
      end
      return
    end

    true
  end

  def ensure_credentials_exist
    # Then check if credentials exist
    unless @company.integration_setting&.credentials&.dig('brevo', 'api_key').present?
      respond_to do |format|
        format.html { render :show, status: :unprocessable_entity, locals: { error: "Please configure your Brevo API key first." } }
        format.json { render json: { error: "Please configure your Brevo API key first." }, status: :unprocessable_entity }
      end
      return
    end

    true
  end

  def set_company
    @company = Company.includes(:integration_setting).find_by(droplet_installation_uuid: session[:droplet_installation_uuid] || params[:dri])
    
    unless @company
      respond_to do |format|
        format.html { render :show, status: :not_found, locals: { error: "Company not found. Please check your droplet installation UUID." } }
        format.json { render json: { error: "Company not found" }, status: :not_found }
      end
      return
    end
  end

  def brevo_params
    params.permit(:brevo_api_key)
  end
end
