# load_generator/load_generator.rb
require 'net/http'
require 'uri'
require 'json'
require 'time' # Required for Time.now

# --- Configuration ---
# Target URL for the Frontend service within the Docker network
# 'frontend' is the service name defined in docker-compose.yml
target_host = ENV.fetch('TARGET_APP_HOST', 'frontend')
target_port = ENV.fetch('TARGET_APP_PORT', '3000')
target_path = ENV.fetch('TARGET_APP_PATH', '/hello') # Endpoint to hit
target_uri = URI("http://#{target_host}:#{target_port}#{target_path}")

# Load generation parameters
min_sleep = ENV.fetch('MIN_SLEEP', 0.5).to_f
max_sleep = ENV.fetch('MAX_SLEEP', 1.5).to_f
request_timeout = ENV.fetch('REQUEST_TIMEOUT', 10).to_i # seconds
initial_delay = ENV.fetch('INITIAL_DELAY', 15).to_i # seconds to wait before starting

# --- Initialization ---
puts "Load Generator Started."
puts "-------------------------------------------"
puts "Target Service: #{target_uri}"
puts "Request Interval: #{min_sleep}s - #{max_sleep}s"
puts "Request Timeout: #{request_timeout}s"
puts "Initial Delay: #{initial_delay}s"
puts "-------------------------------------------"

# Wait for services to become available (relies on docker-compose depends_on healthchecks)
puts "Waiting #{initial_delay} seconds for services to initialize..."
sleep initial_delay
puts "Starting load generation loop..."

# --- Main Loop ---
loop do
  begin
    start_time = Time.now

    # Create a new HTTP connection for each request
    http = Net::HTTP.new(target_uri.host, target_uri.port)
    http.read_timeout = request_timeout
    http.open_timeout = request_timeout

    # Create a GET request
    request = Net::HTTP::Get.new(target_uri.request_uri)
    request['User-Agent'] = 'LoadGenerator/1.0' # Identify the client

    # Send the request and get the response
    response = http.request(request)
    end_time = Time.now
    duration = ((end_time - start_time) * 1000).round(2) # Duration in milliseconds

    # Print concise status log
    response_body_summary = response.body.nil? ? "[No Body]" : response.body.strip.gsub(/\s+/, ' ')[0..80] # Limit body output
    log_prefix = "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}]"
    puts "#{log_prefix} #{response.code} | #{duration}ms | #{target_uri.path} -> #{response_body_summary}..."

  rescue Net::OpenTimeout => e
    puts "#{log_prefix} Timeout connecting to #{target_uri} after #{request_timeout}s: #{e.message}"
  rescue Net::ReadTimeout => e
    puts "#{log_prefix} Timeout reading response from #{target_uri} after #{request_timeout}s: #{e.message}"
  rescue Errno::ECONNREFUSED => e
     puts "#{log_prefix} Connection refused by #{target_uri}. Service might be down or starting."
  rescue StandardError => e
    # Catch other potential errors (e.g., DNS resolution, unexpected exceptions)
    puts "#{log_prefix} Error: #{e.class} - #{e.message}"
    puts e.backtrace.join("\n") # Print backtrace for unexpected errors
  end

  # Wait for a random interval before sending the next request
  sleep_duration = rand(min_sleep..max_sleep)
  sleep(sleep_duration)
end

puts "Load Generator finished." # This line might not be reached in normal operation
