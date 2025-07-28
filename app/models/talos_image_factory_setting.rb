# frozen_string_literal: true

# This is used as a singleton model for storing default bootstrap image settings.

class TalosImageFactorySetting < ApplicationRecord
  def self.singleton
    first_or_create!
  end

  validates :version, presence: true
  validates :version, uniqueness: true
  validates :version, format: { with: /\Av\d+\.\d+\.\d+\z/, message: "must be in the format vX.Y.Z" }
  validates :version, length: { maximum: 20 }

  attribute :version, :string, default: "v1.10.4"

  validates_presence_of :version
end
