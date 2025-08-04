class AddEphemeralDiskIdentifierToMachineConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :machine_configs, :ephemeral_disk_identifier, :string
  end
end
