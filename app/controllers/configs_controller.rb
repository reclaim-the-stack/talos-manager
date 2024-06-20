class ConfigsController < ApplicationController
  skip_before_action :require_authentication, only: :show

  def index
    @configs = Config.all
  end

  def show
    ip = request.remote_ip

    server = Server.find_by_ip!(ip)

    if server.machine_config
      server.configure!
      headers["Content-Type"] = "text/yaml"
      render plain: server.machine_config.generate_config
    else
      server.request_configuration!
      render plain: "No configuration found for server with IP #{server.ip}", status: 420
    end
  end

  def new
    @config = Config.new(
      kubernetes_version: "1.30.1",
      install_image: "ghcr.io/siderolabs/installer:v1.6.6",
      kubespan: true,
    )
  end

  def edit
    @config = Config.find(params[:id])
  end

  def create
    @config = Config.new(config_params)

    if @config.save
      redirect_to configs_path, notice: "Config #{@config.name} successfully created!"
    else
      render :new, status: 422
    end
  end

  def update
    @config = Config.find(params[:id])

    if @config.update(config_params)
      redirect_to configs_path, notice: "Config #{@config.name} successfully updated!"
    else
      render :edit, status: 422
    end
  end

  def destroy
    config = Config.find(params[:id])

    if config.machine_configs.any?
      redirect_to configs_path, alert: "Can't delete #{config.name} because of existing server associations."
    else
      config.destroy!

      redirect_to configs_path, notice: "Config #{config.name} successfully deleted!"
    end
  end

  private

  def config_params
    params.require(:config).permit(
      :name,
      :config,
      :install_image,
      :kubernetes_version,
      :kubespan,
      :patch,
      :patch_control_plane,
      :patch_worker,
    )
  end
end
