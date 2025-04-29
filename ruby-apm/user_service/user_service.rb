# user_service/user_service.rb
require 'sinatra'
require 'json'
require 'newrelic_rpm' # Ensure New Relic agent is loaded

# Configure Sinatra
set :bind, '0.0.0.0' # Bind to all interfaces
set :port, 4568      # Use a different port
# disable :logging # Optional: disable Sinatra logging if using stdout

# Define the endpoint that inventory_service will call
get '/data' do
  content_type :json
  puts "[User Service] Received /data request."

  # Simulate some work (e.g., database query, external API call)
  begin
    # Simulate potential failure occasionally
    if rand(1..10) == 1 # ~10% chance of simulated error
       puts "[User Service] Simulating an error..."
       raise StandardError, "Simulated database connection error"
    end

    processing_time = rand(0.01..0.05)
    puts "[User Service] Simulating work for #{processing_time} seconds..."
    sleep(processing_time)

    puts "[User Service] Responding successfully."
    # Respond back to Inventory Service
    status 200
    {
      status: 'Data provided by User Service',
      user_id: "user_#{rand(100..999)}",
      preference: ["dark_mode", "email_notifications", "sms_alerts"].sample,
      timestamp_user_svc: Time.now.iso8601
    }.to_json

  rescue StandardError => e
    puts "[User Service] Error during processing: #{e.message}"
    status 500 # Internal Server Error
    { error: "User Service failed processing", details: e.message }.to_json
  end
end

# Health check endpoint (used by Docker healthcheck and depends_on)
get '/health' do
  status 200
  content_type :json
  # Could add checks here (e.g., database connection) if needed
  { status: 'OK', service: 'User Service' }.to_json
end

# Optional: Add a root path handler
get '/' do
  content_type :json
  { message: "User Service is running" }.to_json
end

puts "Sinatra User Service starting on port #{settings.port}..."
# Note: Sinatra/Thin will print its own startup message too.
