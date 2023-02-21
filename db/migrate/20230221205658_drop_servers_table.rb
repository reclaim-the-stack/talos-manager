class DropServersTable < ActiveRecord::Migration[7.0]
  def change
    drop_table :servers
  end
end
