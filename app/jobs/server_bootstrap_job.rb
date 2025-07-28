class ServerBootstrapJob < ApplicationJob
  def perform(server_id, talos_version:)
    server = Server.find_by_id(server_id)
    return unless server

    server.bootstrap!(talos_version:)
  end
end
