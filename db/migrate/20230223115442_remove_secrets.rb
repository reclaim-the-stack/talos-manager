class RemoveSecrets < ActiveRecord::Migration[7.0]
  def up
    remove_column :configs, :secret_id
    drop_table :secrets
  end
end
