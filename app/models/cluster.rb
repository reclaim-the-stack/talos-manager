require "open3"

class Cluster < ApplicationRecord
  NoControlPlaneError = Class.new(StandardError)

  has_many :servers, dependent: :nullify
  belongs_to :hetzner_vswitch, optional: true

  encrypts :secrets

  before_validation :generate_default_secret, on: :create

  validates_presence_of :name
  validates_presence_of :endpoint
  validates_presence_of :secrets
  validate :validate_secrets_yaml
  validate :validate_endpoint_url

  def talosconfig
    first_control_plane = servers
      .where.associated(:machine_config)
      .where("name ILIKE '%control-plane%'")
      .order(name: :asc)
      .first

    if first_control_plane
      first_control_plane.machine_config.generate_config(output_type: "talosconfig")
    else
      raise NoControlPlaneError
    end
  end

  private

  def generate_default_secret
    return if secrets.present?

    random_tmp_file = "#{Dir.tmpdir}/#{SecureRandom.hex}"
    if system "talosctl gen secrets -o #{random_tmp_file}"
      self.secrets = File.read(random_tmp_file)
    else
      raise "Failed to generate default secrets"
    end
  ensure
    FileUtils.rm_f(random_tmp_file) if random_tmp_file
  end

  # Caution: Turns out talosctl gen config doesn't really validate secrets YAML all that much
  # and gladly replaces missing keys with null values so take this validation with a grain of salt.
  def validate_secrets_yaml
    return if secrets.blank?

    random_tmp_file = "#{Dir.tmpdir}/#{SecureRandom.hex}"
    File.write(random_tmp_file, secrets)

    cmd = "talosctl gen config -o - --output-types controlplane --with-secrets #{random_tmp_file} test https://host:6443"

    Open3.popen3(cmd) do |_stdin, _stdout, stderr, wait_thread|
      break if wait_thread.value.success?

      errors.add(:secrets, stderr.read)
    end
  ensure
    FileUtils.rm_f(random_tmp_file)
  end

  def validate_endpoint_url
    return if endpoint.blank?

    errors.add(:endpoint, "must start with https://") unless endpoint.start_with?("https://")
    errors.add(:endpoint, "must end with an explicit port, eg. :6443") unless endpoint.match?(/:\d+$/)
    URI.parse(endpoint)
  rescue URI::InvalidURIError
    errors.add(:endpoint, "must be a valid URL")
  end
end
