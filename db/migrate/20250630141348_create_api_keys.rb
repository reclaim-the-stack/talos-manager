class CreateApiKeys < ActiveRecord::Migration[7.2]
  def change
    create_table :api_keys do |t|
      t.string :provider, null: false
      t.string :name, null: false
      t.string :secret, null: false

      t.timestamps
    end

    add_index :api_keys, :name, unique: true
  end
end
