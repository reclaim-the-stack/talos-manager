class AddAccessibleToHetznerServers < ActiveRecord::Migration[7.0]
  def change
    add_column :hetzner_servers, :accessible, :boolean, null: false, default: false
  end
end
