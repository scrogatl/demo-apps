# inventory_service/inventory_service.rb
require 'sinatra'
require 'net/http'
require 'uri'
require 'json'
require 'newrelic_rpm' # Ensure New Relic agent is loaded

# Configure Sinatra
set :bind, '0.0.0.0' # Bind to all interfaces within the container
set :port, 4567      # Port for this service
# Disable Sinatra's built-in logging if relying on stdout/docker logs
# disable :logging

# Define the endpoint that frontend will call
get '/process' do
  content_type :json
  puts "[Inventory Service] Received /process request. Calling User Service..."

  begin
    # Call User Service using its Docker Compose service name 'user_service' and port '4568'
    user_service_uri = URI('http://user_service:4568/data')

    # Use Net::HTTP for the request
    req = Net::HTTP::Get.new(user_service_uri)
    response_user_http = Net::HTTP.start(user_service_uri.hostname, user_service_uri.port) do |http|
        http.request(req)
    end

    # Check response code from User Service
    unless response_user_http.is_a?(Net::HTTPSuccess)
      puts "[Inventory Service] Error response from User Service: #{response_user_http.code} #{response_user_http.message}"
      status 502 # Bad Gateway
      return { error: "User Service returned error", status: response_user_http.code }.to_json
    end

    response_user_body = response_user_http.body
    puts "[Inventory Service] Received successful response from User Service."

    # Simulate some inventory processing work
    sleep(rand(0.02..0.1))

    # Respond back to Frontend (Rails app)
    status 200
    {
      status: 'Processed by Inventory Service',
      user_service_data: JSON.parse(response_user_body), # Parse JSON response from User Service
      timestamp_inventory: Time.now.iso8601
    }.to_json

  rescue JSON::ParserError => e
    puts "[Inventory Service] Failed to parse JSON response from User Service: #{e.message}"
    status 500
    { error: "Invalid JSON response from User Service" }.to_json
  rescue Net::OpenTimeout, Net::ReadTimeout => e
      puts "[Inventory Service] Timeout calling User Service: #{e.message}"
      status 504 # Gateway Timeout
      { error: "Timeout calling User Service", details: e.message }.to_json
  rescue StandardError => e
    # Catch other potential errors (e.g., connection refused)
    puts "[Inventory Service] Error calling User Service: #{e.class} - #{e.message}"
    status 500 # Internal Server Error
    { error: "Failed to call User Service", details: e.message }.to_json
  end
end

# Health check endpoint (used by Docker healthcheck and depends_on)
get '/health' do
  status 200
  content_type :json
  # Could add checks here (e.g., database connection) if needed
  { status: 'OK', service: 'Inventory Service' }.to_json
end

# Optional: Add a root path handler
get '/' do
  content_type :json
  { message: "Inventory Service is running" }.to_json
end


puts "Sinatra Inventory Service starting on port #{settings.port}..."
# Note: Sinatra/Thin will print its own startup message too.
