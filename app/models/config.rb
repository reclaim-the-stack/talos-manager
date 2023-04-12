class Config < ApplicationRecord
  validates_uniqueness_of :name
  validates_presence_of :install_disk
  validates_presence_of :install_image
  validates_presence_of :kubernetes_version
  validate :validate_talos_config

  has_many :machine_configs

  private

  def validate_talos_config
    begin
      YAML.safe_load(patch)
    rescue Psych::SyntaxError => e
      errors.add(:patch, e.message)
      return
    end

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
    dummy_config = MachineConfig.new(config: self, server: dummy_server, hostname: "worker-1", private_ip: "10.0.1.1")
    talos_validation =
      Tempfile.create("talos-config.yaml") do |file|
        file.write(dummy_config.generate_config)
        file.flush
        `talosctl validate -m metal --strict -c #{file.path} 2>&1`
      end

    errors.add(:config, talos_validation) unless talos_validation.include?("is valid")
  end
end
