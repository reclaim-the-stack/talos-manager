class Server::HetznerDedicated < Server
  def bootstrap_metadata
    return @bootstrap_metadata if defined?(@bootstrap_metadata)

    key_data = [ENV.fetch("SSH_PRIVATE_KEY")]
    session = Net::SSH.start(ip, "root", key_data:, non_interactive: true, verify_host_key: :never, timeout: 2)
    hostname = session.exec!("hostname")
    bootstrappable = hostname.include?("rescue")

    # Populate bootstrap_metadata with necessary information
    if bootstrappable
      uuid = session.exec!("dmidecode -s system-uuid").chomp
      lsblk_output = session.exec!("lsblk --output NAME,TYPE,SIZE,UUID,MODEL,WWN --bytes --json")
      lsblk = JSON.parse(lsblk_output)
    end

    @bootstrap_metadata = { bootstrappable:, uuid:, lsblk: }
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::SSH::AuthenticationFailed, Net::SSH::ConnectionTimeout
    @bootstrap_metadata = { bootstrappable: false, uuid: nil, lsblk: nil }
  ensure
    session&.shutdown!
  end

  def rescue
    api_key.client.active_rescue_system(id)

    if api_key.client.reset_state(id).fetch("operating_status") == "shut off"
      api_key.client.press_power_button(id)
    else
      api_key.client.reset(id)
    end
  end

  def sync_with_provider
    if saved_change_to_name?
      api_key.client.update_server(id, server_name: name)
    end

    if saved_change_to_hetzner_vswitch_id?
      initial_vswitch_id, new_vswitch_id = saved_changes.fetch("hetzner_vswitch_id")

      # The server was connected to a vswitch and we need to disconnect it
      if initial_vswitch_id
        api_key.client.remove_server_from_vswitch(initial_vswitch_id, id)
      end

      if new_vswitch_id
        api_key.client.add_server_to_vswitch(new_vswitch_id, id)
      end
    end
  end
end
