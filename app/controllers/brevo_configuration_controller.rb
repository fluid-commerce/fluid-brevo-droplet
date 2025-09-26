# frozen_string_literal: true

class BrevoConfigurationController < ApplicationController
  before_action :authenticate_dri
  before_action :set_company
  before_action :ensure_company_exist
  before_action :ensure_credentials_exist, only: [:verify_connection, :verify_email, :manual_sync]

  def show
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
