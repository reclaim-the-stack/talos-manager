class AddLabeledAndTaintedAtToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :label_and_taint_job_completed_at, :datetime
  end
end
