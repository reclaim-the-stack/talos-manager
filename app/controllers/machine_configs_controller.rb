class MachineConfigsController < ApplicationController
  def show
    machine_config = MachineConfig.find(params[:id])

    headers["Content-Type"] = "text/yaml"
    render plain: machine_config.generate_config
  end

  def new
    @server = Server.find(params.require(:server_id))
    @machine_config = MachineConfig.new(
      server: @server,
      hostname: @server.name,
      private_ip: default_private_ip(@server.name),
      install_disk: @server.bootstrap_disk || "/dev/sda",
    )
  end

  def create
    machine_config_params = params.require(:machine_config).permit(
      :config_id,
      :server_id,
      :hostname,
      :private_ip,
      :already_configured,
      :install_disk,
      :ephemeral_disk_identifier,
    )
    @machine_config = MachineConfig.new(machine_config_params)
    @server = @machine_config.server

    if @machine_config.save
      redirect_to servers_path, notice: "#{@server.name} successfully configured!"
    else
      render :new, status: 422
    end
  end

  def destroy
    MachineConfig.find(params[:id]).destroy

    redirect_to servers_path
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
