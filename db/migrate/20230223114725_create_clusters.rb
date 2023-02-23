class CreateClusters < ActiveRecord::Migration[7.0]
  def change
    create_table :clusters do |t|
      t.string :name, null: false
      t.string :endpoint, null: false
      t.text :secrets, null: false

      t.timestamps
    end
  end
end
