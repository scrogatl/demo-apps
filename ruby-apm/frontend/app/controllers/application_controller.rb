# frontend/app/controllers/application_controller.rb

# Base controller for the application. All other controllers should inherit from this.
class ApplicationController < ActionController::Base
    # Prevent CSRF attacks by raising an exception.
    # For APIs, you may want to use :null_session instead.
    # protect_from_forgery with: :exception # Uncomment if building a traditional web app with forms
    # protect_from_forgery with: :null_session # Use this if your controller primarily serves API requests
  
    # Add any application-wide controller logic here.
end