class BackfillApiKeysFromEnv < ActiveRecord::Migration[7.2]
  def up
    add_reference :servers, :api_key, null: true, foreign_key: true

    if ENV["HETZNER_WEBSERVICE_USER"].present? && ENV["HETZNER_WEBSERVICE_PASSWORD"].present?
      api_key = ApiKey.new(
        provider: "hetzner_robot",
        name: ENV["HETZNER_WEBSERVICE_USER"],
        secret: ENV["HETZNER_WEBSERVICE_PASSWORD"],
      )

      if api_key.save
        HetznerRobot.sync_to_activerecord
      else
        puts "Failed to create Hetzner Robot API key: #{api_key.errors.full_messages.join(', ')}"
      end
    end

    if ENV["HETZNER_CLOUD_API_TOKEN"].present?
      api_key = ApiKey.new(
        provider: "hetzner_cloud",
        name: "Hetzner Cloud", # Assuming a default name for the cloud API key
        secret: ENV["HETZNER_CLOUD_API_TOKEN"],
      )

      if api_key.save
        HetznerCloud.sync_to_activerecord
      else
        puts "Failed to create Hetzner Cloud API key: #{api_key.errors.full_messages.join(', ')}"
      end
    end

    if Server.where(api_key_id: nil).exists?
      raise "Unexpected state: Some servers do not have an API key assigned. Please check your environment variables and ensure all servers are associated with an API key." # rubocop:disable Layout/LineLength
    end

    # Now that we've backfilled servers with API key references, we can add NOT NULL
    change_column_null :servers, :api_key_id, false
  end

  def down
    remove_reference :servers, :api_key, foreign_key: true
  end
end
