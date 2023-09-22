class Server::HetznerDedicated < Server
  def bootstrappable?
    session = Net::SSH.start(
      ip,
      "root",
      key_data: [ENV.fetch("SSH_PRIVATE_KEY")],
      non_interactive: true,
      verify_host_key: :never,
      timeout: 2,
    )
    hostname = session.exec!("hostname")
    session.close
    hostname.include?("rescue")
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::SSH::AuthenticationFailed, Net::SSH::ConnectionTimeout
    false
  ensure
    session&.shutdown!
  end

  def rescue
    Hetzner.active_rescue_system(id)

    if Hetzner.reset_state(id).fetch("operating_status") == "shut off"
      Hetzner.press_power_button(id)
    else
      Hetzner.reset(id)
    end
  end

  def sync_with_provider
    if saved_change_to_name?
      Hetzner.update_server(id, server_name: name)
    end

    if saved_change_to_hetzner_vswitch_id?
      initial_vswitch_id, new_vswitch_id = saved_changes.fetch("hetzner_vswitch_id")

      # The server was connected to a vswitch and we need to disconnect it
      if initial_vswitch_id
        Hetzner.remove_server_from_vswitch(initial_vswitch_id, id)
      end

      if new_vswitch_id
        Hetzner.add_server_to_vswitch(new_vswitch_id, id)
      end
    end
  end
end
