# frozen_string_literal: true

# API docs: https://github.com/siderolabs/image-factory?tab=readme-ov-file#http-frontend-api

module TalosImageFactory
  HttpError = Class.new(StandardError)

  BASE_URL = "https://factory.talos.dev"
  ARCHITECTURES = %w[amd64 arm64].freeze
  DEFAULT_VERSION = "v1.10.4"

  def self.available_versions
    response = Typhoeus.get("#{BASE_URL}/versions")

    raise HttpError, "#{response.code}, #{response.body}" unless response.success?

    JSON.parse(response.body)
  end

  def self.schematic_cmdline(schematic_id)
    response = Typhoeus.get("#{BASE_URL}/image/#{schematic_id}/#{DEFAULT_VERSION}/cmdline-metal-amd64")

    return nil if response.code == 404

    raise HttpError, "#{response.code}, #{response.body}" unless response.success?

    response.body
  end

  def self.image_url(
      architecture:,
      schematic_id: TalosImageFactorySetting.first&.schematic_id,
      version: DEFAULT_VERSION,
      platform: "metal"
    )
    raise ArgumentError, "Unsupported architecture: #{architecture}" unless ARCHITECTURES.include?(architecture)

    if architecture == "arm64" && ENV["TALOS_ARM64_IMAGE_URL"].present?
      return ENV["TALOS_ARM64_IMAGE_URL"]
    elsif architecture == "amd64" && ENV["TALOS_AMD64_IMAGE_URL"].present?
      return ENV["TALOS_AMD64_IMAGE_URL"]
    end

    schematic_id ||= create_schematic_with_talos_config.fetch("id")

    "#{BASE_URL}/image/#{schematic_id}/#{version}/#{platform}-#{architecture}.raw.zst"
  end

  def self.create_schematic_with_talos_config
    response = Typhoeus.post(
      "#{BASE_URL}/schematics",
      body: {
        customization: {
          extraKernelArgs: [
            "talos.config=https://#{ENV.fetch("HOST")}/config",
          ],
        },
      }.to_json,
    )

    raise HttpError, "#{response.code}, #{response.body}" unless response.success?

    JSON.parse(response.body)
  end
end