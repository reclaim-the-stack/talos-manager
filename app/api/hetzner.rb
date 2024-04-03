# Wrapper around the Hetzner "webservice" API (used for interacting with their bare metal Robots service)
# Documentation at: https://robot.hetzner.com/doc/webservice/en.html

module Hetzner
  HttpError = Class.new(StandardError)

  # Syncs current Hetzner API state to ActiveRecord models
  def self.sync_to_activerecord
    if ENV["HETZNER_WEBSERVICE_USER"].blank? || ENV["HETZNER_WEBSERVICE_PASSWORD"].blank?
      Rails.logger.warn(
        %(class=Hetzner action=sync_to_activerecord status=skipped reason="Missing Hetzner webservice credentials"),
      )
      return
    end

    vswitches_full = Hetzner.vswitches.map { |vswitch| Hetzner.vswitch(vswitch.fetch("id")) }

    # Upsert vswitches
    vswitch_attributes = vswitches_full.map do |vswith_payload|
      vswith_payload.slice("id", "name", "vlan")
    end
    HetznerVswitch.upsert_all(vswitch_attributes) if vswitch_attributes.any?

    # Upsert servers
    server_attributes = Hetzner.servers.map do |server_payload|
      vswitch = vswitches_full.find do |vswith_payload|
        vswith_payload.fetch("server").any? do |server|
          server.fetch("server_number") == server_payload.fetch("server_number")
        end
      end

      {
        id: server_payload.fetch("server_number"),
        type: "Server::HetznerDedicated",
        architecture: server_payload.fetch("product").start_with?("RX") ? "arm64" : "amd64",
        cancelled: server_payload.fetch("cancelled"),
        data_center: server_payload.fetch("dc"),
        hetzner_vswitch_id: vswitch&.fetch("id"),
        ip: server_payload.fetch("server_ip"),
        ipv6: server_payload.fetch("server_ipv6_net"),
        name: server_payload.fetch("server_name"),
        product: server_payload.fetch("product"),
        status: server_payload.fetch("status"),
      }
    end
    Server::HetznerDedicated.where.not(id: server_attributes.map { |sa| sa.fetch(:id) }).destroy_all
    Server.upsert_all(server_attributes) if server_attributes.any?
  end

  # https://robot.hetzner.com/doc/webservice/en.html#server
  # Returns information about all servers
  # Limit: 200 requests per 1 hour
  def self.servers
    get("server").map { |server| server.fetch("server") }
  end

  # https://robot.hetzner.com/doc/webservice/en.html#get-server-server-number
  # Query server data for a specific server
  # Limit: 200 requests per 1 hour
  def self.server(id)
    get("server/#{id}").fetch("server")
  end

  # https://robot.hetzner.com/doc/webservice/en.html#post-server-server-number
  # Limit: 200 requests per 1 hour
  def self.update_server(server_id, params)
    post("server/#{server_id}", params)
  end

  # https://robot.hetzner.com/doc/webservice/en.html#get-vswitch
  # Returns information about all vswitches
  # Limit: 500 requests per 1 hour
  def self.vswitches
    get("vswitch")
  end

  # https://robot.hetzner.com/doc/webservice/en.html#get-vswitch-vswitch-id
  # Returns full information about a single vswitch
  # Limit: 500 requests per 1 hour
  def self.vswitch(id)
    get("vswitch/#{id}")
  end

  # https://robot.hetzner.com/doc/webservice/en.html#post-vswitch-vswitch-id-server
  # Limit: 100 requests per 1 hour
  def self.add_server_to_vswitch(vswitch_id, server_id)
    post("vswitch/#{vswitch_id}/server", server: server_id)
  end

  # https://robot.hetzner.com/doc/webservice/en.html#delete-vswitch-vswitch-id-server
  # Limit: 100 requests per 1 hour
  def self.remove_server_from_vswitch(vswitch_id, server_id)
    delete("vswitch/#{vswitch_id}/server", server: server_id)
  end

  # https://robot.hetzner.com/doc/webservice/en.html#post-boot-server-number-rescue
  # Limit: 500 requests per 1 hour
  def self.active_rescue_system(server_id)
    post(
      "boot/#{server_id}/rescue",
      os: "linux",
      authorized_key: talos_manager_ssh_key.fetch("fingerprint"),
    )
  rescue HttpError => e
    raise unless e.message.include? "BOOT_ALREADY_ENABLED"
  end

  # https://robot.hetzner.com/doc/webservice/en.html#ssh-keys
  # Limit: 500 requests per 1 hour
  def self.ssh_keys
    get("key").map { |key| key.fetch("key") }
  end

  # https://robot.hetzner.com/doc/webservice/en.html#get-reset-server-number
  # Query reset options for a specific server. Also returns the current reset state.
  # Limit: 500 requests per 1 hour
  def self.reset_state(server_id)
    get("reset/#{server_id}").fetch("reset")
  end

  # https://robot.hetzner.com/doc/webservice/en.html#get-reset-server-number
  # Execute a hardware reset on a server
  # Limit: 50 requests per hour
  def self.reset(server_id)
    post("reset/#{server_id}", type: "hw")
  end

  def self.press_power_button(server_id)
    post("reset/#{server_id}", type: "power")
  end

  # Finds and memoizes an SSH key named 'devops-talos-manager' on the Hetzner account
  def self.talos_manager_ssh_key
    @talos_manager_ssh_key ||= ssh_keys.find { |key| key.fetch("name").include? "talos-manager" } or
      raise("SSH key named 'talos-manager' not found on Hetzner account")
  end

  %w[get post delete patch].each do |verb|
    define_singleton_method(verb) do |path, params = nil|
      request(verb, path, params)
    end
  end

  def self.headers
    @headers ||= begin
      username = ENV.fetch("HETZNER_WEBSERVICE_USER")
      password = ENV.fetch("HETZNER_WEBSERVICE_PASSWORD")
      basic_auth = Base64.strict_encode64("#{username}:#{password}")
      {
        "Content-Type" => "application/x-www-form-urlencoded",
        "Accept" => "application/json",
        "Authorization" => "Basic #{basic_auth}",
      }
    end
  end

  def self.request(method, path, params = nil)
    response = Typhoeus.send(
      method.downcase,
      "https://robot-ws.your-server.de/#{path}",
      body: params,
      headers:,
    )

    raise HttpError, "#{response.code}, #{response.body}" unless response.success?

    JSON.parse(response.body) unless response.body.empty?
  end
end
