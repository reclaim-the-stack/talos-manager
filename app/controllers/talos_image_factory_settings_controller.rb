class TalosImageFactorySettingsController < ApplicationController
  def update
    @talos_image_factory_setting = TalosImageFactorySetting.singleton

    talos_image_factory_setting_params = params.require(:talos_image_factory_setting).permit(
      :version,
      :talos_image_factory_schematic_id,
    )

    if @talos_image_factory_setting.update(talos_image_factory_setting_params)
      flash.now[:talos_image_factory_update_notice] = "Talos Image Factory settings updated successfully."
      render :edit
    else
      render :edit, status: 422
    end
  end
end
