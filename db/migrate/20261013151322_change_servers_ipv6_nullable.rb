class ChangeServersIpv6Nullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :servers, :ipv6, true
  end
end
