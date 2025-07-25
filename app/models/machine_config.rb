# Represents an application of Config on a Server, including hostname and private_ip

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

  after_create :set_configured, if: :already_configured

  def generate_config(output_type: server.talos_type)
    raise "can't generate config before assigning hostname" if hostname.blank?
    raise "can't generate config before assigning private_ip" if private_ip.blank?

    secrets_file = "#{Dir.tmpdir}/secrets-#{SecureRandom.hex}"
    File.write(secrets_file, server.cluster.secrets)

    patch_file = "#{Dir.tmpdir}/patch-#{SecureRandom.hex}"
    File.write(patch_file, replace_substitution_variables(config.patch))

    patch_control_plane_file = "#{Dir.tmpdir}/patch-control-plane-#{SecureRandom.hex}"
    File.write(patch_control_plane_file, replace_substitution_variables(config.patch_control_plane || ""))

    patch_worker_file = "#{Dir.tmpdir}/patch-worker-#{SecureRandom.hex}"
    File.write(patch_worker_file, replace_substitution_variables(config.patch_worker || ""))

    # Prefer the running kubernetes version over the configured one since bootstrapping
    # outdated versions can lead to issues.
    running_or_configured_kubernetes_version =
      # Avoid infinite recursion since talosconfig is used to determine the running kubernetes version
      if output_type == "talosconfig"
        config.kubernetes_version
      else
        server.cluster.running_kubernetes_version || config.kubernetes_version
      end

    command = %(
      talosctl gen config \
        --install-disk #{install_disk} \
        --install-image #{config.install_image} \
        --kubernetes-version #{running_or_configured_kubernetes_version} \
        --config-patch @#{patch_file} \
        --config-patch-control-plane @#{patch_control_plane_file} \
        --config-patch-worker @#{patch_worker_file} \
        --output-types #{output_type} \
        --with-secrets #{secrets_file} \
        --with-docs=false \
        --with-examples=false \
        #{'--with-kubespan' if config.kubespan?} \
        -o - \
        #{server.cluster.name} \
        #{server.cluster.endpoint}
    )

    config = Open3.popen3(command) do |_stdin, stdout, stderr, wait_thread|
      if wait_thread.value.success?
        stdout.read
      else
        output = stderr.read
        message = "Failed to generate talos configuration.\nCommand:#{command}\nOutput: #{output}"
        raise InvalidConfigError.new(message, output)
      end
    end

    File.delete(secrets_file)
    File.delete(patch_file)
    File.delete(patch_control_plane_file)
    File.delete(patch_worker_file)

    talosconfig = YAML.safe_load(config)

    # Initially talosconfig is generated with an endpoint of 127.0.0.1 and no nodes.
    # Hence we add the first control plane IP as both enpoint and node.
    if output_type == "talosconfig"
      context_name = talosconfig.fetch("context")
      context = talosconfig.fetch("contexts").fetch(context_name)
      context["endpoints"] = [server.ip]
      context["nodes"] = [server.ip]
    end

    # NOTE: This also gives us consistent 2 space indentation
    talosconfig.to_yaml.delete_prefix("---\n")
  end

  private

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
      errors.add(:hostname, "must contain only lowercase ASCII and dash and must end with -<number>")
    end
  end

  def valid_hostname_format?
    hostname[/[a-z-]+-\d+$/]
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

  def set_configured
    server.update!(
      last_configured_at: Time.now,
      last_request_for_configuration_at: Time.at(0),
      label_and_taint_job_completed_at: Time.at(0),
    )
  end
end
