# frozen_string_literal: true

class CustomerImportJob < ApplicationJob
  queue_as :default

  def perform(company_id, segment, list_id, job_id = nil)
    @company = Company.find(company_id)
    @segment = segment
    @list_id = list_id
    @job_id = job_id || SecureRandom.uuid
    
    Rails.logger.info "Starting customer import job #{@job_id} for company #{@company.id}, segment #{@segment}"
    
    begin
      # Initialize progress tracking
      update_progress(0, "Starting customer import...")
      
      # Get total customer count first
      total_customers = get_total_customer_count
      update_progress(10, "Found #{total_customers} customers to import")
      
      if total_customers == 0
        update_progress(100, "No customers found to import")
        return
      end
      
      # Process customers page by page - no memory accumulation
      page = 1
      per_page = 100
      total_imported = 0
      
      loop do
        progress_percentage = 10 + (total_imported * 80 / total_customers)
        update_progress(progress_percentage, "Processing customers... (#{total_imported}/#{total_customers})")
        
        # Fetch customers for this page
        fluid_customers = fetch_customers_page(page, per_page)
        customers = fluid_customers['customers'] || []
        
        # Break if no customers returned from API
        break if customers.empty?
        
        # Process this page immediately - no storing in memory
        page_imported = process_customer_page(customers, @list_id)
        total_imported += page_imported
        
        # Break if we've imported all customers for this segment
        break if total_imported >= total_customers
        
        page += 1
        
        # Small delay to avoid overwhelming the APIs
        sleep(0.3)
      end
      
      update_progress(100, "Successfully imported #{total_imported} customers")
      
    rescue => e
      Rails.logger.error "Customer import job #{@job_id} failed: #{e.message}"
      update_progress(-1, "Import failed: #{e.message}")
      raise
    end
  end

  private

  def update_progress(percentage, message)
    # Store progress in Redis or database
    Rails.cache.write("import_progress_#{@job_id}", {
      percentage: percentage,
      message: message,
      status: percentage == 100 ? 'completed' : (percentage == -1 ? 'failed' : 'running'),
      updated_at: Time.current
    }, expires_in: 1.hour)
    
    Rails.logger.info "Import progress #{@job_id}: #{percentage}% - #{message}"
  end

  def get_total_customer_count
    begin
      # For segment-specific counts, we need to fetch customers and filter them
      # since the API doesn't support is_rep parameter
      Rails.logger.info "Fetching customer count for segment: #{@segment_type}"
      
      # Fetch a reasonable number of customers to count
      params = { page: 1, per_page: 1000 } # Get up to 1000 customers to count
      response = fluid_client.get("/api/customers", params)
      
      # Debug the response
      Rails.logger.info "Count response class: #{response.class}"
      Rails.logger.info "Count response keys: #{response.keys if response.respond_to?(:keys)}"
      Rails.logger.info "Count response: #{response.inspect[0..500]}"
      
      # Get all customers and filter them
      all_customers = response.dig('customers') || []
      filtered_customers = filter_customers_by_segment(all_customers)
      
      total_count = filtered_customers.length
      Rails.logger.info "Total customers to import for segment #{@segment_type}: #{total_count} (filtered from #{all_customers.length} total)"
      total_count
    rescue => e
      Rails.logger.error "Failed to get customer count from stats: #{e.message}"
      Rails.logger.error "Error class: #{e.class}"
      
      # Log the actual response if it's available
      if e.respond_to?(:response) && e.response
        Rails.logger.error "Response code: #{e.response.code}"
        Rails.logger.error "Response body: #{e.response.body&.first(500)}"
        Rails.logger.error "Response headers: #{e.response.headers}"
      end
      
      # Fallback to first page method if stats endpoint fails
      begin
        Rails.logger.info "Trying fallback method..."
        
        # Fetch customers and filter them
        params = { page: 1, per_page: 1000 }
        response = fluid_client.get("/api/customers", params)
        
        all_customers = response.dig('customers') || []
        filtered_customers = filter_customers_by_segment(all_customers)
        
        total_count = filtered_customers.length
        Rails.logger.info "Fallback - Total customers to import for segment #{@segment_type}: #{total_count} (filtered from #{all_customers.length} total)"
        total_count
      rescue => e2
        Rails.logger.error "Fallback also failed: #{e2.message}"
        Rails.logger.error "Fallback error class: #{e2.class}"
        if e2.respond_to?(:response) && e2.response
          Rails.logger.error "Fallback response code: #{e2.response.code}"
          Rails.logger.error "Fallback response body: #{e2.response.body&.first(500)}"
        end
        0
      end
    end
  end

  def fetch_customers_page(page, per_page)
    begin
      Rails.logger.info "Fetching customers page #{page} with per_page=#{per_page} for segment: #{@segment_type}"
      
      # Fetch customers without API filtering (is_rep parameter doesn't exist)
      params = {
        page: page,
        per_page: per_page
      }
      
      response = fluid_client.get("/api/customers", params)
      
      # Debug the response
      Rails.logger.info "Page #{page} response class: #{response.class}"
      Rails.logger.info "Page #{page} response keys: #{response.keys if response.respond_to?(:keys)}"
      Rails.logger.info "Page #{page} customers count before filtering: #{response.dig('customers')&.length || 0}"
      
      # Filter customers based on segment type on our side
      customers = response.dig('customers') || []
      filtered_customers = filter_customers_by_segment(customers)
      
      Rails.logger.info "Page #{page} customers count after filtering: #{filtered_customers.length}"
      
      # Return response with filtered customers
      response.merge('customers' => filtered_customers)
    rescue => e
      Rails.logger.error "Failed to fetch customers page #{page}: #{e.message}"
      Rails.logger.error "Page #{page} error class: #{e.class}"
      
      if e.respond_to?(:response) && e.response
        Rails.logger.error "Page #{page} response code: #{e.response.code}"
        Rails.logger.error "Page #{page} response body: #{e.response.body&.first(500)}"
        Rails.logger.error "Page #{page} response headers: #{e.response.headers}"
      end
      
      raise
    end
  end

  def process_customer_page(customers, list_id)
    # Process customers in smaller batches for Brevo API
    batch_size = 50
    total_imported = 0
    
    customers.each_slice(batch_size) do |customer_batch|
      # Transform and import this batch immediately
      brevo_contacts = transform_customers_to_brevo_format(customer_batch)
      import_result = import_to_brevo(brevo_contacts, list_id)
      
      total_imported += customer_batch.length
      
      # Small delay between Brevo batches
      sleep(0.2)
    end
    
    total_imported
  end

  def filter_customers_by_segment(customers)
    case @segment_type
    when 'customer_list_id'
      # Non-rep customers only
      customers.select { |customer| customer['is_rep'] == false }
    when 'rep_list_id'
      # Rep customers only
      customers.select { |customer| customer['is_rep'] == true }
    when 'everyone_list_id'
      # All customers
      customers
    else
      # Default to all customers if segment type is unknown
      customers
    end
  end

  def transform_customers_to_brevo_format(customers)
    Rails.logger.info "Transforming #{customers.length} customers for Brevo"
    
    # Create CSV format as expected by Brevo
    csv_data = []
    
    # Add header row
    csv_data << "EMAIL,LASTNAME,FIRSTNAME,SMS,WHATSAPP"
    
    customers.each do |customer|
      # Log customer data for debugging
      Rails.logger.info "Customer data: email=#{customer['email']}, phone=#{customer['phone']}, first_name=#{customer['first_name']}, last_name=#{customer['last_name']}"
      
      # Validate email
      email = customer['email']
      if email.blank? || !email.include?('@')
        Rails.logger.warn "Invalid email for customer #{customer['id']}: #{email}"
        next # Skip this customer
      end
      
      # Format phone number for Brevo (must start with + or be numeric)
      phone = customer['phone']
      formatted_phone = if phone.present?
        # Remove any non-numeric characters except +
        cleaned = phone.gsub(/[^\d+]/, '')
        # If it doesn't start with +, add it
        cleaned.start_with?('+') ? cleaned : "+#{cleaned}"
      else
        ''
      end
      
      # Add customer row to CSV
      csv_data << [
        email,
        customer['last_name'] || '',
        customer['first_name'] || '',
        formatted_phone,
        formatted_phone
      ].join(',')
    end
    
    csv_string = csv_data.join("\n")
    Rails.logger.info "Generated CSV data: #{csv_string}"
    csv_string
  end

  def import_to_brevo(contacts_csv, list_id)
    Rails.logger.info "Importing contacts to Brevo list #{list_id}"
    Rails.logger.info "CSV data length: #{contacts_csv.length} characters"
    
    import_data = {
      listIds: [list_id.to_i].compact,
      notifyUrl: nil,
      newList: nil,
      emailBlacklist: false,
      smsBlacklist: false,
      updateExistingContacts: true,
      emptyContactsAttributes: false,
      fileBody: contacts_csv,
      fileUrl: nil
    }

    Rails.logger.info "Brevo import data: #{import_data.inspect}"
    brevo_client.import_contacts(import_data)
  end

  def fluid_client
    @fluid_client ||= FluidClient.new(@company.authentication_token)
  end

  def brevo_client
    @brevo_client ||= BrevoClient.new(@company.integration_setting.credentials.dig('brevo', 'api_key'))
  end
end
