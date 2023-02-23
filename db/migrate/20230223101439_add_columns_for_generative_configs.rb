class AddColumnsForGenerativeConfigs < ActiveRecord::Migration[7.0]
  def change
    change_table :configs do |t|
      t.references :secret, foreign_key: true
      t.column :cluster_name, :string
      t.column :cluster_endpoint, :string
      t.column :install_disk, :string, null: false, default: "/dev/nvme0n1"
      t.column :talos_image, :string, null: false, default: "ghcr.io/siderolabs/installer:v1.3.5"
      t.column :kubernetes_version, :string, null: false, default: "1.24.8"
      t.column :patch, :text
      t.column :patch_control_plane, :text
      t.column :patch_worker, :text
    end

    Config.find_each do |config|
      config_data = YAML.load(config.config)
      config.update_columns(
        cluster_name: config_data.dig("cluster", "clusterName"),
        cluster_endpoint: config_data.dig("cluster", "controlPlane", "endpoint"),
      )
    end

    change_column_null :configs, :cluster_name, false
    change_column_null :configs, :cluster_endpoint, false
  end
end
