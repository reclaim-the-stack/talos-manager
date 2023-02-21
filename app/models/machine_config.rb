# Represents an application of Config on a HetznerServer, including hostname and private_ip

require "resolv"

class MachineConfig < ApplicationRecord
  belongs_to :config
  belongs_to :hetzner_server

  validates_presence_of :hostname
  validate :validate_hostname_format
  validates_presence_of :private_ip
  validate :validate_private_ip_format

  def generate_config
    raise "can't generate config before assigning hostname" if hostname.blank?
    raise "can't generate config before assigning private_ip" if private_ip.blank?

    config.config
      .gsub("${hostname}", hostname)
      .gsub("${private_ip}", private_ip)
      .gsub("${public_ip}", hetzner_server.ip)
  end

  private

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
end
