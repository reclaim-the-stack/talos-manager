class CreateSecrets < ActiveRecord::Migration[7.0]
  def change
    create_table :secrets do |t|
      t.string :name, null: false
      t.text :secrets, null: false

      t.timestamps
    end
  end
end
