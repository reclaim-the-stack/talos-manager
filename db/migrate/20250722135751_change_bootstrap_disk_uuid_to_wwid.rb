class ChangeBootstrapDiskUuidToWwid < ActiveRecord::Migration[8.0]
  def change
    rename_column :servers, :bootstrap_disk_uuid, :bootstrap_disk_wwid
  end
end
