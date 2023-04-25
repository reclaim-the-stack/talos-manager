class ServersController < ApplicationController
  def index
    @servers = Server.all
      .includes(:config, :cluster)
      .order(hetzner_vswitch_id: :asc, name: :asc)
  end

  def edit
    @server = Server.find(params[:id])
  end

  def update
    @server = Server.find(params[:id])

    server_params = params.require(:server).permit(
      :name,
      :hetzner_vswitch_id,
      :cluster_id,
    )

    if @server.update(server_params.merge(sync: true))
      @servers = Server.all
        .includes(:hetzner_vswitch, :config, :cluster)
        .order(hetzner_vswitch_id: :asc, name: :asc)
      redirect_to servers_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def bootstrap
    server = Server.find(params[:id])

    # pretend it's not accessible while bootstrapping to hide bootstrap button
    server.update!(accessible: false)

    ServerBootstrapJob.perform_later(server.id)

    redirect_to servers_path, notice: "Server #{server.name} is being bootstrapped"
  end

  def rescue
    server = Server.find(params[:id])

    server.rescue

    redirect_to servers_path, notice: "Server #{server.name} is rebooting in rescue mode"
  end

  def reset
    server = Server.find(params[:id])

    if server.reset
      redirect_to servers_path, notice: "Server #{server.name} is being reset"
    else
      redirect_to servers_path, alert: "Failed to execute talosctl reset for #{server.name}"
    end
  rescue Cluster::NoControlPlaneError
    redirect_to servers_path, alert: "Can't reset server without a cluster control plane server configured!"
  end

  def sync
    Hetzner.sync_to_activerecord
    HetznerCloud.sync_to_activerecord

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
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::SSH::AuthenticationFailed, Net::SSH::ConnectionTimeout
        nil
      end
    end
    accessible_servers_ids = threads.map(&:value).compact.map(&:id)
    Server.where(id: accessible_servers_ids).update!(accessible: true)
    Server.where.not(id: accessible_servers_ids).update!(accessible: false)

    redirect_to servers_path, notice: "Synced servers"
  end
end
