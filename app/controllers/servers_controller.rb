class ServersController < ApplicationController
  def index
    @servers = Server.all.includes(:config)
  end

  def update
    @server = Server.find(params[:id])

    server_params = params.require(:server).permit(:hostname, :private_ip, :config_id)

    unless @server.update(server_params.merge(state: "configured"))
      render :edit, status: 422
    end
  end
end
