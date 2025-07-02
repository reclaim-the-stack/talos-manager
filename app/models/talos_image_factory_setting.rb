# frozen_string_literal: true

# This is currently used as a singleton model that stores the Talos Image Factory settings.
# Could potentially be extended to support multiple settings records in the future.

class TalosImageFactorySetting < ApplicationRecord
  attribute :version, :string, default: "v1.10.4"

  validates_presence_of :version

  validate :validate_existing_version, if: -> { version.present? && version_changed? }
  validate :validate_schematic, if: -> { schematic_id.present? && schematic_id_changed? }

  private

  # - Version must match an available Talos version
  def validate_existing_version
    available_versions = TalosImageFactory.available_versions

    return if available_versions.include?(version)

    errors.add(:version, "is not a valid Talos version. Available versions: #{available_versions.to_sentence}")
  rescue TalosImageFactory::HttpError => e
    errors.add(:base, "Failed to fetch available Talos versions: #{e.message}")
  end

  # - Schematic must exist
  # - Schematic must contain a talos.config= kernel command line argument
  # - talos.config= must point to https://<HOST>/config
  def validate_schematic
    cmdline = TalosImageFactory.schematic_cmdline(schematic_id)

    if cmdline.nil?
      errors.add(:schematic_id, "could not find this schematic ID in the Talos Image Factory")
      return
    end

    expected_url = "https://#{ENV.fetch('HOST')}/config"
    talos_config_match = cmdline.match(/talos\.config=(https?:\/\/[^\s]+)/)

    if talos_config_match.nil?
      errors.add(:schematic_id, "must contain a talos.config=#{expected_url} kernel command line argument")
      return
    end

    talos_config_url = talos_config_match[1]
    unless talos_config_url.start_with?("")
      errors.add(:schematic_id, "had a talos.config= kernel argument pointing to #{talos_config_url}, but it must point to #{expected_url}")
    end
  rescue TalosImageFactory::HttpError => e
    errors.add(:base, "Failed to validate schematic ID: #{e.message}")
  end
end
