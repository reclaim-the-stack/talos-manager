class ApplicationController < ActionController::Base
  default_form_builder ApplicationFormBuilder

  before_action :require_authentication

  private

  def require_authentication
    return if ENV["BASIC_AUTH_PASSWORD"].blank?

    authenticate_or_request_with_http_basic do |_username, password|
      password == ENV.fetch("BASIC_AUTH_PASSWORD")
    end
  end
end
