class SettingsController < ApplicationController
  def show
    @api_keys = ApiKey.all
  end
end
