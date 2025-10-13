class FluidClient
  include HTTParty
  include Fluid::Droplets
  include Fluid::Webhooks
  include Fluid::CallbackDefinitions
  include Fluid::CallbackRegistrations

  base_uri Setting.fluid_api.base_url
  format :json
  
  # Configure timeouts to prevent hanging requests
  default_timeout 30  # 30 seconds timeout (default)
  open_timeout 10      # 10 seconds connection timeout

  Error                 = Class.new(StandardError)
  AuthenticationError   = Class.new(Error)
  ResourceNotFoundError = Class.new(Error)
  APIError              = Class.new(Error)

  def initialize(auth_token = nil)
    @http = self.class
    @auth_token = auth_token
    update_headers
  end

  def get(path, options = {})
    handle_response(@http.get(path, format_options(options)))
  end

  def get_with_timeout(path, options = {}, timeout = nil)
    if timeout
      # Use HTTParty's timeout option for this specific request
      options[:timeout] = timeout
      handle_response(@http.get(path, format_options(options)))
    else
      get(path, options)
    end
  end

  def post(path, options = {})
    handle_response(@http.post(path, format_options(options)))
  end

  def put(path, options = {})
    handle_response(@http.put(path, format_options(options)))
  end

  def delete(path, options = {})
    handle_response(@http.delete(path, format_options(options)))
  end

private

  def update_headers
    self.class.headers "Authorization" => "Bearer #{@auth_token}", "Content-Type" => "application/json"
  end

  def format_options(options)
    options[:body] = options[:body].to_json if options[:body].is_a?(Hash)

    options
  end

  def handle_response(response)
    case response.code
    when 200..299
      # Check if response is actually JSON
      if response.headers['content-type']&.include?('application/json')
        response.parsed_response
      else
        # Response is not JSON, log the actual content
        Rails.logger.error "Non-JSON response received:"
        Rails.logger.error "Content-Type: #{response.headers['content-type']}"
        Rails.logger.error "Response body: #{response.body&.first(1000)}"
        raise APIError, "Expected JSON response but received #{response.headers['content-type']}"
      end
    when 401
      raise AuthenticationError, response
    when 404
      raise ResourceNotFoundError, response
    else
      Rails.logger.error "API Error #{response.code}:"
      Rails.logger.error "Response body: #{response.body&.first(1000)}"
      raise APIError, response
    end
  end
end
