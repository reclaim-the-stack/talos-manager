require "open3"

class Cluster < ApplicationRecord
  has_many :servers, dependent: :nullify
  belongs_to :hetzner_vswitch, optional: true

  encrypts :secrets

  before_validation :generate_default_secret, on: :create

  validates_presence_of :name
  validates_presence_of :endpoint
  validates_presence_of :secrets
  validate :validate_secrets_yaml
  validate :validate_endpoint_url

  private

  def generate_default_secret
    return if secrets.present?

    self.secrets = Tempfile.create do |tempfile|
      `talosctl gen secrets -o #{tempfile.path}`
      tempfile.flush
      File.read(tempfile.path)
    end
  end

  # Caution: Turns out talosctl gen config doesn't really validate secrets YAML all that much
  # and gladly replaces missing keys with null values so take this validation with a grain of salt.
  def validate_secrets_yaml
    return if secrets.blank?

    Tempfile.create do |tempfile|
      tempfile.write(secrets)
      tempfile.flush

      cmd = "talosctl gen config -o - --output-types controlplane --with-secrets #{tempfile.path} test https://host:6443"

      Open3.popen3(cmd) do |_stdin, _stdout, stderr, wait_thread|
        break if wait_thread.value.success?

        errors.add(:secrets, stderr.read)
      end
    end
  end

  def validate_endpoint_url
    return if endpoint.blank?

    errors.add(:endpoint, "must start with https://") unless endpoint.start_with?("https://")
    errors.add(:endpoint, "must end with an explicit port, eg. :6443") unless endpoint.match?(/:\d+$/)
  rescue URI::InvalidURIError
    errors.add(:endpoint, "must be a valid URL")
  end
end
