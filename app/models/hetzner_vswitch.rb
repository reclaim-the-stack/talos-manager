class HetznerVswitch < ApplicationRecord
  validates_presence_of :name
  validates_presence_of :vlan

  has_many :servers, through: :clusters
  has_many :clusters
end
