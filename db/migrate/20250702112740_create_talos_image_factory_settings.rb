class CreateTalosImageFactorySettings < ActiveRecord::Migration[7.2]
  def change
    create_table :talos_image_factory_settings do |t|
      t.string :version, null: false
      t.string :schematic_id

      t.timestamps
    end
  end
end
