class HetznerVswitch < ApplicationRecord
  validates_presence_of :name
  validates_presence_of :vlan

  has_many :hetzner_servers
end
