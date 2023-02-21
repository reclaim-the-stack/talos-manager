class CreateMachineConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :machine_configs do |t|
      t.references :config, null: false, foreign_key: true
      t.references :hetzner_server, null: false, foreign_key: true
      t.string :hostname, null: false
      t.string :private_ip, null: false

      t.timestamps
    end

    HetznerServer.where.not(config_id: nil).find_each do |hetzner_server|
      hetzner_server.create_machine_config!(
        config_id: hetzner_server.config_id,
        hostname: hetzner_server.name,
        private_ip: hetzner_server.private_ip,
      )
    end
  end
end
