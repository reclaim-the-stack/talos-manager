class RemoveSuperfluousColumnsFromConfigs < ActiveRecord::Migration[7.0]
  def change
    remove_column :configs, :cluster_name, :string
    remove_column :configs, :cluster_endpoint, :string
    rename_column :configs, :talos_image, :install_image
  end
end
