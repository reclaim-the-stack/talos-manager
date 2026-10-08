class Config < ApplicationRecord
  validates_uniqueness_of :name
  validates_presence_of :install_image
  validates_presence_of :kubernetes_version
  validate :validate_talos_config

  has_many :machine_configs

  private

  def validate_talos_config
    # NOTE: map before all? to report errors for every patch rather than stopping at the first invalid one
    return unless %i[patch patch_control_plane patch_worker].map { validate_patch(it) }.all?

    # Use `talosctl validate` to validate the config.
    #
    # Valid output example:
    # /var/folders/wc/f9vq4v_d7879y8t0rr39k5_40000gn/T/talos-config.yaml20230214-51302-cn67md is valid for metal mode
    #
    # Invalid output example:
    # 3 errors occurred:
    #   * cluster instructions are required
    #   * install instructions are required in "metal" mode
    #   * warning: use "worker" instead of "" for machine type

    dummy_cluster = Cluster.new(
      name: "test",
      endpoint: "https://test.com:6443",
      hetzner_vswitch: HetznerVswitch.new(vlan: 4000),
    )
    dummy_cluster.validate # trigger the default secret generation callback
    dummy_server = Server.new(name: "control-plane-1", ip: "108.108.108.108", cluster: dummy_cluster)
    dummy_config = MachineConfig.new(config: self, server: dummy_server, private_ip: "10.0.0.1")
    tmp_config_file = "#{Dir.tmpdir}/#{SecureRandom.hex}"
    File.write(tmp_config_file, dummy_config.generate_config)
    talos_validation = `talosctl validate -m metal --strict -c #{tmp_config_file} 2>&1`

    errors.add(:config, talos_validation) unless talos_validation.include?("is valid")
  # Can be triggered by dummy_config.generate_config
  rescue MachineConfig::InvalidConfigError => e
    errors.add(:config, e.output)
  end

  # Returns true if the patch is valid YAML which doesn't attempt to set the hostname
  def validate_patch(attribute)
    documents = YAML.safe_load_stream(public_send(attribute).to_s)

    if documents.any? { sets_hostname?(it) }
      errors.add(attribute, "must not set the hostname since Talos Manager sets it to the name of the server")
      return false
    end

    true
  rescue Psych::Exception => e
    errors.add(attribute, e.message)
    false
  end

  def sets_hostname?(document)
    return false unless document.is_a?(Hash)

    machine = document["machine"]
    network = machine["network"] if machine.is_a?(Hash)

    document["kind"] == "HostnameConfig" || (network.is_a?(Hash) && network.key?("hostname"))
  end
end
