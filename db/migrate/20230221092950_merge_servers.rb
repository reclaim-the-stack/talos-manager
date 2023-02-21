class MergeServers < ActiveRecord::Migration[7.0]
  def up
    add_column :hetzner_servers, :private_ip, :string
    add_column :hetzner_servers, :config_id, :integer
    add_column :hetzner_servers, :uuid, :string

    add_index :hetzner_servers, :config_id
    add_foreign_key :hetzner_servers, :configs
    add_index :hetzner_servers, :ip, unique: true

    Server.find_each do |server|
      HetznerServer.where(ip: server.public_ip).update!(
        uuid: server.smbios_uuid,
        private_ip: server.private_ip,
        config_id: server.config_id,
      )
    end
  end
end
