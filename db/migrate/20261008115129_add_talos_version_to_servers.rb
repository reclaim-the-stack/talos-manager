class AddTalosVersionToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :talos_version, :string
  end
end
