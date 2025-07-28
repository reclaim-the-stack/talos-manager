class AddTalosImageFactorySchematicIdToServers < ActiveRecord::Migration[8.0]
  def change
    add_reference :servers, :talos_image_factory_schematic, foreign_key: true
  end
end
