class MachineConfigsController < ApplicationController
  def new
    @hetzner_server = HetznerServer.find(params.require(:hetzner_server_id))
    @machine_config = MachineConfig.new(
      hetzner_server: @hetzner_server,
      hostname: @hetzner_server.name,
      private_ip: default_private_ip(@hetzner_server.name),
    )
  end

  def create
    machine_config_params = params.require(:machine_config).permit(
      :config_id,
      :hetzner_server_id,
      :hostname,
      :private_ip,
      :already_configured,
    )
    @machine_config = MachineConfig.new(machine_config_params)
    @hetzner_server = @machine_config.hetzner_server

    if @machine_config.save
      redirect_to hetzner_servers_path, notice: "#{@hetzner_server.name} successfully configured!"
    else
      render :new, status: 422
    end
  end

  def destroy
    MachineConfig.find(params[:id]).destroy

    redirect_to hetzner_servers_path
  end

  private

  def default_private_ip(name)
    ip = "10.0."
    ip <<
      case name
      when /control-plane/ then "0"
      when /worker/ then "1"
      when /database/ then "2"
      when /standby/ then "7"
      else "x"
      end
    ip << "."
    ip << (name[/\d+$/] || "x")
  end
end
