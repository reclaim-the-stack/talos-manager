class AddKubespanToConfigs < ActiveRecord::Migration[7.0]
  def change
    add_column :configs, :kubespan, :boolean, null: false, default: false
  end
end
