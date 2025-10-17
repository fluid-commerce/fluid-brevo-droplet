# frozen_string_literal: true

class BrevoAttributeCreationJob < ApplicationJob
  queue_as :default

  # Define the attributes to create
  ATTRIBUTES_TO_CREATE = [
    {
      name: 'customer_type',
      category: 'category',
      type: 'category',
      enumeration: [
        { value: 1, label: 'rep' },
        { value: 2, label: 'no_rep' }
      ]
    },
    {
      name: 'shareguid',
      category: 'normal',
      type: 'text'
    },
    {
      name: 'rank',
      category: 'normal',
      type: 'text'
    },
    {
      name: 'sponsor_name',
      category: 'normal',
      type: 'text'
    },
    {
      name: 'sponsor_id',
      category: 'normal',
      type: 'text'
    }
  ].freeze

  def perform(company_id)
    @company = Company.find(company_id)
    @api_key = @company.integration_setting.credentials.dig('brevo', 'api_key')
    
    Rails.logger.info "Starting Brevo attribute creation for company #{company_id}"
    Rails.logger.info "Attributes to create: #{ATTRIBUTES_TO_CREATE.map { |attr| attr[:name] }.join(', ')}"
    
    ActivityLog.log_info(@company, 'attribute_creation', "Starting Brevo attribute creation")
    
    begin
      brevo_client = BrevoClient.new(@api_key)
      
      # Check existing attributes first
      existing_attributes = brevo_client.get_attributes
      Rails.logger.info "Found #{existing_attributes['attributes']&.length || 0} existing attributes"
      
      results = []
      created_count = 0
      skipped_count = 0

      ATTRIBUTES_TO_CREATE.each do |attribute_config|
        result = create_single_attribute(brevo_client, existing_attributes, attribute_config)
        results << result
        
        if result[:created]
          created_count += 1
        else
          skipped_count += 1
        end
      end
      
      Rails.logger.info "Attribute creation completed: #{created_count} created, #{skipped_count} skipped"
      
      # Log successful completion (no details to keep it simple)
      ActivityLog.log_success(@company, 'attribute_creation', "Successfully created #{created_count} attributes, #{skipped_count} already existed", {})
      
      {
        success: true,
        message: "Attribute creation completed: #{created_count} created, #{skipped_count} skipped",
        created_count: created_count,
        skipped_count: skipped_count,
        results: results
      }
      
    rescue BrevoApiError => e
      Rails.logger.error "Brevo API error creating attributes: #{e.message} (Status: #{e.status_code})"
      
      # Log error (no details to keep it simple)
      ActivityLog.log_error(@company, 'attribute_creation', "Brevo API error creating attributes: #{e.message}", {})
      
      { success: false, error: "Brevo API error: #{e.message}", status_code: e.status_code }
    rescue => e
      Rails.logger.error "Unexpected error creating Brevo attributes: #{e.class.name}: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
      
      # Log error (no details to keep it simple)
      ActivityLog.log_error(@company, 'attribute_creation', "Unexpected error creating attributes: #{e.message}", {})
      
      { success: false, error: "Unexpected error: #{e.message}" }
    end
  end

  private

  def create_single_attribute(brevo_client, existing_attributes, attribute_config)
    attribute_name = attribute_config[:name]
    attribute_category = attribute_config[:category]
    
    # Check if attribute already exists (case-insensitive comparison)
    attribute_exists = existing_attributes['attributes']&.any? do |attr|
      attr['name'].downcase == attribute_name.downcase && attr['category'] == attribute_category
    end
    
    Rails.logger.info "Checking for #{attribute_name} (#{attribute_category}): #{attribute_exists ? 'EXISTS' : 'NOT FOUND'}"
    
    if attribute_exists
      Rails.logger.info "#{attribute_name} attribute already exists, skipping creation"
      return {
        attribute: attribute_name,
        created: false,
        message: "#{attribute_name} attribute already exists"
      }
    end
    
    # Prepare attribute parameters
    attribute_params = {
      type: attribute_config[:type]
    }
    
    # Add enumeration if present
    if attribute_config[:enumeration]
      attribute_params[:enumeration] = attribute_config[:enumeration]
    end
    
    Rails.logger.info "Creating #{attribute_name} attribute with params: #{attribute_params.inspect}"
    Rails.logger.info "Endpoint: /contacts/attributes/#{attribute_category}/#{attribute_name}"
    
    begin
      # Use the correct endpoint format: /contacts/attributes/{attributeCategory}/{attributeName}
      
      result = brevo_client.create_attribute_with_category(attribute_category, attribute_name, attribute_params)
      
      Rails.logger.info "#{attribute_name} attribute creation result: #{result.inspect}"
      
      {
        attribute: attribute_name,
        created: true,
        message: "#{attribute_name} attribute created successfully",
        result: result
      }
      
    rescue BrevoApiError => e
      Rails.logger.error "Failed to create #{attribute_name} attribute: #{e.message} (Status: #{e.status_code})"
      {
        attribute: attribute_name,
        created: false,
        error: "Brevo API error: #{e.message}",
        status_code: e.status_code
      }
    rescue => e
      Rails.logger.error "Unexpected error creating #{attribute_name} attribute: #{e.message}"
      {
        attribute: attribute_name,
        created: false,
        error: "Unexpected error: #{e.message}"
      }
    end
  end
end
