# frozen_string_literal: true

require 'set'

class ProductImportJob < ApplicationJob
  queue_as :default

  def perform(company_id, job_id = nil)
    @company = Company.find(company_id)
    @job_id = job_id || SecureRandom.uuid
    
    Rails.logger.info "Starting product import job #{@job_id} for company #{@company.id}"
    
    begin
      # Initialize progress tracking
      update_progress(0, "Starting product import...")
      
      # Import products page by page
      page = 1
      per_page = 50
      total_imported = 0
      total_products = nil
      imported_product_ids = Set.new
      
      loop do
        # Fetch products for this page
        products_response = fluid_client.get("/api/company/v1/products", { page: page, per_page: per_page })
        products = products_response['products'] || []
        
        # Get total count from first page if not already set
        if total_products.nil?
          # Use pagination metadata as initial estimate, but we'll adjust based on actual products found
          if products_response['meta'] && products_response['meta']['pagination']
            total_products = products_response['meta']['pagination']['total_count'] || 0
          else
            total_products = products.length
          end
          update_progress(10, "Found #{total_products} products to import (estimated)")
        end
        
        break if products.empty?
        
        # If we got fewer products than per_page, this is the last page
        if products.length < per_page
          Rails.logger.info "Reached last page (#{products.length} < #{per_page} products), stopping after this page"
          # Adjust total_products to reflect actual count found
          total_products = total_imported + products.length
          Rails.logger.info "Adjusted total products to actual count: #{total_products}"
        end
        
        # Filter out already imported products to avoid duplicates
        new_products = products.reject { |product| imported_product_ids.include?(product['id']) }
        
        if new_products.empty?
          Rails.logger.info "No new products on page #{page}, stopping import"
          break
        end
        
        progress_percentage = 10 + (total_imported * 80 / total_products)
        update_progress(progress_percentage, "Importing products page #{page}...")
        
        # Transform products to Brevo format
        brevo_products = transform_products_to_brevo_format(new_products)
        
        # Import to Brevo
        import_result = import_to_brevo(brevo_products)
        
        # Track imported product IDs
        new_products.each { |product| imported_product_ids.add(product['id']) }
        total_imported += new_products.length
        
        update_progress(10 + (total_imported * 80 / total_products), "Imported #{total_imported}/#{total_products} products")
        
        # Break if we've imported all products or if this was the last page
        break if total_imported >= total_products || products.length < per_page
        
        page += 1
      end
      
      if total_imported == 0
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
        stock: calculate_stock(product),
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

  def calculate_stock(product)
    # If product is not in stock, return 0
    return 0 unless product['in_stock']
    
    # If track_quantity is false, return 0 (unlimited stock)
    return 0 unless product['track_quantity']
    
    # Get stock from variants' inventory_levels
    variants = product['variants'] || []
    total_stock = 0
    
    variants.each do |variant|
      inventory_levels = variant['inventory_levels'] || []
      inventory_levels.each do |level|
        # Sum up the 'available' quantity from all inventory levels
        total_stock += level['available'].to_i
      end
    end
    
    # If no variants or no inventory levels, check if there's a direct inventory_quantity
    if total_stock == 0 && variants.any?
      first_variant = variants.first
      total_stock = first_variant['inventory_quantity'].to_i if first_variant['inventory_quantity']
    end
    
    total_stock
  end

  def import_to_brevo(brevo_products)
    Rails.logger.info "Importing #{brevo_products.length} products to Brevo"
    
    # Import in batches of 50 (Brevo's recommended batch size)
    batch_size = 50
    total_imported = 0
    
    brevo_products.each_slice(batch_size) do |batch|
      Rails.logger.info "Importing batch of #{batch.length} products"
      
      begin
        result = brevo_client.create_products_batch(batch)
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
