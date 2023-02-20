class HetznerServer < ApplicationRecord
  belongs_to :hetzner_vswitch, optional: true

  attr_accessor :sync # set to true to sync changed attributes to hetzner

  validates_presence_of :ip
  validates_presence_of :ipv6
  validates_presence_of :product
  validates_presence_of :data_center
  validates_presence_of :status

  after_save :sync_with_hetzner, if: :sync

  private

  def sync_with_hetzner
    if saved_change_to_name?
      Hetzner.update_server(id, server_name: name)
    end

    if saved_change_to_hetzner_vswitch_id?
      initial_vswitch_id, new_vswitch_id = saved_changes.fetch("hetzner_vswitch_id")

      # The server was connected to a vswitch and we need to disconnect it
      if initial_vswitch_id
        Hetzner.remove_server_from_vswitch(initial_vswitch_id, id)
      end

      if new_vswitch_id
        Hetzner.add_server_to_vswitch(new_vswitch_id, id)
      end
    end
  end
end
