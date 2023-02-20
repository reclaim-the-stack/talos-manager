# Wrapper around the Hetzner "webservice" API (used for interacting with their bare metal Robots service)
# Documentation at: https://robot.hetzner.com/doc/webservice/en.html

module Hetzner
  HttpError = Class.new(StandardError)

  # Syncs current Hetzner API state to ActiveRecord models
  def self.sync_to_activerecord
    vswitches_full = vswitches.map { |vswitch| Hetzner.vswitch(vswitch.fetch("id")) }

    vswitches_full.each do |vswitch_payload|
      vswitch_params = vswitch_payload.slice("name", "vlan")

      HetznerVswitch.create_with(vswitch_params).find_or_create_by!(id: vswitch_payload.fetch("id"))
    end

    servers.each do |server_payload|
      server_params = {
        name: server_payload.fetch("server_name"),
        cancelled: server_payload.fetch("cancelled"),
        data_center: server_payload.fetch("dc"),
        ip: server_payload.fetch("server_ip"),
        ipv6: server_payload.fetch("server_ipv6_net"),
        product: server_payload.fetch("product"),
        status: server_payload.fetch("status"),
      }

      HetznerServer.create_with(server_params).find_or_create_by!(id: server_payload.fetch("server_number"))
    end

    vswitches_full.each do |vswitch_payload|
      vswitch_id = vswitch_payload.fetch("id")
      server_ids = vswitch_payload.fetch("server").map { |server| server.fetch("server_number") }

      HetznerServer
        .where(id: server_ids)
        .update!(hetzner_vswitch_id: vswitch_id)

      HetznerServer
        .where(hetzner_vswitch_id: vswitch_id)
        .where.not(id: server_ids)
        .update!(hetzner_vswitch_id: nil)
    end
  end

  # https://robot.hetzner.com/doc/webservice/en.html#server
  # Returns information about all servers
  # Limit: 200 requests per 1 hour
  def self.servers
    get("server").map { |server| server.fetch("server") }
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

  def self.add_server_to_vswitch(vswitch_id, server_ids)
    server_ids = Array.wrap(server_ids)

    post("vswitch/#{vswitch_id}/server", server: server_ids)
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
      body: params.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
      },
    )

    raise HttpError, "#{response.code}, #{response.body}" unless response.success?

    JSON.parse(response.body)
  end
end
