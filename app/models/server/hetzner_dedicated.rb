class Server::HetznerDedicated < Server
  def rescue
    Hetzner.active_rescue_system(id)
    Hetzner.reset(id)
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
