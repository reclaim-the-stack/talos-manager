class AddStiToServers < ActiveRecord::Migration[7.0]
  def change
    add_column :servers, :type, :string, null: false, default: "Server::HetznerDedicated"
    add_index :servers, :type
  end
end
