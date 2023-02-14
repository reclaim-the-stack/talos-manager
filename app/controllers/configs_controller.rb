class ConfigsController < ApplicationController
  def index
    @configs = Config.all
  end

  def new
    @config = Config.new
  end

  def create
    config_params = params.require(:config).permit(:name, :config)

    @config = Config.new(config_params)

    if @config.save
      redirect_to configs_path
    else
      render :new, status: 422
    end
  end

  def edit
    @config = Config.find(params[:id])
  end

  def update
    @config = Config.find(params[:id])

    config_params = params.require(:config).permit(:name, :config)

    if @config.update(config_params)
      redirect_to configs_path
    else
      render :edit, status: 422
    end
  end

  def show
    uuid = params[:uuid]
    public_ip = request.remote_ip
    # values = params.require(:values).split("__")
    # raise "unexpected params: #{params}" unless values.length == 4

    # hostname, mac_address, smbios_serial, smbios_uuid = values

    server_params = {
      # hostname: hostname,
      # mac_address: mac_address,
      # smbios_serial: smbios_serial,
      smbios_uuid: uuid,
      public_ip: public_ip,
    }

    server = Server.find_by_public_ip(public_ip) || Server.create!(server_params)

    if server.configured?
      headers["Content-Type"] = "text/yaml"
      render plain: server.generate_config
    else
      sleep 10

      attempt = params[:attempt] || 0
      redirect_to get_config_path(uuid: params[:uuid], attempt: attempt.to_i + 1)
    end
  end
end
