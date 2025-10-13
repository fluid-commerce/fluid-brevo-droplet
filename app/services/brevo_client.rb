# frozen_string_literal: true

class BrevoClient
  include HTTParty

  base_uri 'https://api.brevo.com/v3'

  def initialize(api_key = nil)
    @api_key = api_key
  end

  def api_key
    @api_key || ENV['BREVO_API_KEY']
  end

  # Email API methods
  def send_transactional_email(email_params)
    make_request(:post, '/smtp/email', body: email_params.to_json)
  end

  def send_batch_emails(batch_params)
    make_request(:post, '/smtp/email', body: batch_params.to_json)
  end

  # Contacts API methods
  def create_contact(contact_params)
    make_request(:post, '/contacts', body: contact_params.to_json)
  end

  def update_contact(identifier, contact_params)
    make_request(:put, "/contacts/#{identifier}", body: contact_params.to_json)
  end

  def get_contact(identifier)
    make_request(:get, "/contacts/#{identifier}")
  end

  def delete_contact(identifier)
    make_request(:delete, "/contacts/#{identifier}")
  end

  def import_contacts(import_params)
    Rails.logger.info "Import params: #{import_params.inspect}"
    Rails.logger.info "fileBody content: #{import_params[:fileBody]}"
    
    # Keep consistent with other methods - send as JSON
    # The fileBody will be properly JSON-encoded as a string
    make_request(:post, '/contacts/import', body: import_params.to_json)
  end

  def get_contacts(options = {})
    query_params = options.any? ? "?#{options.to_query}" : ""
    make_request(:get, "/contacts#{query_params}")
  end

  # Email Campaigns API methods
  def create_campaign(campaign_params)
    make_request(:post, '/emailCampaigns', body: campaign_params.to_json)
  end

  def get_campaign(campaign_id)
    make_request(:get, "/emailCampaigns/#{campaign_id}")
  end

  def update_campaign(campaign_id, campaign_params)
    make_request(:put, "/emailCampaigns/#{campaign_id}", body: campaign_params.to_json)
  end

  def send_campaign(campaign_id)
    make_request(:post, "/emailCampaigns/#{campaign_id}/sendNow")
  end

  def get_campaign_report(campaign_id)
    make_request(:get, "/emailCampaigns/#{campaign_id}/report")
  end

  def get_campaigns(options = {})
    query_params = options.any? ? "?#{options.to_query}" : ""
    make_request(:get, "/emailCampaigns#{query_params}")
  end

  # Webhooks API methods
  def create_webhook(webhook_params)
    make_request(:post, '/webhooks', body: webhook_params.to_json)
  end

  def get_webhooks
    make_request(:get, '/webhooks')
  end

  def update_webhook(webhook_id, webhook_params)
    make_request(:put, "/webhooks/#{webhook_id}", body: webhook_params.to_json)
  end

  def delete_webhook(webhook_id)
    make_request(:delete, "/webhooks/#{webhook_id}")
  end

  def get_webhook(webhook_id)
    make_request(:get, "/webhooks/#{webhook_id}")
  end

  # Account API methods
  def get_account
    make_request(:get, '/account')
  end

  def get_account_limits
    make_request(:get, '/account/limits')
  end

  # Senders API methods
  def get_senders
    make_request(:get, '/senders')
  end

  # Lists API methods
  def create_list(list_params)
    make_request(:post, '/contacts/lists', body: list_params.to_json)
  end

  def get_lists(options = {})
    query_params = options.any? ? "?#{options.to_query}" : ""
    make_request(:get, "/contacts/lists#{query_params}")
  end

  def get_list(list_id)
    make_request(:get, "/contacts/lists/#{list_id}")
  end

  def update_list(list_id, list_params)
    make_request(:put, "/contacts/lists/#{list_id}", body: list_params.to_json)
  end

  def delete_list(list_id)
    make_request(:delete, "/contacts/lists/#{list_id}")
  end

  # Folders API methods
  def get_folders
    make_request(:get, '/contacts/folders')
  end

  def create_folder(folder_params)
    make_request(:post, '/contacts/folders', body: folder_params.to_json)
  end

  def get_folder(folder_id)
    make_request(:get, "/contacts/folders/#{folder_id}")
  end

  def update_folder(folder_id, folder_params)
    make_request(:put, "/contacts/folders/#{folder_id}", body: folder_params.to_json)
  end

  def delete_folder(folder_id)
    make_request(:delete, "/contacts/folders/#{folder_id}")
  end


  def create_attribute_with_category(attribute_category, attribute_name, attribute_params)
    make_request(:post, "/contacts/attributes/#{attribute_category}/#{attribute_name}", body: attribute_params.to_json)
  end

  def get_attributes
    make_request(:get, '/contacts/attributes')
  end

  def delete_attribute(attribute_name)
    make_request(:delete, "/contacts/attributes/#{attribute_name}")
  end

  # Templates API methods
  def get_templates(options = {})
    query_params = options.any? ? "?#{options.to_query}" : ""
    make_request(:get, "/smtp/templates#{query_params}")
  end

  def get_template(template_id)
    make_request(:get, "/smtp/templates/#{template_id}")
  end

  # Contact search and filtering
  def search_contacts(search_params)
    make_request(:post, '/contacts/search', body: search_params.to_json)
  end

  def get_contact_stats(identifier)
    make_request(:get, "/contacts/#{identifier}/stats")
  end

  # Batch operations for contact sync
  def create_contacts_batch(contacts_data)
    make_request(:post, '/contacts/batch', body: contacts_data.to_json)
  end

  def update_contacts_batch(contacts_data)
    make_request(:put, '/contacts/batch', body: contacts_data.to_json)
  end

  def create_products_batch(products)
    Rails.logger.info "BrevoClient creating products batch with #{products.length} products"
    
    result = make_request(:post, '/products/batch', body: { 
      products: products,
      updateEnabled: true
    }.to_json)
    
    Rails.logger.info "BrevoClient products batch response: #{result.inspect}"
    result
  end

  def create_categories_batch(categories)
    Rails.logger.info "BrevoClient creating categories batch with #{categories.length} categories"
    Rails.logger.info "Categories being sent: #{categories.inspect}"
    
    request_body = { 
      categories: categories,
      updateEnabled: true
    }
    
    Rails.logger.info "Request body: #{request_body.to_json}"
    
    result = make_request(:post, '/categories/batch', body: request_body.to_json)
    
    Rails.logger.info "BrevoClient categories batch response: #{result.inspect}"
    result
  end

  def create_orders_batch(orders)
    Rails.logger.info "BrevoClient creating orders batch with #{orders.length} orders"
    Rails.logger.info "Orders being sent: #{orders.inspect}"

    request_body = { 
      orders: orders,
      historical: true
    }
    
    Rails.logger.info "Request body: #{request_body.to_json}"
    
    result = make_request(:post, '/orders/status/batch', body: request_body.to_json)
    
    Rails.logger.info "BrevoClient orders batch response: #{result.inspect}"
    result
  end

  def activate_ecommerce
    make_request(:post, '/ecommerce/activate')
  end

  private

  def default_headers
    {
      'api-key' => api_key,
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  def make_request(method, endpoint, options = {})
    Rails.logger.info "BrevoClient making #{method.upcase} request to: #{endpoint}"
    Rails.logger.info "Request headers: #{default_headers.except('api-key').merge('api-key' => '[REDACTED]').inspect}"
    
    if options[:body]
      Rails.logger.info "Request body (first 1000 chars): #{options[:body][0..1000]}"
      Rails.logger.info "Request body length: #{options[:body].length} characters"
    end
    
    response = self.class.send(
      method,
      endpoint,
      {
        headers: default_headers,
        timeout: 30
      }.merge(options)
    )

    Rails.logger.info "BrevoClient response code: #{response.code}"
    Rails.logger.info "BrevoClient response body: #{response.parsed_response.inspect}"
    
    handle_response(response)
  end

  def handle_response(response)
    case response.code
    when 200..299
      response.parsed_response
    when 400
      raise BrevoApiError.new("Bad Request: #{response.parsed_response['message']}", response.code)
    when 401
      raise BrevoApiError.new("Unauthorized: Invalid API key", response.code)
    when 403
      raise BrevoApiError.new("Forbidden: #{response.parsed_response['message']}", response.code)
    when 404
      raise BrevoApiError.new("Not Found: #{response.parsed_response['message']}", response.code)
    when 429
      raise BrevoApiError.new("Rate Limited: Too many requests", response.code)
    when 500..599
      raise BrevoApiError.new("Server Error: #{response.parsed_response['message']}", response.code)
    else
      raise BrevoApiError.new("Unexpected error: #{response.parsed_response['message']}", response.code)
    end
  rescue HTTParty::Error => e
    Rails.logger.error "Brevo HTTP Error: #{e.message}"
    raise BrevoApiError.new("HTTP Error: #{e.message}", 0)
  end
end

# Custom error class for Brevo API errors
class BrevoApiError < StandardError
  attr_reader :status_code

  def initialize(message, status_code = nil)
    super(message)
    @status_code = status_code
  end
end
