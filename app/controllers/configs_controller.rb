class ConfigsController < ApplicationController
  skip_before_action :require_authentication, only: :show

  def index
    @configs = Config.all
  end

  def new
    @config = Config.new(
      kubernetes_version: "1.29.2",
      install_image: "ghcr.io/siderolabs/installer:v1.6.6",
      kubespan: true,
    )
  end

  def create
    @config = Config.new(config_params)

    if @config.save
      redirect_to configs_path, notice: "Config #{@config.name} successfully created!"
    else
      render :new, status: 422
    end
  end

  def edit
    @config = Config.find(params[:id])
  end

  def update
    @config = Config.find(params[:id])

    if @config.update(config_params)
      redirect_to configs_path, notice: "Config #{@config.name} successfully updated!"
    else
      render :edit, status: 422
    end
  end

  def show
    uuid = params[:uuid]
    ip = request.remote_ip

    server = Server.find_by_ip!(ip)

    server.update!(uuid: uuid) if uuid != server.uuid

    if server.machine_config
      # Using 1.second.ago seems silly but is required to show the correct status in the UI at the moment
      server.update!(last_request_for_configuration_at: 1.second.ago, last_configured_at: Time.now)
      headers["Content-Type"] = "text/yaml"
      render plain: server.machine_config.generate_config
    else
      server.update!(last_configured_at: nil, last_request_for_configuration_at: Time.now)

      sleep 15

      attempt = params[:attempt] || 0
      redirect_to get_config_path(uuid: params[:uuid], attempt: attempt.to_i + 1)
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
