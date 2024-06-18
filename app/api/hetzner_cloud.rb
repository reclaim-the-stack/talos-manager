# Wrapper around the Hetzner Cloud API.
# Documentation at: https://docs.hetzner.cloud

module HetznerCloud
  HttpError = Class.new(StandardError)

  BASE_URL = "https://api.hetzner.cloud/v1".freeze

  # Syncs current Hetzner Cloud API state to ActiveRecord models
  def self.sync_to_activerecord
    if ENV["HETZNER_CLOUD_API_TOKEN"].blank?
      Rails.logger.warn(
        %(class=HetznerCloud action=sync_to_activerecord status=skipped reason="Missing Hetzner cloud API token"),
      )
      return
    end

    # Upsert servers
    server_attributes = servers.map do |server_payload|
      {
        id: server_payload.fetch("id"),
        type: "Server::HetznerCloud",
        architecture: server_payload.fetch("server_type").fetch("architecture") == "arm" ? "arm64" : "amd64",
        cancelled: false,
        data_center: server_payload.fetch("datacenter").fetch("name"),
        hetzner_vswitch_id: nil,
        ip: server_payload.fetch("public_net").fetch("ipv4").fetch("ip"),
        ipv6: server_payload.fetch("public_net").fetch("ipv6").fetch("ip"),
        name: server_payload.fetch("name"),
        product: server_payload.fetch("server_type").fetch("name"),
        status: server_payload.fetch("status"),
      }
    end
    Server::HetznerCloud.where.not(id: server_attributes.map { |sa| sa.fetch(:id) }).destroy_all
    Server.upsert_all(server_attributes) if server_attributes.any?
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
  # NOTE: Since pagination isn't implemented here we only support up to 50 servers.
  def self.servers
    get("servers", per_page: 50).fetch("servers")
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
    url = "#{BASE_URL}/#{path}"
    url += "?#{Rack::Utils.build_query(params)}" if method == "get" && params.present?
    body = params&.to_json unless method == "get"

    response = Typhoeus.send(
      method.downcase,
      url,
      body:,
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
