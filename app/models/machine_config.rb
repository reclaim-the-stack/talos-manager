# Represents an application of Config on a Server, including private_ip and disk selection

require "open3"
require "resolv"

class MachineConfig < ApplicationRecord
  class InvalidConfigError < StandardError
    attr_reader :output

    def initialize(message, output)
      super message
      @output = output
    end
  end

  belongs_to :config
  belongs_to :server

  attribute :already_configured, :boolean # set to true to simulate the server already being configured

  validates_presence_of :hostname
  validate :validate_hostname_format
  validates_presence_of :private_ip
  validate :validate_private_ip_format
  validates_presence_of :install_disk
  validate :validate_ephemeral_disk_identifier_format

  after_create :set_configured, if: :already_configured

  def generate_config(output_type: server.talos_type)
    raise "can't generate config before assigning hostname" if hostname.blank?
    raise "can't generate config before assigning private_ip" if private_ip.blank?

    # Prefer the running kubernetes version over the configured one since bootstrapping
    # outdated versions can lead to issues.
    running_or_configured_kubernetes_version =
      # Avoid infinite recursion since talosconfig is used to determine the running kubernetes version
      if output_type == "talosconfig"
        config.kubernetes_version
      else
        server.cluster.running_kubernetes_version || config.kubernetes_version
      end

    # The machine config format depends on the Talos version, eg. newer versions of talosctl generate
    # multi-document configs which older versions of Talos won't accept. Hence we explicitly generate
    # configs for the default Talos version rather than for the version of the installed talosctl.
    talos_version = TalosImageFactorySetting.singleton.version

    secrets_file = "#{Dir.tmpdir}/secrets-#{SecureRandom.hex}"
    File.write(secrets_file, server.cluster.secrets)

    patches = [
      ["--config-patch", replace_substitution_variables(config.patch.to_s)],
      ["--config-patch", talos_manager_patch(talos_version)],
      ["--config-patch-control-plane", replace_substitution_variables(config.patch_control_plane.to_s)],
      ["--config-patch-worker", replace_substitution_variables(config.patch_worker.to_s)],
    ]
    # talosctl treats empty patches as JSON6902 patches which aren't supported for multi-document configs
    patches.reject! { |_flag, patch| empty_patch?(patch) }

    patch_files = patches.map do |flag, patch|
      patch_file = "#{Dir.tmpdir}/patch-#{SecureRandom.hex}"
      File.write(patch_file, patch)
      [flag, patch_file]
    end

    command = %(
      talosctl gen config \
        --talos-version #{talos_version} \
        --install-disk #{install_disk} \
        --install-image #{config.install_image} \
        --kubernetes-version #{running_or_configured_kubernetes_version} \
        #{patch_files.map { |flag, patch_file| "#{flag} @#{patch_file}" }.join(' ')} \
        --output-types #{output_type} \
        --with-secrets #{secrets_file} \
        --with-docs=false \
        --with-examples=false \
        #{'--with-kubespan' if config.kubespan?} \
        -o - \
        #{server.cluster.name} \
        #{server.cluster.endpoint}
    )

    stdout, stderr, status = Open3.capture3(command)
    unless status.success?
      message = "Failed to generate talos configuration.\nCommand:#{command}\nOutput: #{stderr}"
      raise InvalidConfigError.new(message, stderr)
    end

    # Machine configs for Talos 1.12+ consist of multiple YAML documents
    documents = YAML.safe_load_stream(stdout)

    # Initially talosconfig is generated with an endpoint of 127.0.0.1 and no nodes.
    # Hence we add the first control plane IP as both enpoint and node.
    if output_type == "talosconfig"
      talosconfig = documents.first
      context_name = talosconfig.fetch("context")
      context = talosconfig.fetch("contexts").fetch(context_name)
      context["endpoints"] = [server.ip]
      context["nodes"] = [server.ip]
    end

    # NOTE: This also gives us consistent 2 space indentation
    documents.map(&:to_yaml).join
  ensure
    FileUtils.rm_f(secrets_file) if secrets_file
    patch_files&.each { FileUtils.rm_f(it.last) }
  end

  # The hostname is always the server name since Talos uses the hostname as the name of the cluster
  # member and Kubernetes node.
  def hostname
    server&.name
  end

  private

  def empty_patch?(patch)
    YAML.safe_load_stream(patch).compact.empty?
  rescue Psych::Exception
    false # leave it to talosctl to report the error
  end

  # Config documents managed by Talos Manager, applied on top of the user supplied config patches
  def talos_manager_patch(talos_version)
    documents = [hostname_patch(talos_version)]
    documents << ephemeral_volume_config if ephemeral_disk_identifier.present?
    documents.map(&:to_yaml).join
  end

  # Talos 1.12 deprecated machine.network.hostname in favour of the HostnameConfig document
  def hostname_patch(talos_version)
    if Gem::Version.new(talos_version.delete_prefix("v")) >= Gem::Version.new("1.12")
      {
        "apiVersion" => "v1alpha1",
        "kind" => "HostnameConfig",
        "auto" => "off", # gen config defaults to auto: stable which conflicts with a static hostname
        "hostname" => hostname,
      }
    else
      { "machine" => { "network" => { "hostname" => hostname } } }
    end
  end

  def ephemeral_volume_config
    # id_type will be "wwid" for regular disks or "uuid" for raid arrays
    id_type, id = ephemeral_disk_identifier.split(":", 2)

    # https://www.talos.dev/v1.10/talos-guides/configuration/disk-management/#disk-selector
    disk_selector_cel =
      if id_type == "wwid"
        "disk.wwid == '#{id}'"
      elsif id_type == "uuid"
        # Talos takes the UUID hex and puts colons every 8 characters
        # 1a462672-bd83-888c-df8f-a57e6b38f998 -> 1a462672:bd83888c:df8fa57e:6b38f998
        uuid_talos_style = id.delete("-").chars.each_slice(8).map(&:join).join(":")
        "'/dev/disk/by-id/md-uuid-#{uuid_talos_style}' in disk.symlinks"
      end

    {
      "apiVersion" => "v1alpha1",
      "kind" => "VolumeConfig",
      "name" => "EPHEMERAL",
      "provisioning" => {
        "diskSelector" => { "match" => disk_selector_cel },
        "minSize" => "10GB",
        "grow" => true,
      },
    }
  end

  def replace_substitution_variables(patch)
    patch
      .gsub("${hostname}", hostname)
      .gsub("${private_ip}", private_ip)
      .gsub("${public_ip}", server.ip)
      .gsub("${vlan}", server.cluster.hetzner_vswitch&.vlan.to_s)
      .gsub("${bootstrap_disk_wwid}", server.bootstrap_disk_wwid.to_s)
  end

  def validate_hostname_format
    return if hostname.blank?

    unless valid_hostname_format?
      errors.add(
        :hostname,
        "must contain only lowercase ASCII and dash and must end with -<number> (rename the server to change it)",
      )
    end
  end

  def valid_hostname_format?
    hostname.present? && hostname[/[a-z-]+-\d+$/]
  end

  def validate_private_ip_format
    return if private_ip.blank?

    unless private_ip[Resolv::IPv4::Regex] && private_ip.start_with?("10.0.")
      errors.add(:private_ip, "must be a valid IPv4 address and begin with 10.0.")
      return
    end

    if valid_hostname_format?
      hostname_number = hostname[/\d+$/].to_i
      private_ip_number = private_ip[/\d+$/].to_i

      unless hostname_number == private_ip_number
        errors.add(
          :private_ip,
          "last octet must match the hostname number (expected '#{hostname_number}', got '#{private_ip_number}')",
        )
      end
    end
  end

  def validate_ephemeral_disk_identifier_format
    return if ephemeral_disk_identifier.blank?

    unless ephemeral_disk_identifier.match?(/^(wwid|uuid):.+$/)
      errors.add(:ephemeral_disk_identifier, "must be in the format 'wwid:<wwid>' or 'uuid:<uuid>'")
    end
  end

  def set_configured
    server.update!(
      last_configured_at: Time.now,
      last_request_for_configuration_at: Time.at(0),
      label_and_taint_job_completed_at: Time.at(0),
    )
  end
end
