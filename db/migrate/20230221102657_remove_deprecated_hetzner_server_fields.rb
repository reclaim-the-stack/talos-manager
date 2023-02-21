class RemoveDeprecatedHetznerServerFields < ActiveRecord::Migration[7.0]
  def up
    remove_column :hetzner_servers, :config_id
    remove_column :hetzner_servers, :private_ip
  end
end
