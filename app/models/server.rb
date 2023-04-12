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

  # Implement #sync_with_provider in subclasses of Server
  after_save :sync_with_provider, if: :sync

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
    nvme = session.exec!("ls /dev/nvme0n1 && echo 'has-nvme'").chomp.ends_with? "has-nvme"
    install_disk = nvme ? "/dev/nvme0n1" : "/dev/sda"
    partition = nvme ? "p3" : "3"

    ssh_exec_with_log! session, "wget #{TALOS_IMAGE_URL} --quiet -O - | tar xvfzO - | dd of=#{install_disk} status=progress"
    ssh_exec_with_log! session, "sync"

    # assuming that p3 is the BOOT partition, can make sure with `gdisk /dev/nvme0n1` and `s` command
    ssh_exec_with_log! session, "mount #{install_disk}#{partition} /mnt"
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

  def rescue
    raise "#rescue is not implemented for #{self.class.name}"
  end

  private

  def sync_with_provider
    raise "#sync_with_provider is not implemented for #{self.class.name}"
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
