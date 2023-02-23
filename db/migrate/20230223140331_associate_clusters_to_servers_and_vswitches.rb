class AssociateClustersToServersAndVswitches < ActiveRecord::Migration[7.0]
  def change
    change_table :hetzner_servers do |t|
      t.references :cluster, foreign_key: true
    end

    change_table :clusters do |t|
      t.references :hetzner_vswitch, foreign_key: true
    end
  end
end
