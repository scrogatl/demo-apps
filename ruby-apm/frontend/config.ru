# frontend/config.ru

# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

# Explicitly run the Rails application defined in config/application.rb
run Rails.application

# If you have specific middleware or other Rack setup, it would go here.
# For example:
# use Rack::ContentLength