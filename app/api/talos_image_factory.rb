# frozen_string_literal: true

# API docs: https://github.com/siderolabs/image-factory?tab=readme-ov-file#http-frontend-api

module TalosImageFactory
  HttpError = Class.new(StandardError)

  BASE_URL = "https://factory.talos.dev"

  def self.available_versions
    response = Typhoeus.get("#{BASE_URL}/versions")

    raise HttpError, "#{response.code}, #{response.body}" unless response.success?

    JSON.parse(response.body)
  end

  def self.schematic_cmdline(schematic_id)
    version = TalosImageFactorySetting.sole.version
    response = Typhoeus.get("#{BASE_URL}/image/#{schematic_id}/#{version}/cmdline-metal-amd64")

    return nil if response.code == 404

    raise HttpError, "#{response.code}, #{response.body}" unless response.success?

    response.body
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