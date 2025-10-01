class ChangeTalosImageFactorySettingsSchematicIdIntoReference < ActiveRecord::Migration[8.0]
  def up
    add_reference :talos_image_factory_settings, :talos_image_factory_schematic, foreign_key: true

    setting = TalosImageFactorySetting.singleton
    schematic_id = setting.try(:schematic_id)
    talos_image_factory_schematic = schematic_id && TalosImageFactorySchematic.find_by(schematic_id:)

    if talos_image_factory_schematic
      TalosImageFactorySetting.singleton.update!(talos_image_factory_schematic_id: talos_image_factory_schematic.id)
    end
  end

  def down
    remove_reference :talos_image_factory_settings, :talos_image_factory_schematic, foreign_key: true
  end
end
