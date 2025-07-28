class SettingsController < ApplicationController
  def show
    @api_keys = ApiKey.all
    @talos_image_factory_setting = TalosImageFactorySetting.singleton
  end
end
