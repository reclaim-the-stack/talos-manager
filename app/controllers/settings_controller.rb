class SettingsController < ApplicationController
  def show
    @api_keys = ApiKey.all
    @talos_image_factory_setting = TalosImageFactorySetting.first_or_create!
  end
end
