class CreateLabelAndTaintRules < ActiveRecord::Migration[8.0]
  def change
    create_table :label_and_taint_rules do |t|
      t.string :match, null: false
      t.string :labels, array: true, null: false, default: []
      t.string :taints, array: true, null: false, default: []

      t.timestamps
    end
  end
end
