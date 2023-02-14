require "resolv"

class Server < ApplicationRecord
  belongs_to :config, optional: true

  validates_inclusion_of :state, in: %w[pending configured]

  with_options unless: :pending? do
    validates_presence_of :hostname
    validate :validate_hostname_format
    validates_presence_of :private_ip
    validate :validate_private_ip_format
    validates_presence_of :config
  end

  def generate_config
    raise "can't generate config before assigning a config" unless config
    raise "can't generate config before assigning hostname" unless hostname
    raise "can't generate config before assigning private_ip" unless private_ip

    config.config.gsub("${hostname}", hostname).gsub("${private_ip}", private_ip)
  end

  def pending?
    state == "pending"
  end

  def configured?
    state == "configured"
  end

  private

  def validate_hostname_format
    return if hostname.blank?

    unless valid_hostname_format?
      errors.add(:hostname, "must contain only lowercase ASCII and dash and must end with -<number>")
    end
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

  def valid_hostname_format?
    hostname[/[a-z-]+-\d+$/]
  end
end
