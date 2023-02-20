class HetznerServer < ApplicationRecord
  belongs_to :hetzner_vswitch, optional: true

  validates_presence_of :ip
  validates_presence_of :ipv6
  validates_presence_of :product
  validates_presence_of :data_center
  validates_presence_of :status
end
