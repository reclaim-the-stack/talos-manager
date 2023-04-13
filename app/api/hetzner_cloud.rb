# Wrapper around the Hetzner Cloud API.
# Documentation at: https://docs.hetzner.cloud

module HetznerCloud
  HttpError = Class.new(StandardError)

  BASE_URL = "https://api.hetzner.cloud/v1".freeze

  # Syncs current Hetzner Cloud API state to ActiveRecord models
  def self.sync_to_activerecord
    # Upsert servers
    server_attributes = servers.map do |server_payload|
      {
        id: server_payload.fetch("id"),
        name: server_payload.fetch("name"),
        cancelled: false,
        data_center: server_payload.fetch("datacenter").fetch("name"),
        ip: server_payload.fetch("public_net").fetch("ipv4").fetch("ip"),
        ipv6: server_payload.fetch("public_net").fetch("ipv6").fetch("ip"),
        product: server_payload.fetch("server_type").fetch("name"),
        status: server_payload.fetch("status"),
        hetzner_vswitch_id: nil,
      }
    end
    Server::HetznerCloud.where.not(id: server_attributes.map { |sa| sa.fetch(:id) }).delete_all
    Server::HetznerCloud.upsert_all(server_attributes)
  end

  # https://docs.hetzner.cloud/#server-actions-enable-rescue-mode-for-a-server
  def self.active_rescue_system(server_id)
    post(
      "servers/#{server_id}/actions/enable_rescue",
      ssh_keys: ssh_keys.map { |ssh_key| ssh_key.fetch("id") },
    )
  end

  # https://docs.hetzner.cloud/#server-actions-soft-reboot-a-server
  def self.reset(server_id)
    post("servers/#{server_id}/actions/reset")
  end

  # https://docs.hetzner.cloud/#server-actions-power-on-a-server
  def self.power_on(server_id)
    post("servers/#{server_id}/actions/poweron")
  end

  # https://docs.hetzner.cloud/#ssh-keys-get-all-ssh-keys
  def self.ssh_keys
    get("ssh_keys").fetch("ssh_keys")
  end

  # https://docs.hetzner.cloud/#servers-get-all-servers
  def self.servers
    get("servers").fetch("servers")
  end

  def self.server(id)
    get("servers/#{id}").fetch("server")
  end

  # https://docs.hetzner.cloud/#servers-update-a-server
  def self.update_server(id, params)
    put("servers/#{id}", params)
  end

  %w[get post delete put].each do |verb|
    define_singleton_method(verb) do |path, params = nil|
      request(verb, path, params)
    end
  end

  def self.request(method, path, params = nil)
    response = Typhoeus.send(
      method.downcase,
      "#{BASE_URL}/#{path}",
      body: params&.to_json,
      headers: {
        "Authorization" => "Bearer #{ENV.fetch('HETZNER_CLOUD_API_TOKEN')}",
        "Content-Type" => "application/json",
        "Accept" => "application/json",
      },
    )

    raise HttpError, "#{response.code}, #{response.body}" unless response.success?

    JSON.parse(response.body) unless response.body.empty?
  end
end
