class ApplicationController < ActionController::Base
  default_form_builder ApplicationFormBuilder

  before_action :require_authentication if ENV["BASIC_AUTH_PASSWORD"].present?

  private

  def require_authentication
    authenticate_or_request_with_http_basic do |_username, password|
      password == ENV.fetch("BASIC_AUTH_PASSWORD")
    end
  end
end
