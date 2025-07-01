class ApiKey < ApplicationRecord
  has_many :servers

  validates_presence_of :provider, :name, :secret
  validates_inclusion_of :provider, in: %w[hetzner_cloud hetzner_robot]
  validates_uniqueness_of :name, case_sensitive: false

  validate :validate_credentials

  encrypts :secret

  def client
    @client ||= case provider
      when "hetzner_cloud" then HetznerCloud.new(api_key: secret)
      when "hetzner_robot" then HetznerRobot.new(username: name, password: secret)
      else
        raise ArgumentError, "Unsupported provider: #{provider}"
      end
  end

  private

  def validate_credentials
    client.servers
  rescue StandardError => e
    errors.add(:secret, "Invalid API credentials or upstream service error: #{e.message}")
  end
end
