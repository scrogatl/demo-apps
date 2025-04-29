# frontend/config/environments/application.rb
Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.logger = ActiveSupport::Logger.new(STDOUT).tap do |logger|
    logger.formatter = ::Logger::Formatter.new
  end
  config.log_tags = [:request_id]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
end