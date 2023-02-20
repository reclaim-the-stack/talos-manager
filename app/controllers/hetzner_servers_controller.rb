class HetznerServersController < ApplicationController
  TALOS_ISO_URL = "https://drive.google.com/uc?id=1cUFh6YjmmhsLCuXg8PIhZxsKCkp4upu5&export=download".freeze

  def index
    @hetzner_servers = HetznerServer.all.order(hetzner_vswitch_id: :asc, name: :asc).includes(:hetzner_vswitch)
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

    Net::SSH.start(hetzner_server.ip, "root", key_data: [ENV.fetch("SSH_PRIVATE_KEY")]) do |session|
      ssh_exec_with_log! session, "wget '#{TALOS_ISO_URL}' -O talos.iso --no-verbose"
      ssh_exec_with_log! session, "dd if=talos.iso of=/dev/sda status=progress"
      session.exec "reboot"
    end

    hetzner_server.update!(accessible: false)

    head 204
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

  private

  def ssh_exec_with_log!(session, command)
    status = {}
    channel = session.exec(command, status: status)
    channel.on_data { |_channel, data| $stdout.print(data) }
    channel.on_extended_data { |_channel, data| $stderr.print(data) }
    channel.wait
    raise "failed to execute '#{command}' on #{session.host}" unless status.fetch(:exit_code) == 0
  end
end
