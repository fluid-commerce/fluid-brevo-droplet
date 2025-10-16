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
        
        # Check if we've reached the last page using pagination metadata
        pagination = fluid_customers.dig('meta', 'pagination')
        is_last_page = false
        
        if pagination
          current_page = pagination['current_page']
          total_pages = pagination['total_pages']
          Rails.logger.info "Page #{current_page} of #{total_pages} (pagination metadata)"
          is_last_page = current_page >= total_pages
        elsif customers.length < per_page
          Rails.logger.info "Reached last page (#{customers.length} < #{per_page} customers), this is the final page"
          is_last_page = true
        end
        
        # Process this page immediately - no storing in memory
        page_imported = process_customer_page(customers, @list_id)
        total_imported += page_imported
        
        # Break if we've reached the last page or imported all customers
        break if is_last_page || total_imported >= total_customers
        
        page += 1
      end
      
      # Store final result for controller to access
      final_message = "Successfully imported #{total_imported} customers"
      final_result_data = {
        message: final_message,
        total_imported: total_imported
      }
      
      Rails.cache.write("import_result_#{@job_id}", final_result_data, expires_in: 1.hour)
      
      # Update progress with final message
      update_progress(100, final_message)
      
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
      Rails.logger.info "Fetching customer count for segment: #{@segment}"
      
      # Fetch a reasonable number of customers to count
      params = { query: { page: 1, per_page: 1000 } } # Get up to 1000 customers to count
      response = fluid_client.get("/api/customers", params)
      
      # Get all customers and filter them
      all_customers = response.dig('customers') || []
      filtered_customers = filter_customers_by_segment(all_customers)
      
      total_count = filtered_customers.length
      Rails.logger.info "Total customers to import for segment #{@segment}: #{total_count} (filtered from #{all_customers.length} total)"
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
        params = { query: { page: 1, per_page: 1000 } }
        response = fluid_client.get("/api/customers", params)
        
        all_customers = response.dig('customers') || []
        filtered_customers = filter_customers_by_segment(all_customers)
        
        total_count = filtered_customers.length
        Rails.logger.info "Fallback - Total customers to import for segment #{@segment}: #{total_count} (filtered from #{all_customers.length} total)"
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
      Rails.logger.info "Fetching customers page #{page} with per_page=#{per_page} for segment: #{@segment}"
      
      # Fetch customers without API filtering (is_rep parameter doesn't exist)
      params = {
        query: {
          page: page,
          per_page: per_page
        }
      }
      
      response = fluid_client.get("/api/customers", params)
      
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
      contact_data = transform_customers_to_brevo_format(customer_batch)
      import_result = import_to_brevo(contact_data, list_id)
      
      total_imported += customer_batch.length
      
      # Respect Brevo's 10 RPS rate limit (0.12s = ~8.3 RPS with safety margin)
      sleep(0.12)
    end
    
    total_imported
  end

  def filter_customers_by_segment(customers)
    case @segment
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
    
    # Create contact data for JSON generation
    contact_data = []
    
    # Separate reps and non-reps for different processing
    rep_customers = customers.select { |customer| customer['is_rep'] == true }
    non_rep_customers = customers.select { |customer| customer['is_rep'] == false }
    
    Rails.logger.info "Found #{rep_customers.length} reps and #{non_rep_customers.length} non-reps"
    
    # Process non-rep customers first (simpler, no additional API calls needed)
    non_rep_customers.each do |customer|
      contact = build_customer_contact(customer, nil)
      contact_data << contact if contact
    end
    
    # Process rep customers with additional MLM data
    if rep_customers.any?
      Rails.logger.info "Fetching MLM data for #{rep_customers.length} reps..."
      
      begin
        rep_data = fetch_rep_data_for_customers(rep_customers)

        rep_customers.each do |customer|
          rep_info = rep_data[customer['email']] || {}
          contact = build_customer_contact(customer, rep_info)
          contact_data << contact if contact
        end
        
        successful_reps = rep_data.values.count { |data| data.any? }
        Rails.logger.info "Successfully processed #{successful_reps}/#{rep_customers.length} reps with MLM data"
        
      rescue => e
        Rails.logger.error "Error fetching rep data, falling back to basic rep import: #{e.message}"
        
        # Fallback: import reps without MLM data
        rep_customers.each do |customer|
          contact = build_customer_contact(customer, {})
          contact_data << contact if contact
        end
      end
    end
    
    Rails.logger.info "Generated contact data: #{contact_data.length} contacts"
    Rails.logger.info "Sample contact: #{contact_data.first.inspect}" if contact_data.any?
    contact_data
  end

  def import_to_brevo(contact_data, list_id)
    Rails.logger.info "Importing contacts to Brevo list #{list_id}"
    Rails.logger.info "Contact data count: #{contact_data.length}"
    
    # Generate JSON body for Brevo as recommended by support
    json_body = generate_json_from_contacts(contact_data)
    
    import_data = {
      listIds: [list_id.to_i].compact,
      updateExistingContacts: true,
      jsonBody: json_body
    }

    Rails.logger.info "Brevo import data with JSON: #{import_data.inspect[0..500]}"
    Rails.logger.info "Request body being sent to Brevo:"
    Rails.logger.info "listIds: #{import_data[:listIds]}"
    Rails.logger.info "jsonBody count: #{json_body.length} contacts"
    Rails.logger.info "Sample contact: #{json_body.first.inspect}" if json_body.any?
    
    brevo_client.import_contacts(import_data)
  end

  private

  def build_customer_contact(customer, rep_info = nil)
    # Log customer data for debugging (only for reps with MLM data)
    if customer['is_rep']
      Rails.logger.info "Processing rep: #{customer['email']}"
    end
    
    # Validate email
    email = customer['email']
    if email.blank? || !email.include?('@')
      Rails.logger.warn "Invalid email for customer #{customer['id']}: #{email}"
      return nil # Skip this customer
    end
    
    # Format phone number for Brevo JSON format
    phone = customer['phone']
    formatted_phone = if phone.present?
      # Remove any non-numeric characters except +
      cleaned = phone.gsub(/[^\d+]/, '')
      # If it doesn't start with +, add it
      cleaned = cleaned.start_with?('+') ? cleaned : "+#{cleaned}"
      # Ensure minimum 8 characters as required by Brevo
      cleaned.length >= 8 ? cleaned : ''
    else
      ''
    end

    # Only log phone formatting issues
    if phone.present? && formatted_phone.blank?
      Rails.logger.warn "Phone formatting failed: original='#{phone}', formatted='#{formatted_phone}'"
    end

    # Build base contact data
    contact = {
      email: email,
      firstname: customer['first_name'] || '',
      lastname: customer['last_name'] || '',
      sms: formatted_phone,
      # Add customer_type attribute
      customer_type: customer['is_rep'] ? 'rep' : 'no_rep'
    }

    # Add MLM-specific attributes for reps
    if customer['is_rep'] && rep_info
      contact[:shareguid] = rep_info[:share_guid] if rep_info[:share_guid]
      contact[:sponsor_name] = rep_info[:sponsor_name] if rep_info[:sponsor_name]
      contact[:sponsor_id] = rep_info[:sponsor_id] if rep_info[:sponsor_id]
      contact[:rank] = rep_info[:rank] if rep_info[:rank]

      # Only log if we have MLM data
      if contact[:shareguid] || contact[:sponsor_name] || contact[:sponsor_id]
        Rails.logger.info "Rep with MLM data: #{contact[:shareguid]}, #{contact[:sponsor_name]}, #{contact[:sponsor_id]}"
      end
    end

    contact
  end

  def fetch_rep_data_for_customers(rep_customers)
    Rails.logger.info "Fetching rep data for #{rep_customers.length}"

    rep_data = {}
    rep_emails = rep_customers.map { |customer| customer['email'] }.compact.uniq

    begin
      # We need both endpoints: /api/v2/reps for rep IDs and /api/v202506/users for rank data
      # First, get all reps to get rep IDs and basic info
      all_reps = []
      page = 1
      per_page = 100  # API limit: must be <= 100

      loop do
        # Try different parameter combinations to see which works
        reps_params = {
          query: {
            page: page,
            per_page: per_page
          }
        }

        Rails.logger.info "Fetching reps page #{page}"
        Rails.logger.info "Trying params: #{reps_params}"
        
        Rails.logger.info "About to call fluid_client.get with params: #{reps_params}"
        
        reps_response = fluid_client.get("/api/v2/reps", reps_params)
        
        Rails.logger.info "Response received: #{reps_response.inspect}"
        page_reps = reps_response.dig('reps') || []

        all_reps.concat(page_reps)

        # Check if we've reached the last page
        pagination = reps_response.dig('meta', 'pagination')
        if pagination
          current_page = pagination['current_page']
          total_pages = pagination['total_pages']
          Rails.logger.info "Reps page #{current_page} of #{total_pages}"
          break if current_page >= total_pages
        elsif page_reps.length < per_page
          Rails.logger.info "Reached last page (#{page_reps.length} < #{per_page} reps)"
          break
        end

        page += 1
      end

      Rails.logger.info "Retrieved #{all_reps.length} total reps"

      # Get rank data for specific rep emails using search_query
      Rails.logger.info "Fetching rank data for #{rep_emails.length} specific reps..."
      ranks_by_email = {}
      
      rep_emails.each do |email|
        begin
          # Search for specific user by email using search_query
          users_params = {
            query: {
              role: 'rep',
              search_query: email,
              per_page: 1  # We only need 1 result since we're searching by exact email
            }
          }
          
          users_response = fluid_client.get("/api/v202506/users", users_params)
          users = users_response.dig('user_companies') || []
          
          # Find the user with matching email
          matching_user = users.find { |user| user.dig('user', 'email') == email }
          
          if matching_user
            ranks_by_email[email] = matching_user['rank']
            Rails.logger.info "Found rank for #{email}: #{matching_user['rank']}"
          else
            Rails.logger.warn "No user found for email: #{email}"
            ranks_by_email[email] = nil
          end
          
        rescue => e
          Rails.logger.error "Error fetching rank for #{email}: #{e.message}"
          ranks_by_email[email] = nil
        end
      end
      
      Rails.logger.info "Retrieved rank data for #{ranks_by_email.values.compact.length}/#{rep_emails.length} reps"
      
      # Create a lookup hash by email for fast matching
      reps_by_email = {}
      all_reps.each do |rep|
        email = rep['computed_email']
        if email.present?
          reps_by_email[email] = rep
        end
      end
      
      # Match our rep customers with the fetched data
      rep_emails.each do |email|
        if reps_by_email[email]
          rep_info = reps_by_email[email]
          
          # For sponsor information, we need to fetch individual rep details
          # The users endpoint doesn't include enroller/sponsor data
          sponsor_name = nil
          sponsor_id = nil
          
          # Get detailed rep info to access enroller data
          rep_detail = fetch_rep_detail(rep_info['id'])
          
          if rep_detail && rep_detail.dig('enroller')
            enroller = rep_detail['enroller']
            if enroller['first_name'] && enroller['last_name']
              sponsor_name = "#{enroller['first_name']} #{enroller['last_name']}".strip
            end
            sponsor_id = enroller['external_id']
          end

          rep_data[email] = {
            share_guid: rep_info['share_guid'],
            sponsor_name: sponsor_name,
            sponsor_id: sponsor_id,
            rank: ranks_by_email[email] # Available from /api/v202506/users
          }
          
        else
          rep_data[email] = {}
        end
      end
      
      successful_fetches = rep_data.values.count { |data| data.any? }
      Rails.logger.info "Successfully processed #{successful_fetches}/#{rep_emails.length} reps with MLM data"
      
    rescue => e
      Rails.logger.error "Error fetching rep data using users endpoint: #{e.message}"
      Rails.logger.error "Error details: #{e.class} - #{e.backtrace&.first(3)&.join(', ')}"
      
      # Fallback: return empty data for all reps
      rep_emails.each { |email| rep_data[email] = {} }
    end

    rep_data
  end

  def fetch_rep_detail(rep_id)
    begin
      # Fetch detailed rep info to get enroller/sponsor data
      rep_response = fluid_client.get_with_timeout("/api/v2/reps/#{rep_id}", {}, 30)

      if rep_response && rep_response['rep']
        rep_response['rep']
      else
        Rails.logger.warn "Empty or invalid response for rep #{rep_id}"
        nil
      end
      
    rescue Net::ReadTimeout, Net::OpenTimeout => e
      Rails.logger.error "Timeout fetching rep detail for #{rep_id}: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "Error fetching rep detail for #{rep_id}: #{e.message}"
      nil
    end
  end

  def generate_json_from_contacts(contact_data)
    # Generate JSON body following Brevo's exact format as provided by support
    contact_data.compact.map do |contact|
      # Build base attributes
      attributes = {
        FIRSTNAME: contact[:firstname] || '',
        LASTNAME: contact[:lastname] || '',
        SMS: contact[:sms] || '',
        WHATSAPP: contact[:sms] || '',
        CUSTOMER_TYPE: contact[:customer_type] || 'no_rep'
      }
      
      # Add MLM-specific attributes for reps
      if contact[:customer_type] == 'rep'
        attributes[:SHAREGUID] = contact[:shareguid] if contact[:shareguid]
        attributes[:SPONSOR_NAME] = contact[:sponsor_name] if contact[:sponsor_name]
        attributes[:SPONSOR_ID] = contact[:sponsor_id] if contact[:sponsor_id]
        attributes[:RANK] = contact[:rank] if contact[:rank]
      end
      
      {
        email: contact[:email],
        attributes: attributes
      }
    end
  end

  def fluid_client
    @fluid_client ||= FluidClient.new(@company.authentication_token)
  end

  def brevo_client
    @brevo_client ||= BrevoClient.new(@company.integration_setting.credentials.dig('brevo', 'api_key'))
  end
end
