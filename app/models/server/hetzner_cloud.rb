class Server::HetznerCloud < Server
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

    # Hetzner appears to temporarily lock the server immediately after enabling rescue mode.
    # Due to race conditions it's hard to detect this by fetching server status, so we just
    # wait a bit and retry if a "server is locked" error is returned.
    begin
      if api_key.client.server(id).fetch("status") == "off"
        api_key.client.power_on(id)
      else
        api_key.client.reset(id)
      end
    rescue ::HetznerCloud::HttpError => e
      if e.message.include?("locked")
        Rails.logger.info "Server #{id} is locked while enabling rescue mode, retrying in 1 second"
        sleep 1
        retry
      else
        raise
      end
    end
  end

  private

  def sync_with_provider
    if saved_change_to_name?
      api_key.client.update_server(id, name:)
    end
  end
end
