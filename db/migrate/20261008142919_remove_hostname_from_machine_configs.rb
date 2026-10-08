class RemoveHostnameFromMachineConfigs < ActiveRecord::Migration[8.0]
  # The hostname is now always the name of the server
  def up
    remove_column :machine_configs, :hostname
  end

  def down
    add_column :machine_configs, :hostname, :string
    execute "UPDATE machine_configs SET hostname = servers.name FROM servers WHERE servers.id = machine_configs.server_id"
    change_column_null :machine_configs, :hostname, false
  end
end
