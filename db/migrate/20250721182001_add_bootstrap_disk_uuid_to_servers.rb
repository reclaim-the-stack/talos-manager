class AddBootstrapDiskUuidToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :bootstrap_disk_uuid, :string
  end
end
