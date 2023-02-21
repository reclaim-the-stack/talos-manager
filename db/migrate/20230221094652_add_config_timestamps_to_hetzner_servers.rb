class AddConfigTimestampsToHetznerServers < ActiveRecord::Migration[7.0]
  def change
    add_column :hetzner_servers, :last_configured_at, :datetime
    add_column :hetzner_servers, :last_request_for_configuration_at, :datetime
  end
end
