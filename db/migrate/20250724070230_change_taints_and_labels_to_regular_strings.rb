class ChangeTaintsAndLabelsToRegularStrings < ActiveRecord::Migration[8.0]
  def up
    existing = ApplicationRecord.connection
      .query("SELECT id,array_to_string(labels, ','),array_to_string(taints, ',') FROM label_and_taint_rules")

    remove_column :label_and_taint_rules, :labels
    remove_column :label_and_taint_rules, :taints

    add_column :label_and_taint_rules, :labels, :string
    add_column :label_and_taint_rules, :taints, :string

    existing.each do |row|
      id, labels, taints = row
      LabelAndTaintRule.where(id:).update_all(labels: labels, taints: taints)
    end
  end

  def down
    existing = ApplicationRecord.connection
      .query("SELECT id,labels,taints FROM label_and_taint_rules")

    remove_column :label_and_taint_rules, :labels
    remove_column :label_and_taint_rules, :taints

    add_column :label_and_taint_rules, :labels, :string, array: true, default: []
    add_column :label_and_taint_rules, :taints, :string, array: true, default: []

    existing.each do |row|
      id, labels, taints = row
      LabelAndTaintRule.where(id:).update_all(labels: labels.split(','), taints: taints.split(','))
    end
  end
end
