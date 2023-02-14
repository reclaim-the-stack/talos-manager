class CreateServers < ActiveRecord::Migration[7.0]
  def change
    create_table :servers do |t|
      t.string :state, null: false, default: "pending"
      t.string :public_ip, null: false
      t.string :smbios_uuid, null: false
      t.string :private_ip
      t.string :hostname
      t.belongs_to :config

      t.timestamps
    end
    add_index :servers, :public_ip, unique: true
  end
end
