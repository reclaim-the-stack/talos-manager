class TalosImageFactorySchematic < ApplicationRecord
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :body
  validate :validate_and_normalize_and_post_body, if: :body_changed?
  validates_presence_of :schematic_id # must be validated after body is validated and posted

  has_one :talos_image_factory_setting, dependent: :nullify

  # private

  def validate_and_normalize_and_post_body
    return if body.blank?

    deserialized_body =
      begin
        YAML.load(body)
      rescue Psych::SyntaxError => e
        errors.add(:body, "is not valid YAML: #{e.message}")
        return # rubocop:disable Lint/NoReturnInBeginEndBlocks
      end

    unless deserialized_body.is_a?(Hash)
      errors.add(:body, "must be a YAML object")
      return
    end

    deserialized_body["customization"] ||= {}
    deserialized_body["customization"]["extraKernelArgs"] ||= []

    extra_kernel_args = deserialized_body["customization"]["extraKernelArgs"]
    extra_kernel_args.delete_if { it.starts_with?("talos.config") }
    extra_kernel_args << "talos.config=https://#{HOST}/config"

    response =
      begin
        TalosImageFactory.create_schematic(deserialized_body)
      rescue TalosImageFactory::HttpError => e
        errors.add(:body, "POST to Talos Image Factory failed: #{e.message}")
        return # rubocop:disable Lint/NoReturnInBeginEndBlocks
      end

    self.body = deserialized_body.to_yaml.delete_prefix("---\n")
    self.schematic_id = response.fetch("id")
  end
end
