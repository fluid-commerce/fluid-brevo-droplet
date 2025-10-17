# frozen_string_literal: true

class ActivityLogsController < ApplicationController
  before_action :authenticate_dri
  before_action :set_company

  def index
    @logs = @company.activity_logs.recent.limit(100)
    
    respond_to do |format|
      format.html
      format.json { render json: @logs }
    end
  end

  def clear
    Rails.logger.info "Clearing activity logs for company #{@company.id}"
    @company.activity_logs.destroy_all
    Rails.logger.info "Activity logs cleared successfully"
    
    respond_to do |format|
      format.html { redirect_to activity_logs_path, notice: 'Activity logs cleared successfully.' }
      format.json { render json: { success: true, message: 'Activity logs cleared successfully.' }, status: :ok }
    end
  rescue => e
    Rails.logger.error "Error clearing activity logs: #{e.message}"
    respond_to do |format|
      format.html { redirect_to activity_logs_path, alert: 'Failed to clear activity logs.' }
      format.json { render json: { success: false, message: 'Failed to clear activity logs.' }, status: :internal_server_error }
    end
  end

  private

  def authenticate_dri
    droplet_installation_uuid = params[:dri] || session[:droplet_installation_uuid]

    unless droplet_installation_uuid.present?
      respond_to do |format|
        format.html { render :index, status: :unauthorized, locals: { error: "Authentication required. Please provide a valid droplet installation UUID." } }
        format.json { render json: { error: "Authentication droplet_installation_uuid missing" }, status: :unauthorized }
      end
      return
    end

    session[:droplet_installation_uuid] = droplet_installation_uuid
  end

  def set_company
    @company = Company.includes(:integration_setting).find_by(droplet_installation_uuid: session[:droplet_installation_uuid] || params[:dri])
    
    unless @company
      respond_to do |format|
        format.html { render :index, status: :not_found, locals: { error: "Company not found. Please check your droplet installation UUID." } }
        format.json { render json: { error: "Company not found" }, status: :not_found }
      end
      return
    end
  end
end
