# frozen_string_literal: true

# API docs: https://github.com/siderolabs/image-factory?tab=readme-ov-file#http-frontend-api

module TalosImageFactory
  HttpError = Class.new(StandardError)

  BASE_URL = "https://factory.talos.dev"

  def self.available_versions
    Rails.cache.fetch("talos_image_factory/available_versions", expires_in: 1.hour) do
      response = Typhoeus.get("#{BASE_URL}/versions")

      raise HttpError, "#{response.code}, #{response.body}" unless response.success?

      @available_versions = JSON.parse(response.body)
    end
  end

  def self.schematic_cmdline(schematic_id)
    version = TalosImageFactorySetting.singleton.version
    response = Typhoeus.get("#{BASE_URL}/image/#{schematic_id}/#{version}/cmdline-metal-amd64")

    return nil if response.code == 404

    raise HttpError, "#{response.code}, #{response.body}" unless response.success?

    response.body
  end

  def self.create_schematic(params)
    response = Typhoeus.post("#{BASE_URL}/schematics", body: params.to_json)

    raise HttpError, "#{response.code}, #{response.body}" unless response.success?

    JSON.parse(response.body)
  end

  def self.create_schematic_with_talos_config
    create_schematic(
      customization: {
        extraKernelArgs: [
          "talos.config=https://#{ENV.fetch("HOST")}/config",
        ],
      },
    )
  end
end