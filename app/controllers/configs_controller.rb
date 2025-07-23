class ConfigsController < ApplicationController
  skip_before_action :require_authentication, only: :show

  def index
    @configs = Config.all
  end

  def show
    ip = request.remote_ip
    server = Server.find_by_ip!(ip)

    if server.machine_config
      # Render config before updating in case it would fail for whatever reason
      config = server.machine_config.generate_config

      labeling_job_maybe_already_running = server.last_configured_at && server.last_configured_at > 10.minutes.ago

      # Using 1.second.ago seems silly but is required to show the correct status in the UI at the moment
      server.update!(
        last_request_for_configuration_at: 1.second.ago,
        last_configured_at: Time.now,
        # Don't touch this attribute in case a labeling job could be running to avoid hypothetical race condition
        label_and_taint_job_completed_at: labeling_job_maybe_already_running ? server.label_and_taint_job_completed_at : nil,
      )

      # We have to be cautious about scheduling this job since the requesting server may be
      # rejecting the configuration we're returning. If this is the case the requesting server
      # will keep on hitting this endpoint until it gets a configuration that it accepts.
      LabelAndTaintJob.perform_later(server.id) unless labeling_job_maybe_already_running

      headers["Content-Type"] = "text/yaml"
      render plain: config
    else
      server.update!(
        last_configured_at: nil,
        last_request_for_configuration_at: Time.now,
        label_and_taint_job_completed_at: nil,
      )
      render plain: "No configuration found for server with IP #{server.ip}", status: 420
    end
  end

  def new
    @config = Config.new(
      kubernetes_version: "1.30.1",
      install_image: "ghcr.io/siderolabs/installer:v1.10.4",
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
