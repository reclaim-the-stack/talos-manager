class AddLsblkToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :lsblk, :jsonb
  end
end
