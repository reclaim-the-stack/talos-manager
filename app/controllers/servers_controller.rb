# frozen_string_literal: true

class ServersController < ApplicationController
  def index
    @servers = Server.all
      .includes(:config, :cluster)
      .order(cluster_id: :asc, name: :asc)
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
        .order(cluster_id: :asc, name: :asc)
      redirect_to servers_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def prepare_bootstrap
    @server = Server.find(params[:id])
  end

  def bootstrap
    server = Server.find(params[:id])

    talos_version = params.expect(:talos_version)
    talos_image_factory_schematic_id = params[:talos_image_factory_schematic_id]
    bootstrap_disk_wwid = params.expect(:bootstrap_disk_wwid)
    bootstrap_disk_name = server.lsblk.fetch("blockdevices").find { it.fetch("wwn") == bootstrap_disk_wwid }.fetch("name")
    wipe_disk = params.expect(:wipe_bootstrap_disk) == "1"

    # pretend it's not accessible while bootstrapping to hide bootstrap button
    server.update!(
      accessible: false,
      bootstrap_disk_wwid:,
      bootstrap_disk: "/dev/#{bootstrap_disk_name}",
      label_and_taint_job_completed_at: nil,
      last_configured_at: nil,
      last_request_for_configuration_at: nil,
      talos_image_factory_schematic_id:,
    )

    ServerBootstrapJob.perform_later(server.id, talos_version:, wipe_disk:)

    redirect_to servers_path, notice: "Server #{server.name} is being bootstrapped"
  end

  def rescue
    server = Server.find(params[:id])

    server.rescue

    redirect_to servers_path, notice: "Server #{server.name} is rebooting in rescue mode"
  end

  def reset
    server = Server.find(params[:id])

    if server.reset
      redirect_to servers_path, notice: "Server #{server.name} is being reset"
    else
      redirect_to servers_path, alert: "Failed to execute talosctl reset for #{server.name}"
    end
  rescue Cluster::NoControlPlaneError
    redirect_to servers_path, alert: "Can't reset server without a cluster control plane server configured!"
  end

  def sync
    HetznerRobot.sync_to_activerecord
    HetznerCloud.sync_to_activerecord

    # Set server accessible status based on SSH connectability
    threads = Server.all.map do |server|
      Thread.new do
        server.bootstrappable?
        server
      end
    end

    accessible_servers, non_accessible_servers = threads.map(&:value).partition(&:bootstrappable?)

    # Update accessible servers with their metadata using a single UPDATE query
    if accessible_servers.any?
      connection = Server.connection

      bootstrap_metadata_values = accessible_servers.map do |server|
        id = server.id
        uuid = server.bootstrap_metadata.fetch(:uuid)
        lsblk = server.bootstrap_metadata.fetch(:lsblk).to_json

        "(#{id}, #{Server.connection.quote(uuid)}, #{Server.connection.quote(lsblk)}::jsonb)"
      end.join(", ")

      sql = <<~SQL
        UPDATE servers SET
          accessible = true,
          uuid = bootstrap_metadata_values.uuid,
          lsblk = bootstrap_metadata_values.lsblk
        FROM (VALUES #{bootstrap_metadata_values}) AS bootstrap_metadata_values(id, uuid, lsblk)
        WHERE servers.id = bootstrap_metadata_values.id
      SQL

      connection.execute(sql)
    end

    Server.where(id: non_accessible_servers.map(&:id)).update!(accessible: false)

    redirect_to servers_path, notice: "Synced servers"
  end

  def reboot_command
    @server = Server.find(params[:id])
  end

  def upgrade_command
    @server = Server.find(params[:id])
  end
end
