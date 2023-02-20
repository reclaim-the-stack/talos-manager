class CreateHetznerServers < ActiveRecord::Migration[7.0]
  def change
    create_table :hetzner_servers do |t|
      t.string :name
      t.string :ip, null: false
      t.string :ipv6, null: false
      t.string :product, null: false
      t.string :data_center, null: false
      t.string :status, null: false
      t.boolean :cancelled, null: false
      t.references :hetzner_vswitch, foreign_key: true

      t.timestamps
    end
  end
end
