class CreateConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :configs do |t|
      t.string :name, null: false
      t.text :config, null: false

      t.timestamps
    end
    add_index :configs, :name, unique: true
  end
end
