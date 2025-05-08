# frontend/config/application.rb
require_relative "boot"
require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Define the Rails application module. The name should match the directory
# or a logical name for your app. Let's call it FrontendApp.
module FrontendApp
  class Application < Rails::Application
    config.load_defaults 7.1
    config.autoload_lib(ignore: %w(assets tasks))
    config.generators.system_tests = nil
    config.log_level = :info # or :debug
    config.log_formatter = ::Logger::Formatter.new
  end
end
