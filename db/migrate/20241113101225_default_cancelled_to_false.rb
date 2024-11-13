class DefaultCancelledToFalse < ActiveRecord::Migration[7.2]
  def change
    change_column_default :servers, :cancelled, from: nil, to: false
  end
end
