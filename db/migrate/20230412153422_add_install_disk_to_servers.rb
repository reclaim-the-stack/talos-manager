class AddInstallDiskToServers < ActiveRecord::Migration[7.0]
  def change
    add_column :servers, :bootstrap_disk, :string
    Server::HetznerCloud.update_all(bootstrap_disk: "/dev/sda")
    Server::HetznerDedicated.update_all(bootstrap_disk: "/dev/nvme0n1")

    add_column :machine_configs, :install_disk, :string, null: false, default: "/dev/sda"
    MachineConfig.includes(:server).find_each do |machine_config|
      machine_config.update!(install_disk: machine_config.server.bootstrap_disk)
    end

    remove_column :configs, :install_disk
  end
end
