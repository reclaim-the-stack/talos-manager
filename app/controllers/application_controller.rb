class ApplicationController < ActionController::Base
  default_form_builder ApplicationFormBuilder

  before_action :require_authentication

  private

  def require_authentication
    authenticate_or_request_with_http_basic do |username, password|
      ENV["BASIC_AUTH_PASSWORD"].blank? || password == ENV.fetch("BASIC_AUTH_PASSWORD")
    end
  end
end
