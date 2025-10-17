require 'set'

class OrderImportJob < ApplicationJob
  queue_as :default

  def perform(company_id, job_id = nil)
    @company = Company.find(company_id)
    @job_id = job_id || SecureRandom.uuid
    @auth_token = @company.authentication_token
    @brevo_api_key = @company.integration_setting.credentials.dig('brevo', 'api_key')

    Rails.logger.info "Starting order import job #{@job_id} for company #{@company.id}"

    # Initialize progress tracking
    update_progress(0, "Starting order import...")
    ActivityLog.log_info(@company, 'order_import', "Starting order import")

    # Initialize clients
    fluid_client = FluidClient.new(@auth_token)
    brevo_client = BrevoClient.new(@brevo_api_key)

    total_imported = 0
    page = 1
    per_page = 50
    total_orders = nil
    processed_orders = Set.new # Track order IDs to prevent duplicates

    update_progress(5, "Fetching orders from Fluid...")

    begin
      loop do
        Rails.logger.info "Fetching orders page #{page}..."
        
        # Fetch orders with error handling and rate limiting
        orders_response = fluid_client.get("/api/v202506/orders", { 
          query: { page: page, per_page: per_page } 
        })


        unless orders_response
          Rails.logger.error "Failed to fetch orders after retries, stopping import"
          break
        end

        orders = orders_response['orders'] || []

        Rails.logger.info "Received #{orders.length} orders from Fluid API"
        
        # Set total orders count from first response
        if total_orders.nil?
          total_orders = extract_total_count(orders_response, orders.length)
          Rails.logger.info "Total orders to process: #{total_orders}"
          update_progress(10, "Found #{total_orders} orders to import")
        end

        # Break if no orders returned
        break if orders.empty?

        # Filter out already processed orders
        new_orders = orders.reject { |order| processed_orders.include?(order['id']) }
        Rails.logger.info "New orders to process: #{new_orders.length}"

        # Process new orders if any exist
        if new_orders.any?
          progress_percentage = calculate_progress(total_imported, total_orders, 10, 85)
          update_progress(progress_percentage, "Processing page #{page} (#{new_orders.length} new orders)...")

          # Transform and import orders
          imported_count = process_orders_batch(new_orders, brevo_client, processed_orders)
          total_imported += imported_count
          
          progress_percentage = calculate_progress(total_imported, total_orders, 10, 85)
          update_progress(progress_percentage, "Imported #{total_imported}/#{total_orders} orders")
        end

        # Check if this is the last page
        if last_page?(orders_response, orders.length, per_page, page)
          Rails.logger.info "Reached last page (#{page})"
          break
        end

        page += 1
        
        # Safety check to prevent infinite loops
        if page > 1000 # Reasonable safety limit
          Rails.logger.warn "Reached page limit (1000), stopping import"
          break
        end
      end

    rescue => e
      Rails.logger.error "Error during order import: #{e.message}"
      raise e
    end

    update_progress(100, "Order import completed! Imported #{total_imported} orders")
    Rails.logger.info "Order import completed for company #{@company.id}. Total imported: #{total_imported}"
    
    # Log successful completion (no details to keep it simple)
    ActivityLog.log_success(@company, 'order_import', "Successfully imported #{total_imported} orders", {})
    
  rescue => e
    Rails.logger.error "Order import job #{@job_id} failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    update_progress(0, "Order import failed: #{e.message}")
    
    # Log error (no details to keep it simple)
    ActivityLog.log_error(@company, 'order_import', "Order import failed: #{e.message}", {})
    
    raise e
  end

  private

  def extract_total_count(orders_response, current_count)
    # Try to get from pagination metadata first
    if orders_response.dig('meta', 'pagination', 'total_count')
      return orders_response['meta']['pagination']['total_count']
    end
    
    # Fallback: estimate from current page
    if orders_response.dig('meta', 'pagination', 'total_pages')
      total_pages = orders_response['meta']['pagination']['total_pages']
      per_page = orders_response.dig('meta', 'pagination', 'per_page') || current_count
      return total_pages * per_page
    end
    
    # Last resort: use current count (will be inaccurate for multi-page)
    current_count
  end

  def last_page?(orders_response, orders_count, per_page, current_page)
    # Check pagination metadata first
    pagination = orders_response.dig('meta', 'pagination')
    if pagination
      total_pages = pagination['total_pages']
      return current_page >= total_pages if total_pages
      
      # Alternative: check if current page equals total pages
      reported_current = pagination['current_page']
      return reported_current >= total_pages if reported_current && total_pages
    end
    
    # Fallback: if we got fewer orders than per_page, it's likely the last page
    orders_count < per_page
  end

  def calculate_progress(current, total, min_percentage, max_percentage)
    return min_percentage if total.nil? || total == 0
    
    progress_range = max_percentage - min_percentage
    percentage = (current.to_f / total * progress_range) + min_percentage
    [percentage.round, max_percentage].min
  end

  def process_orders_batch(orders, brevo_client, processed_orders)
    # Transform orders to Brevo format
    brevo_orders = transform_orders_to_brevo_format(orders)
    
    if brevo_orders.empty?
      Rails.logger.info "No valid orders to import (missing contact identifiers)"
      return 0
    end

    # Import to Brevo
    import_to_brevo(brevo_orders, brevo_client)
    
    # Track processed order IDs
    brevo_orders.each { |order| processed_orders.add(order[:id]) }
    
    brevo_orders.length
  end

  def transform_orders_to_brevo_format(orders)
    orders.filter_map do |order|
      identifiers = build_identifiers(order)
      
      # Skip orders without any contact identifiers (Brevo requirement)
      next if identifiers.empty?
      
      {
        id: order['id'].to_s,
        createdAt: order['created_at'],
        updatedAt: order['updated_at'],
        status: map_order_status(order['status']),
        amount: order['amount'].to_f,
        storeId: "FLUID-#{@company.fluid_company_id}",
        identifiers: identifiers,
        products: transform_order_products(order['items'] || []),
        billing: build_billing_info(order),
        metaInfo: build_meta_info(order)
      }
    end
  end

  def map_order_status(fluid_status)
    case fluid_status
    when 'awaiting_payment'
      'pending'
    when 'awaiting_shipment'
      'confirmed'
    when 'shipped'
      'shipped'
    when 'delivered'
      'delivered'
    when 'cancelled'
      'cancelled'
    when 'failed_payment'
      'failed'
    else
      'pending'
    end
  end

  def transform_order_products(items)
    items.map do |item|
      # Try to get product ID from variant.product.id, fallback to item.id if not available
      product_id = item.dig('variant', 'product', 'id') || item['id']
      
      product_data = {
        productId: product_id.to_s,
        quantity: item['quantity'].to_i,
        price: item['price'].to_f
      }
      
      # Add variant ID if available
      if item.dig('variant', 'id')
        product_data[:variantId] = item.dig('variant', 'id').to_s
      end
      
      product_data
    end
  end

  def build_identifiers(order)
    identifiers = {}
    
    # Add email identifier if available
    email = order['email'] || order.dig('customer', 'email')
    identifiers[:email_id] = email if email.present?
    
    # Add phone identifier if available
    phone = order.dig('customer', 'phone') || order.dig('bill_to', 'phone')
    identifiers[:phone_id] = phone if phone.present?
    
    # Add external ID if available
    external_id = order.dig('customer', 'external_id')
    identifiers[:ext_id] = external_id if external_id.present?
    
    identifiers.present? ? identifiers : {}
  end

  def build_billing_info(order)
    billing = order['bill_to'] || {}
    customer = order['customer'] || {}
    
    billing_info = {
      address: build_address(billing),
      city: billing['city'],
      countryCode: billing['country_code'],
      country: get_country_name(billing['country_code']),
      phone: billing['phone'] || customer['phone'],
      postCode: billing['postal_code'],
      region: billing['state'],
      paymentMethod: determine_payment_method(order)
    }.compact
    
    billing_info.present? ? billing_info : {}
  end

  def build_address(billing)
    address_parts = [
      billing['address1'],
      billing['address2'],
      billing['address3']
    ].compact
    
    address_parts.join(', ')
  end

  def get_country_name(country_code)
    return nil unless country_code.present?
    
    country_mapping = {
      'US' => 'United States',
      'CA' => 'Canada',
      'GB' => 'United Kingdom',
      'AU' => 'Australia',
      'DE' => 'Germany',
      'FR' => 'France',
      'ES' => 'Spain',
      'IT' => 'Italy',
      'NL' => 'Netherlands',
      'BE' => 'Belgium',
      'CH' => 'Switzerland',
      'AT' => 'Austria',
      'SE' => 'Sweden',
      'NO' => 'Norway',
      'DK' => 'Denmark',
      'FI' => 'Finland',
      'PL' => 'Poland',
      'CZ' => 'Czech Republic',
      'HU' => 'Hungary',
      'RO' => 'Romania',
      'BG' => 'Bulgaria',
      'HR' => 'Croatia',
      'SI' => 'Slovenia',
      'SK' => 'Slovakia',
      'LT' => 'Lithuania',
      'LV' => 'Latvia',
      'EE' => 'Estonia',
      'IE' => 'Ireland',
      'PT' => 'Portugal',
      'GR' => 'Greece',
      'CY' => 'Cyprus',
      'MT' => 'Malta',
      'LU' => 'Luxembourg'
    }
    
    country_mapping[country_code.upcase] || country_code
  end

  def determine_payment_method(order)
    if order['payment_method'].present?
      order['payment_method']
    elsif order['financial_status'].present?
      case order['financial_status'].downcase
      when 'paid', 'completed'
        'Credit Card'
      when 'pending'
        'Pending'
      when 'failed'
        'Failed'
      end
    end
  end

  def build_meta_info(order)
    {
      order_source: 'Fluid',
      order_number: order['order_number'],
      customer_id: order.dig('customer', 'id')&.to_s
    }.compact
  end

  def import_to_brevo(orders, brevo_client)
    Rails.logger.info "Importing #{orders.length} orders to Brevo"
    
    orders.each_slice(200) do |batch|
      Rails.logger.info "Importing batch of #{batch.length} orders"
      
      begin
        brevo_client.create_orders_batch(batch)
      rescue => e
        Rails.logger.error "Failed to import batch to Brevo: #{e.message}"
        # Re-raise to let the main error handler deal with it
        raise e
      end
      
      # Respect Brevo's 10 RPS rate limit (0.12s = ~8.3 RPS with safety margin)
      sleep(0.12)
    end
  end

  def update_progress(percentage, message)
    progress_data = {
      status: percentage == 100 ? 'completed' : 'in_progress',
      percentage: percentage,
      message: message,
      timestamp: Time.current.iso8601
    }
    
    Rails.cache.write("import_progress_#{@job_id}", progress_data, expires_in: 1.hour)
    Rails.logger.info "Order import progress #{@job_id}: #{percentage}% - #{message}"
  end
end
