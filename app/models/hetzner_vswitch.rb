class HetznerVswitch < ApplicationRecord
  validates_presence_of :name
  validates_presence_of :vlan

  has_many :hetzner_servers, through: :clusters
  has_many :clusters
end
