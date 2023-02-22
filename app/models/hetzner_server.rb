class HetznerServer < ApplicationRecord
  TALOS_ISO_URL = "https://drive.google.com/uc?id=1cUFh6YjmmhsLCuXg8PIhZxsKCkp4upu5&export=download".freeze

  belongs_to :hetzner_vswitch, optional: true
  has_one :machine_config
  has_one :config, through: :machine_config

  attr_accessor :sync # set to true to sync changed attributes to hetzner

  validates_presence_of :ip
  validates_presence_of :ipv6
  validates_presence_of :product
  validates_presence_of :data_center
  validates_presence_of :status

  after_save :sync_with_hetzner, if: :sync

  def bootstrap!
    session = Net::SSH.start(ip, "root", key_data: [ENV.fetch("SSH_PRIVATE_KEY")])
    uuid = session.exec! "dmidecode -s system-uuid"
    if uuid.include? "-000000000000"
      system_data = session.exec! "dmidecode -t system"
      raise "Invalid SMBIOS UUID, send this output to Hetzner support: #{system_data}"
    end

    ssh_exec_with_log! session, "wget '#{TALOS_ISO_URL}' -O talos.iso --no-verbose"
    ssh_exec_with_log! session, "dd if=talos.iso of=/dev/sda status=progress"

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
