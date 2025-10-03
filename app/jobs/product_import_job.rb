# frozen_string_literal: true

class ProductImportJob < ApplicationJob
  queue_as :default

  def perform(company_id, job_id = nil)
    @company = Company.find(company_id)
    @job_id = job_id || SecureRandom.uuid
    
    Rails.logger.info "Starting product import job #{@job_id} for company #{@company.id}"
    
    begin
      # Initialize progress tracking
      update_progress(0, "Starting product import...")
      
      # Get total product count first
      total_products = get_total_product_count
      update_progress(10, "Found #{total_products} products to import")
      
      if total_products == 0
        update_progress(100, "No products found to import")
        
        # Store final result for controller to access
        final_message = "No products found to import"
        final_result_data = {
          message: final_message,
          total_imported: 0
        }
        
        Rails.cache.write("import_result_#{@job_id}", final_result_data, expires_in: 1.hour)
        return
      end
      
      # Import products page by page
      page = 1
      per_page = 50
      total_imported = 0
      
      loop do
        update_progress(10 + (page * 80 / ((total_products / per_page) + 1)), "Importing products page #{page}...")
        
        # Fetch products for this page
        products_response = fluid_client.get("/api/company/v1/products", { page: page, per_page: per_page })
        products = products_response['products'] || []
        
        break if products.empty?
        
        # Transform products to Brevo format
        brevo_products = transform_products_to_brevo_format(products)
        
        # Import to Brevo
        import_result = import_to_brevo(brevo_products)
        
        total_imported += products.length
        update_progress(10 + (page * 80 / ((total_products / per_page) + 1)), "Imported #{total_imported}/#{total_products} products")
        
        page += 1
        
        # Small delay to avoid overwhelming the APIs
        sleep(0.3)
      end
      
      # Store final result for controller to access
      final_message = "Successfully imported #{total_imported} products"
      final_result_data = {
        message: final_message,
        total_imported: total_imported
      }
      
      Rails.cache.write("import_result_#{@job_id}", final_result_data, expires_in: 1.hour)
      
      # Update progress with final message
      update_progress(100, final_message)
      
    rescue => e
      Rails.logger.error "Product import job #{@job_id} failed: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      
      # Store final result for controller to access
      final_message = "Import failed: #{e.message}"
      final_result_data = {
        message: final_message,
        total_imported: 0
      }
      
      Rails.cache.write("import_result_#{@job_id}", final_result_data, expires_in: 1.hour)
      update_progress(-1, final_message)
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

  def get_total_product_count
    begin
      Rails.logger.info "Fetching product count for company #{@company.id}"
      
      # Fetch a reasonable number of products to count
      params = { page: 1, per_page: 1000 } # Get up to 1000 products to count
      Rails.logger.info "Making request to Fluid API with params: #{params}"
      
      response = fluid_client.get("/api/company/v1/products", params)
      Rails.logger.info "Fluid API response: #{response.inspect}"
      
      products = response['products'] || []
      total_count = products.length
      
      Rails.logger.info "Found #{total_count} products"
      total_count
    rescue => e
      Rails.logger.error "Error getting product count: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      0
    end
  end

  def transform_products_to_brevo_format(products)
    Rails.logger.info "Transforming #{products.length} products for Brevo"
    
    brevo_products = []
    
    products.each do |product|
      # Map Fluid product to Brevo product format
      brevo_product = {
        id: product['id'].to_s,
        name: product['title'] || 'Untitled Product',
        url: product['external_url'] || (product['slug'] ? "https://#{@company.fluid_shop}.fluid.app/products/#{product['slug']}" : nil),
        imageUrl: product['image_url'],
        sku: product['sku'] || product['id'].to_s,
        price: product['price']&.to_f,
        categories: product['category'] ? [product['category']['id'].to_s] : [],
        stock: product['in_stock'] ? (product['variants']&.first&.dig('inventory_quantity') || 0) : 0,
        metaInfo: product['metadata'] || {}
      }
      
      # Add parentId if it exists (for variants)
      if product['parent_id']
        brevo_product[:parentId] = product['parent_id'].to_s
      end
      
      # Remove nil values to keep the payload clean
      brevo_product = brevo_product.compact
      brevo_products << brevo_product
    end
    
    Rails.logger.info "Generated #{brevo_products.length} Brevo products"
    brevo_products
  end

  def import_to_brevo(brevo_products)
    Rails.logger.info "Importing #{brevo_products.length} products to Brevo"
    
    # Import in batches of 50 (Brevo's recommended batch size)
    batch_size = 50
    total_imported = 0
    
    brevo_products.each_slice(batch_size) do |batch|
      Rails.logger.info "Importing batch of #{batch.length} products"
      Rails.logger.info "Batch data: #{batch.inspect}"
      
      begin
        result = brevo_client.create_products_batch(batch)
        Rails.logger.info "Brevo API response: #{result.inspect}"
        total_imported += batch.length
        Rails.logger.info "Successfully imported batch of #{batch.length} products"
      rescue => e
        Rails.logger.error "Error importing batch: #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
        raise e
      end
    end
    
    Rails.logger.info "Total products imported to Brevo: #{total_imported}"
    { success: true, total_imported: total_imported }
  end

  def fluid_client
    @fluid_client ||= FluidClient.new(@company.authentication_token)
  end

  def brevo_client
    @brevo_client ||= BrevoClient.new(@company.integration_setting.credentials.dig('brevo', 'api_key'))
  end
end
