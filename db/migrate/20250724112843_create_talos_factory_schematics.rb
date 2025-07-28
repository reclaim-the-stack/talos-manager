class CreateTalosFactorySchematics < ActiveRecord::Migration[8.0]
  def change
    create_table :talos_image_factory_schematics do |t|
      t.string :name, null: false
      t.string :body, null: false
      t.string :schematic_id, null: false

      t.timestamps
    end

    add_index :talos_image_factory_schematics, :name, unique: true
  end
end
