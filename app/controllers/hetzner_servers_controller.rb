class HetznerServersController < ApplicationController
  def index
    @hetzner_servers = HetznerServer.all
      .includes(:hetzner_vswitch, :config)
      .order(hetzner_vswitch_id: :asc, name: :asc)
  end

  def edit
    @hetzner_server = HetznerServer.find(params[:id])
  end

  def update
    @hetzner_server = HetznerServer.find(params[:id])

    hetzner_server_params = params.require(:hetzner_server).permit(:name, :hetzner_vswitch_id)

    @hetzner_server.update!(hetzner_server_params.merge(sync: true))

    redirect_to hetzner_servers_path
  end

  def bootstrap
    hetzner_server = HetznerServer.find(params[:id])

    hetzner_server.bootstrap!

    redirect_to hetzner_servers_path
  end

  def rescue
    hetzner_server = HetznerServer.find(params[:id])

    Hetzner.active_rescue_system(hetzner_server.id)
    Hetzner.reset(hetzner_server.id)

    redirect_to hetzner_servers_path
  end

  def sync
    Hetzner.sync_to_activerecord

    redirect_to hetzner_servers_path
  end
end
