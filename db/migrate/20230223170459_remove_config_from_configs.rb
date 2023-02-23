class RemoveConfigFromConfigs < ActiveRecord::Migration[7.0]
  def change
    remove_column :configs, :config, :text
  end
end
