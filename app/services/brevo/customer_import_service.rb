# frozen_string_literal: true

class Brevo::CustomerImportService
  def initialize(company)
    @company = company
    @fluid_client = FluidClient.new(@company.fluid_api_token)
    @brevo_client = BrevoClient.new(@company.integration_setting.credentials.dig('brevo', 'api_key'))
  end

  def import_customers(limit: 50, offset: 0)
    begin
      Rails.logger.info "Starting customer import for company #{@company.id}"
      
      # Fetch customers from Fluid
      fluid_customers = fetch_fluid_customers(limit: limit, offset: offset)
      Rails.logger.info "Fetched #{fluid_customers['customers']&.length || 0} customers from Fluid"
      
      # Transform customers to Brevo format
      brevo_contacts = transform_customers_to_brevo_format(fluid_customers['customers'] || [])
      Rails.logger.info "Transformed #{brevo_contacts.length} customers to Brevo format"
      
      # Import to Brevo
      if brevo_contacts.any?
        import_result = import_to_brevo(brevo_contacts)
        Rails.logger.info "Import result: #{import_result}"
        
        {
          success: true,
          imported_count: brevo_contacts.length,
          total_fluid_customers: fluid_customers['customers']&.length || 0,
          import_result: import_result
        }
      else
        {
          success: true,
          imported_count: 0,
          total_fluid_customers: 0,
          message: "No customers to import"
        }
      end
    rescue FluidClient::Error => e
      Rails.logger.error "Fluid API Error: #{e.message}"
      {
        success: false,
        error: "Failed to fetch customers from Fluid: #{e.message}"
      }
    rescue BrevoApiError => e
      Rails.logger.error "Brevo API Error: #{e.message}"
      {
        success: false,
        error: "Failed to import customers to Brevo: #{e.message}"
      }
    rescue => e
      Rails.logger.error "Unexpected error: #{e.message}"
      {
        success: false,
        error: "An unexpected error occurred: #{e.message}"
      }
    end
  end

  def preview_customers(limit: 10, offset: 0)
    begin
      fluid_customers = fetch_fluid_customers(limit: limit, offset: offset)
      customers = fluid_customers['customers'] || []
      
      # Return a simplified version for preview
      customers.map do |customer|
        {
          id: customer['id'],
          name: customer['full_name'] || "#{customer['first_name']} #{customer['last_name']}".strip,
          email: customer['email'],
          phone: customer['phone'],
          created_at: customer['created_at']
        }
      end
    rescue FluidClient::Error => e
      Rails.logger.error "Fluid API Error during preview: #{e.message}"
      []
    rescue => e
      Rails.logger.error "Unexpected error during preview: #{e.message}"
      []
    end
  end

  def preview_customers_for_segment(segment, limit: 10, offset: 0)
    begin
      fluid_customers = fetch_fluid_customers_for_segment(segment, limit: limit, offset: offset)
      customers = fluid_customers['customers'] || []
      
      # Return a simplified version for preview
      customers.map do |customer|
        {
          id: customer['id'],
          name: customer['full_name'] || "#{customer['first_name']} #{customer['last_name']}".strip,
          email: customer['email'],
          phone: customer['phone'],
          created_at: customer['created_at']
        }
      end
    rescue FluidClient::Error => e
      Rails.logger.error "Fluid API Error during segment preview: #{e.message}"
      []
    rescue => e
      Rails.logger.error "Unexpected error during segment preview: #{e.message}"
      []
    end
  end

  def import_customers_for_segment(segment, limit: 50, offset: 0)
    begin
      Rails.logger.info "Starting customer import for segment #{segment} in company #{@company.id}"
      
      # Get the list ID for this segment
      list_id = @company.integration_setting.send(segment)
      unless list_id.present?
        return {
          success: false,
          error: "No list configured for #{segment.humanize}. Please select a list first."
        }
      end
      
      # Fetch customers from Fluid for this segment
      fluid_customers = fetch_fluid_customers_for_segment(segment, limit: limit, offset: offset)
      Rails.logger.info "Fetched #{fluid_customers['customers']&.length || 0} customers from Fluid for segment #{segment}"
      
      # Transform customers to Brevo format
      brevo_contacts = transform_customers_to_brevo_format(fluid_customers['customers'] || [])
      Rails.logger.info "Transformed #{brevo_contacts.length} customers to Brevo format"
      
      # Import to Brevo
      if brevo_contacts.any?
        import_result = import_to_brevo_for_segment(brevo_contacts, list_id)
        Rails.logger.info "Import result: #{import_result}"
        
        {
          success: true,
          imported_count: brevo_contacts.length,
          total_fluid_customers: fluid_customers['customers']&.length || 0,
          import_result: import_result
        }
      else
        {
          success: true,
          imported_count: 0,
          total_fluid_customers: 0,
          message: "No customers to import for #{segment.humanize}"
        }
      end
    rescue FluidClient::Error => e
      Rails.logger.error "Fluid API Error: #{e.message}"
      {
        success: false,
        error: "Failed to fetch customers from Fluid: #{e.message}"
      }
    rescue BrevoApiError => e
      Rails.logger.error "Brevo API Error: #{e.message}"
      {
        success: false,
        error: "Failed to import customers to Brevo: #{e.message}"
      }
    rescue => e
      Rails.logger.error "Unexpected error: #{e.message}"
      {
        success: false,
        error: "An unexpected error occurred: #{e.message}"
      }
    end
  end

  private

  def fetch_fluid_customers(limit:, offset:)
    @fluid_client.get("/api/company/v1/customers", {
      limit: limit,
      offset: offset
    })
  end

  def fetch_fluid_customers_for_segment(segment, limit:, offset:)
    # For now, we'll fetch all customers and filter them based on the segment
    # In the future, this could be enhanced to use specific Fluid API filters
    case segment
    when 'everyone_list_id'
      # All customers
      @fluid_client.get("/api/company/v1/customers", {
        limit: limit,
        offset: offset
      })
    when 'customer_list_id'
      # Non-rep customers (customers without rep role)
      @fluid_client.get("/api/company/v1/customers", {
        limit: limit,
        offset: offset,
        # Add filters for non-rep customers when Fluid API supports it
        # For now, we'll fetch all and filter in Ruby
      })
    when 'rep_list_id'
      # Rep customers only
      @fluid_client.get("/api/company/v1/customers", {
        limit: limit,
        offset: offset,
        # Add filters for rep customers when Fluid API supports it
        # For now, we'll fetch all and filter in Ruby
      })
    else
      # Default to all customers
      @fluid_client.get("/api/company/v1/customers", {
        limit: limit,
        offset: offset
      })
    end
  end

  def transform_customers_to_brevo_format(customers)
    customers.map do |customer|
      {
        email: customer['email'],
        attributes: {
          FIRSTNAME: customer['first_name'] || '',
          LASTNAME: customer['last_name'] || '',
          SMS: customer['phone'] || '',
          # Add custom attributes for Fluid-specific data
          'FLUID_ID': customer['id'].to_s,
          'FLUID_ACCOUNT_ID': customer['account_id'] || '',
          'TOTAL_SPENT': customer['total_spent'] || '0',
          'ORDERS_COUNT': customer['orders_count'] || 0,
          'VERIFIED_EMAIL': customer['verified_email'] || false
        },
        listIds: [@company.integration_setting.default_list_id].compact,
        updateEnabled: true
      }
    end
  end

  def import_to_brevo(contacts)
    # Brevo import API expects a specific format
    import_data = {
      listIds: [@company.integration_setting.default_list_id].compact,
      notifyUrl: nil,
      newList: {
        listName: "Fluid Import #{Time.current.strftime('%Y-%m-%d %H:%M')}",
        folderId: 1
      },
      emailBlacklist: false,
      smsBlacklist: false,
      updateExistingContacts: true,
      emptyContactsAttributes: false,
      fileBody: contacts.to_json,
      fileUrl: nil
    }

    @brevo_client.import_contacts(import_data)
  end

  def import_to_brevo_for_segment(contacts, list_id)
    # Brevo import API expects a specific format
    import_data = {
      listIds: [list_id].compact,
      notifyUrl: nil,
      newList: nil, # Don't create a new list, use the existing one
      emailBlacklist: false,
      smsBlacklist: false,
      updateExistingContacts: true,
      emptyContactsAttributes: false,
      fileBody: contacts.to_json,
      fileUrl: nil
    }

    @brevo_client.import_contacts(import_data)
  end
end
