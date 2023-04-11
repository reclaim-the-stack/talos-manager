# Wrapper around the Hetzner "webservice" API (used for interacting with their bare metal Robots service)
# Documentation at: https://robot.hetzner.com/doc/webservice/en.html

module Hetzner
  HttpError = Class.new(StandardError)

  # Syncs current Hetzner API state to ActiveRecord models
  def self.sync_to_activerecord
    vswitches_full = Hetzner.vswitches.map { |vswitch| Hetzner.vswitch(vswitch.fetch("id")) }

    # Upsert vswitches
    vswitch_attributes = vswitches_full.map do |vswith_payload|
      vswith_payload.slice("id", "name", "vlan")
    end
    HetznerVswitch.upsert_all(vswitch_attributes)

    # Upsert servers
    server_attributes = Hetzner.servers.map do |server_payload|
      vswitch = vswitches_full.find do |vswith_payload|
        vswith_payload.fetch("server").any? do |server|
          server.fetch("server_number") == server_payload.fetch("server_number")
        end
      end

      {
        id: server_payload.fetch("server_number"),
        name: server_payload.fetch("server_name"),
        cancelled: server_payload.fetch("cancelled"),
        data_center: server_payload.fetch("dc"),
        ip: server_payload.fetch("server_ip"),
        ipv6: server_payload.fetch("server_ipv6_net"),
        product: server_payload.fetch("product"),
        status: server_payload.fetch("status"),
        hetzner_vswitch_id: vswitch&.fetch("id"),
      }
    end
    Server.upsert_all(server_attributes)

    # Set server accessible status based on SSH connectability
    threads = Server.all.map do |server|
      Thread.new do
        Net::SSH.start(
          server.ip,
          "root",
          key_data: [ENV.fetch("SSH_PRIVATE_KEY")],
          non_interactive: true,
          verify_host_key: :never,
          timeout: 2,
        ).close
        server
      rescue Errno::ECONNREFUSED, Net::SSH::AuthenticationFailed, Net::SSH::ConnectionTimeout
        nil
      end
    end
    accessible_servers_ids = threads.map(&:value).compact.map(&:id)
    Server.where(id: accessible_servers_ids).update!(accessible: true)
    Server.where.not(id: accessible_servers_ids).update!(accessible: false)
  end

  # https://robot.hetzner.com/doc/webservice/en.html#server
  # Returns information about all servers
  # Limit: 200 requests per 1 hour
  def self.servers
    get("server").map { |server| server.fetch("server") }
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
      authorized_key: devops_talos_manager_ssh_key.fetch("fingerprint"),
    )
  end

  # https://robot.hetzner.com/doc/webservice/en.html#ssh-keys
  # Limit: 500 requests per 1 hour
  def self.ssh_keys
    get("key").map { |key| key.fetch("key") }
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
  def self.devops_talos_manager_ssh_key
    @devops_talos_manager_ssh_key ||= ssh_keys.find { |key| key.fetch("name") == "devops-talos-manager" } or
      raise("SSH key named 'devops-talos-manager' not found on Hetzner account")
  end

  %w[get post delete patch].each do |verb|
    define_singleton_method(verb) do |path, params = nil|
      request(verb, path, params)
    end
  end

  def self.request(method, path, params = nil)
    response = Typhoeus.send(
      method.downcase,
      "#{ENV.fetch('HETZNER_URL')}/#{path}",
      body: params,
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
        "Accept" => "application/json",
      },
    )

    raise HttpError, "#{response.code}, #{response.body}" unless response.success?

    JSON.parse(response.body) unless response.body.empty?
  end
end
