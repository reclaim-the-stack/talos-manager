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

    server.bootstrap!

    redirect_to servers_path
  end

  def rescue
    server = Server.find(params[:id])

    Hetzner.active_rescue_system(server.id)
    Hetzner.reset(server.id)

    redirect_to servers_path
  end

  def sync
    Hetzner.sync_to_activerecord

    redirect_to servers_path
  end
end
