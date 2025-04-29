# frontend/app/controllers/welcome_controller.rb
require 'net/http' # Required for HTTP calls
require 'uri'      # Required for HTTP calls
require 'json'     # Required for parsing JSON

class WelcomeController < ApplicationController
  # Skip CSRF token verification for API-like endpoints if necessary
  # protect_from_forgery with: :null_session, only: [:hello]

  def index
    render plain: "Welcome to the Ruby Demo Frontend App!"
  end

  # Endpoint called by load generator, orchestrates downstream calls
  def hello
    Rails.logger.info("[Frontend] Received /hello request. Calling Inventory Service...")

    begin
      # Call Inventory Service using its Docker Compose service name 'inventory_service' and port '4567'
      # NOTE: The hostname matches the service name in docker-compose.yml
      inventory_service_uri = URI('http://inventory_service:4567/process')

      # Use Net::HTTP for the request. New Relic agent instruments this automatically.
      req = Net::HTTP::Get.new(inventory_service_uri)
      # Add headers if needed, e.g., req['Accept'] = 'application/json'

      response_inventory_http = Net::HTTP.start(inventory_service_uri.hostname, inventory_service_uri.port) do |http|
        http.request(req)
      end

      # Check response code
      unless response_inventory_http.is_a?(Net::HTTPSuccess)
        Rails.logger.error("[Frontend] Error response from Inventory Service: #{response_inventory_http.code} #{response_inventory_http.message}")
        render json: { error: "Inventory Service returned error", status: response_inventory_http.code }, status: :internal_server_error
        return # Stop processing
      end

      response_inventory_body = response_inventory_http.body
      Rails.logger.info("[Frontend] Received successful response from Inventory Service.")

      # Simulate some work in Frontend after getting response
      sleep(rand(0.01..0.03))

      # Render the combined result
      render json: {
        message: "Hello from Frontend (Rails)!",
        inventory_service_response: JSON.parse(response_inventory_body), # Parse the JSON response
        timestamp_frontend: Time.now.iso8601
      }

    rescue JSON::ParserError => e
      Rails.logger.error("[Frontend] Failed to parse JSON response from Inventory Service: #{e.message}")
      render json: { error: "Invalid JSON response from Inventory Service" }, status: :internal_server_error
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("[Frontend] Timeout calling Inventory Service: #{e.message}")
      render json: { error: "Timeout calling Inventory Service", details: e.message }, status: :gateway_timeout
    rescue StandardError => e
      # Catch other potential errors (e.g., connection refused)
      Rails.logger.error("[Frontend] Error calling Inventory Service: #{e.class} - #{e.message}")
      render json: { error: "Failed to call Inventory Service", details: e.message }, status: :internal_server_error
    end
  end
end
