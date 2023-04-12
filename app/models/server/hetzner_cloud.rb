class Server::HetznerCloud < Server
  def rescue
    ::HetznerCloud.active_rescue_system(id)

    # Hetzner appears to temporarily lock the server immediately after enabling rescue mode
    sleep 1

    if ::HetznerCloud.server(id).fetch("status") == "off"
      ::HetznerCloud.power_on(id)
    else
      ::HetznerCloud.reset(id)
    end
  end

  private

  def sync_with_provider
    if saved_change_to_name?
      ::HetznerCloud.update_server(id, name: name)
    end
  end
end
