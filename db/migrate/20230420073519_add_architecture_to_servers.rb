class AddArchitectureToServers < ActiveRecord::Migration[7.0]
  def change
    add_column :servers, :architecture, :string, null: false, default: "amd64"
  end
end
