class CreateHetznerVswitches < ActiveRecord::Migration[7.0]
  def change
    create_table :hetzner_vswitches do |t|
      t.string :name, null: false
      t.integer :vlan, null: false

      t.timestamps
    end
  end
end
