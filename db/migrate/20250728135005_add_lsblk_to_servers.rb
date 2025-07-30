class AddLsblkToServers < ActiveRecord::Migration[8.0]
  def change
    # NOTE: Would use jsonb but SQLite doesn't support it at the moment 😭
    add_column :servers, :lsblk, :json
  end
end
