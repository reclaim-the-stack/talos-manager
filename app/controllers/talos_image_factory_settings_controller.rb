class TalosImageFactorySettingsController < ApplicationController
  def update
    @talos_image_factory_setting = TalosImageFactorySetting.singleton

    talos_image_factory_setting_params = params.require(:talos_image_factory_setting).permit(
      :version,
      :schematic_id,
    )

    if @talos_image_factory_setting.update(talos_image_factory_setting_params)
      # redirect_to settings_path, status: 303, notice: "Talos Image Factory settings updated successfully."
      flash.now[:talos_image_factory_update_notice] = "Talos Image Factory settings updated successfully."
      render :edit
    else
      render :edit, status: 422
    end
  end
end
