class ServerBootstrapJob < ApplicationJob
  def perform(server_id)
    server = Server.find_by_id(server_id)
    return unless server

    server.bootstrap!
  end
end
