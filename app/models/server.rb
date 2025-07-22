class Server < ApplicationRecord
  belongs_to :cluster, optional: true
  belongs_to :api_key

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

  def talos_type
    name.include?("control-plane") ? "controlplane" : "worker"
  end

  # Implement #bootstrappable? in subclasses of Server. Eg. for Hetzner servers this is
  # true when servers are in rescue mode and SSH is accessible.
  def bootstrappable?
    raise "#bootstrappable? is not implemented for #{self.class.name}"
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
  def bootstrap!
    raise "ERROR: Can't bootstrap without a HOST configured" unless HOST

    session = Net::SSH.start(ip, "root", key_data: [ENV.fetch("SSH_PRIVATE_KEY")])
    uuid = session.exec! "dmidecode -s system-uuid".chomp
    if uuid.include? "-000000000000"
      system_data = session.exec! "dmidecode -t system"
      raise "Invalid SMBIOS UUID, send this output to Hetzner support: #{system_data}"
    end

    talos_image_url = TalosImageFactorySetting.sole.bootstrap_image_url(architecture:)
    blockdevices = JSON.parse(session.exec!("lsblk --output NAME,TYPE,SIZE,UUID,MODEL,WWN --bytes --json")).fetch("blockdevices")
    disks = blockdevices.select { it.fetch("type") == "disk" }

    # Exclude disks with children (partitions or RAID devices)
    noneligble, eligble = disks.partition { |disk| disk.key?("children") }

    Rails.logger.info "Ignoring non-eligible disks: #{noneligble.map { it.fetch('name') }.join(', ')}"
    raise "No eligible disks found for bootstrapping" if eligble.empty?

    Rails.logger.info "Eligible disks for bootstrapping: #{eligble.map { it.fetch('name') }.join(', ')}"

    eligble.sort_by! { it.fetch("name") }
    first_nvme = eligble.find { it.fetch("name").start_with?("nvme") }
    bootstrap_disk_data = first_nvme || eligble.first
    bootstrap_disk = "/dev/#{bootstrap_disk_data.fetch('name')}"
    bootstrap_disk_wwid = bootstrap_disk_data.fetch("wwn")

    update!(bootstrap_disk:, bootstrap_disk_wwid:, uuid:)

    Rails.logger.info "Bootstrapping #{ip} with talos image #{talos_image_url} on #{bootstrap_disk}"
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
      update!(last_configured_at: nil, last_request_for_configuration_at: nil)
    end
    success
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
