class Server < ApplicationRecord
  TALOS_IMAGE_URL = "https://github.com/siderolabs/talos/releases/download/v1.3.7/metal-amd64.tar.gz".freeze

  belongs_to :cluster, optional: true

  has_one :machine_config
  has_one :config, through: :machine_config

  attr_accessor :sync # set to true to sync changed attributes to hetzner

  validates_uniqueness_of :name, allow_nil: true
  validates_presence_of :ip
  validates_presence_of :ipv6
  validates_presence_of :product
  validates_presence_of :data_center
  validates_presence_of :status

  after_save :sync_with_hetzner, if: :sync

  def talos_type
    name.include?("control-plane") ? "controlplane" : "worker"
  end

  def bootstrap!
    session = Net::SSH.start(ip, "root", key_data: [ENV.fetch("SSH_PRIVATE_KEY")])
    uuid = session.exec! "dmidecode -s system-uuid".chomp
    if uuid.include? "-000000000000"
      system_data = session.exec! "dmidecode -t system"
      raise "Invalid SMBIOS UUID, send this output to Hetzner support: #{system_data}"
    end

    host = ENV.fetch("HOST")
    install_disk =
      if session.exec!("ls /dev/nvme0n1 && echo 'has-nvme'").chomp == "has-nvme"
        "/dev/nvme0n1"
      else
        "/dev/sda"
      end

    ssh_exec_with_log! session, "wget #{TALOS_IMAGE_URL} --quiet -O - | tar xvfzO - | dd of=#{install_disk} status=progress"
    ssh_exec_with_log! session, "sync"

    # assuming that p3 is the BOOT partition, can make sure with `gdisk /dev/nvme0n1` and `s` command
    ssh_exec_with_log! session, "mount #{install_disk}p3 /mnt"
    ssh_exec_with_log! session, "sed -i 's/vmlinuz/vmlinuz talos.config=https:\\/\\/#{host}\\/config?uuid=${uuid}/' "\
                                "/mnt/grub/grub.cfg"
    ssh_exec_with_log! session, "umount /mnt"

    begin
      session.exec! "reboot"
    rescue IOError
      # rebooting implicitly closes the connection causing an IOError
    end
    session.shutdown!

    update!(accessible: false)
  end

  private

  def sync_with_hetzner
    if saved_change_to_name?
      Hetzner.update_server(id, server_name: name)
    end

    if saved_change_to_hetzner_vswitch_id?
      initial_vswitch_id, new_vswitch_id = saved_changes.fetch("hetzner_vswitch_id")

      # The server was connected to a vswitch and we need to disconnect it
      if initial_vswitch_id
        Hetzner.remove_server_from_vswitch(initial_vswitch_id, id)
      end

      if new_vswitch_id
        Hetzner.add_server_to_vswitch(new_vswitch_id, id)
      end
    end
  end

  def ssh_exec_with_log!(session, command)
    status = {}
    channel = session.exec(command, status: status)
    channel.on_data { |_channel, data| $stdout.print(data) }
    channel.on_extended_data { |_channel, data| $stderr.print(data) }
    channel.wait
    raise "failed to execute '#{command}' on #{session.host}" unless status.fetch(:exit_code) == 0
  end
end
