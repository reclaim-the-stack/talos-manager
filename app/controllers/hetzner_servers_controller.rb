class HetznerServersController < ApplicationController
  def index
    @hetzner_servers = HetznerServer.all.order(name: :asc).includes(:hetzner_vswitch)
  end

  def edit
    @hetzner_server = HetznerServer.find(params[:id])
  end

  def update
    @hetzner_server = HetznerServer.find(params[:id])

    hetzner_server_params = params.require(:hetzner_server).permit(:name, :hetzner_vswitch_id)

    @hetzner_server.update!(hetzner_server_params)

    @hetzner_servers = HetznerServer.all.order(name: :asc).includes(:hetzner_vswitch)

    render :index
  end
end
