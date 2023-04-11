class GenericServers < ActiveRecord::Migration[7.0]
  def change
    rename_table :hetzner_servers, :servers
    rename_column :machine_configs, :hetzner_server_id, :server_id
  end
end
