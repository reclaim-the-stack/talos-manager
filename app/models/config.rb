class Config < ApplicationRecord
  validates_uniqueness_of :name
  validate :validate_talos_config

  def self.as_options
    all.map { |config| config.values_at(:name, :id) }
  end

  private

  def validate_talos_config
    begin
      YAML.safe_load(config)
    rescue Psych::SyntaxError => e
      errors.add(:config, e.message)
      return
    end

    unless config.include?("${hostname}") && config.include?("${private_ip}")
      errors.add(:config, "must include substitution variables ${hostname} and ${private_ip}")
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

    dummy_server = Server.new(config: self, hostname: "worker-1", private_ip: "10.0.1.1")
    talos_validation =
      Tempfile.create("talos-config.yaml") do |file|
        file.write(dummy_server.generate_config)
        file.flush
        `talosctl validate -m metal --strict -c #{file.path} 2>&1`
      end

    errors.add(:config, talos_validation) unless talos_validation.include?("is valid")
  end
end
