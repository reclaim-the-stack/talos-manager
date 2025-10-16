# frozen_string_literal: true

class Server < ApplicationRecord
  belongs_to :cluster, optional: true
  belongs_to :api_key
  belongs_to :talos_image_factory_schematic, optional: true

  has_one :machine_config, dependent: :destroy
  has_one :config, through: :machine_config

  attr_accessor :sync # set to true to sync changed attributes to hetzner

  # Only validate name if it changed to avoid UI editing issues in case the same name has been used
  # at Hetzner in which case the sync will bypass the validation and add duplicates to the database.
  validates_uniqueness_of :name, allow_nil: true, if: -> { name_changed? }
  validates_presence_of :ip
  validates_presence_of :ipv6
  validates_presence_of :product
  validates_presence_of :data_center
  validates_presence_of :status # running, initializing, starting, stopping, off, deleting migrating, rebuilding, unknown

  # Implement #sync_with_provider in subclasses of Server
  after_save :sync_with_provider, if: :sync

  after_update_commit lambda {
    if saved_change_to_name?
      broadcast_replace_to "servers", target: "SERVER-#{id}-NAME", partial: "servers/server_name", locals: { server: self }
    end
    if saved_change_to_last_configured_at? || saved_change_to_last_request_for_configuration_at?
      broadcast_replace_to "servers", target: "SERVER-#{id}-STATUS", partial: "servers/server_status", locals: { server: self }
    end
    if saved_change_to_name? ||
       saved_change_to_last_configured_at? ||
       saved_change_to_last_request_for_configuration_at? ||
       saved_change_to_accessible?
      broadcast_replace_to "servers", target: "SERVER-#{id}-MENU", partial: "servers/server_menu", locals: { server: self }
    end
  }

  # #bootstrap_metadata must be implemented in every subclasses of Server.
  # Should return a hash populated with:
  # {
  #   bootstrappable: <true/false> (eg. for Hetzner servers this is true if the server is in rescue mode),
  #   uuid: "<output from dmidecode -s system-uuid>",
  #   lsblk: { <JSON parsed output from lsblk --output NAME,TYPE,SIZE,UUID,MODEL,WWN --bytes --json> },
  # }
  def bootstrap_metadata
    raise "#bootstrap_metadata is not implemented for #{self.class.name}"
  end

  def bootstrappable?
    bootstrap_metadata.fetch(:bootstrappable)
  end

  # Convert SCSI NAA addresses to Talos readable WWIDs
  def bootstrap_disk_wwid=(value)
    if value&.start_with?("0x")
      super "naa.#{value.delete_prefix('0x').downcase}"
    else
      super
    end
  end

  def talos_type
    name.include?("control-plane") ? "controlplane" : "worker"
  end

  # NOTE: Doesn't necessarily imply that the server was successfully bootstrapped after config was sent
  def configured?
    last_configured_at && last_configured_at > last_request_for_configuration_at
  end

  # Equivalent of manually running the following via ssh:
  # TALOS_IMAGE_URL=https://factory.talos.dev/image/<schematic-id>/v1.10.5/metal-amd64.raw.zst
  # DEVICE=nvme0n1
  #
  # wget $TALOS_IMAGE_URL --quiet -O - | zstd -d | dd of=/dev/$DEVICE status=progress
  # sync
  # reboot
  def bootstrap!(talos_version:)
    key_data = [ENV.fetch("SSH_PRIVATE_KEY")]
    session = Net::SSH.start(ip, "root", key_data:, non_interactive: true, verify_host_key: :never, timeout: 2)
    talos_image_url = bootstrap_image_url(talos_version:)

    Rails.logger.info "Wiping disk #{bootstrap_disk} before bootstrapping"
    # NOTE: sfdisk --delete silently returns non-zero exit code if the disk is already empty with no options to ignore it
    ssh_exec_with_log! session, "sfdisk --delete #{bootstrap_disk} || echo 'ignoring non-zero exit code from sfdisk'"
    ssh_exec_with_log! session, "wipefs -a -f #{bootstrap_disk}"

    Rails.logger.info "Bootstrapping #{ip} with talos image #{talos_image_url} on #{bootstrap_disk} (may take a few minutes)"
    ssh_exec_with_log! session, "wget #{talos_image_url} --quiet -O - | zstd -d | dd of=#{bootstrap_disk} status=progress"
    ssh_exec_with_log! session, "sync"

    begin
      session.exec! "reboot"
    rescue IOError
      # rebooting implicitly closes the connection causing an IOError
    end
    session.shutdown!

    update!(accessible: false)
  end

  def talosctl
    raise "ERROR: Can't use talosctl without a cluster" unless cluster

    @talosctl ||= Talosctl.new(cluster.talosconfig)
  end

  def kubectl
    @kubectl ||= Kubectl.new(talosctl.kubeconfig)
  end

  def rescue
    raise "#rescue is not implemented for #{self.class.name}"
  end

  def reset
    talosconfig_path = "tmp/#{name}-talosconfig"
    File.write(talosconfig_path, cluster.talosconfig)
    members = `talosctl get members -o jsonpath={.spec.hostname} --talosconfig=#{talosconfig_path}`
    more_than_one_remaining = members.lines.length > 1
    command = "talosctl reset " \
              "--graceful=#{more_than_one_remaining} " \
              "--wait=false " \
              "--reboot " \
              "--system-labels-to-wipe STATE " \
              "--system-labels-to-wipe EPHEMERAL " \
              "--talosconfig=#{talosconfig_path} " \
              "-n #{ip}"
    Rails.logger.info "class=Server method=reset name='#{name}' command='#{command}'"
    if (success = system(command))
      machine_config&.destroy!
      update!(last_configured_at: nil, last_request_for_configuration_at: nil, label_and_taint_job_completed_at: nil)
    end
    success
  end

  def bootstrap_image_url(platform: "metal", talos_version: TalosImageFactorySetting.singleton.version)
    existing_schematic_id =
      talos_image_factory_schematic&.schematic_id ||
      TalosImageFactorySetting.singleton.talos_image_factory_schematic&.schematic_id
    schematic_id = existing_schematic_id || TalosImageFactory.create_schematic_with_talos_config.fetch("id")

    "#{TalosImageFactory::BASE_URL}/image/#{schematic_id}/#{talos_version}/#{platform}-#{architecture}.raw.zst"
  end

  def upgrade_image_url(platform: "metal", talos_version: TalosImageFactorySetting.singleton.version)
    existing_schematic_id =
      talos_image_factory_schematic&.schematic_id ||
      TalosImageFactorySetting.singleton.talos_image_factory_schematic&.schematic_id
    schematic_id = existing_schematic_id || TalosImageFactory.create_schematic_with_talos_config.fetch("id")

    "factory.talos.dev/#{platform}-installer/#{schematic_id}:#{talos_version}"
  end

  private

  def sync_with_provider
    raise "#sync_with_provider is not implemented for #{self.class.name}"
  end

  def ssh_exec_with_log!(session, command)
    status = {}
    channel = session.exec(command, status:)
    channel.on_data { |_channel, data| $stdout.print(data) }
    channel.on_extended_data { |_channel, data| $stderr.print(data) }
    channel.wait
    raise "failed to execute '#{command}' on #{session.host}" unless status.fetch(:exit_code) == 0
  end
end
