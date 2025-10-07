# frozen_string_literal: true

require 'set'

class CategoryImportJob < ApplicationJob
  queue_as :default

  def perform(company_id, job_id = nil)
    @company = Company.find(company_id)
    @job_id = job_id || SecureRandom.uuid
    
    Rails.logger.info "Starting category import job #{@job_id} for company #{@company.id}"
    
    begin
      # Initialize progress tracking
      update_progress(0, "Starting category import...")
      
      # Import categories page by page
      page = 1
      per_page = 50
      total_imported = 0
      total_categories = nil
      imported_category_ids = Set.new
      
      loop do
        Rails.logger.info "Fetching categories page #{page}..."
        start_time = Time.current
        categories_response = fluid_client.get("/api/company/v1/categories", { page: page, per_page: per_page })
        api_time = Time.current - start_time
        Rails.logger.info "Fluid API call took #{api_time.round(2)}s"
        
        categories = categories_response['categories'] || []
        Rails.logger.info "Received #{categories.length} categories from Fluid API"
        
        # Get total count from first page if not already set
        if total_categories.nil?
          # Use pagination metadata as initial estimate, but we'll adjust based on actual categories found
          if categories_response['meta'] && categories_response['meta']['pagination']
            total_categories = categories_response['meta']['pagination']['total_count'] || 0
          else
            total_categories = categories.length
          end
          update_progress(10, "Found #{total_categories} categories to import (estimated)")
        end
        
        break if categories.empty?
        
        # If we got fewer categories than per_page, this is the last page
        if categories.length < per_page
          Rails.logger.info "Reached last page (#{categories.length} < #{per_page} categories), this is the final page"
          # Adjust total_categories to reflect actual count found
          total_categories = total_imported + categories.length
          Rails.logger.info "Adjusted total categories to actual count: #{total_categories}"
        end
        
        # Filter out already imported categories to avoid duplicates
        new_categories = categories.reject { |category| imported_category_ids.include?(category['id']) }
        
        if new_categories.empty?
          Rails.logger.info "No new categories on page #{page}, skipping to next page"
          page += 1
          next
        end
        
        progress_percentage = 10 + (total_imported * 80 / total_categories)
        update_progress(progress_percentage, "Importing categories page #{page}...")
        
        # Transform categories to Brevo format
        brevo_categories = transform_categories_to_brevo_format(new_categories)
        
        # Import to Brevo
        import_result = import_to_brevo(brevo_categories)
        
        # Track imported category IDs
        new_categories.each { |category| imported_category_ids.add(category['id']) }
        total_imported += new_categories.length
        
        update_progress(10 + (total_imported * 80 / total_categories), "Imported #{total_imported}/#{total_categories} categories")
        
        # Break if we've imported all categories OR if we've reached the last page
        break if total_imported >= total_categories || categories.length < per_page
        
        page += 1
      end
      
      # Final progress update
      update_progress(100, "Successfully imported #{total_imported} categories")
      
      Rails.logger.info "Total categories imported to Brevo: #{total_imported}"
      { success: true, total_imported: total_imported }
      
    rescue => e
      Rails.logger.error "Category import job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      update_progress(0, "Category import failed: #{e.message}")
      raise e
    end
  end

private

  def update_progress(percentage, message)
    progress_data = {
      status: percentage == 100 ? 'completed' : 'in_progress',
      percentage: percentage,
      message: message,
      timestamp: Time.current.iso8601
    }
    
    Rails.cache.write("category_import_progress_#{@job_id}", progress_data, expires_in: 1.hour)
    Rails.logger.info "Category import progress #{@job_id}: #{percentage}% - #{message}"
  end

  def transform_categories_to_brevo_format(categories)
    Rails.logger.info "Transforming #{categories.length} categories for Brevo"
    
    brevo_categories = categories.map do |category|
      {
        id: category['id'].to_s,
        name: category['title'] || category['name'] || 'Untitled Category',
        url: build_category_url(category)
      }
    end
    
    Rails.logger.info "Generated #{brevo_categories.length} Brevo categories"
    brevo_categories
  end

  def build_category_url(category)
    # Build category URL from slug or use ID
    if category['slug']
      "https://#{@company.fluid_shop}/categories/#{category['slug']}"
    else
      "https://#{@company.fluid_shop}/categories/#{category['id']}"
    end
  end

  def import_to_brevo(brevo_categories)
    Rails.logger.info "Importing #{brevo_categories.length} categories to Brevo"
    
    # Import in batches of 50 (Brevo's recommended batch size)
    brevo_categories.each_slice(50) do |batch|
      Rails.logger.info "Importing batch of #{batch.length} categories"
      
      begin
        result = brevo_client.create_categories_batch(batch)
        Rails.logger.info "Successfully imported batch of #{batch.length} categories"
      rescue => e
        Rails.logger.error "Failed to import category batch: #{e.message}"
        raise e
      end
    end
    
    Rails.logger.info "Total categories imported to Brevo: #{brevo_categories.length}"
    { success: true, total_imported: brevo_categories.length }
  end

  def fluid_client
    @fluid_client ||= FluidClient.new(@company.authentication_token)
  end

  def brevo_client
    @brevo_client ||= BrevoClient.new(@company.integration_setting.credentials.dig('brevo', 'api_key'))
  end
end
