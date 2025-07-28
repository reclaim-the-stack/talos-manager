RSpec.describe "ServersController" do
  describe "GET /admin/index" do
    it "returns http success" do
      get "/admin/servers"
      expect(response).to have_http_status 200
    end
  end

  describe "GET /admin/servers/<server-id>/prepare_bootstrap" do
    it "returns http success" do
      server = servers(:cloud_bootstrappable)

      get "/admin/servers/#{server.id}/prepare_bootstrap"
      expect(response).to have_http_status 200
    end
  end

  describe "POST /admin/servers/<server-id>/bootstrap" do
    it "returns http redirect" do
      server = servers(:cloud_bootstrappable)
      talos_version = "v1.10.5"

      # Explicitly setting these to be able to verify that they are reset by the bootstrap action
      server.update!(
        accessible: true,
        label_and_taint_job_completed_at: Time.now,
        last_configured_at: Time.now,
        last_request_for_configuration_at: Time.now,
        talos_image_factory_schematic_id: nil,
      )

      post "/admin/servers/#{server.id}/bootstrap", params: {
        talos_version:,
        talos_image_factory_schematic_id: talos_image_factory_schematics(:default).id,
      }

      server.reload
      expect(server).to have_attributes(
        accessible: false,
        label_and_taint_job_completed_at: nil,
        last_configured_at: nil,
        last_request_for_configuration_at: nil,
        talos_image_factory_schematic_id: talos_image_factory_schematics(:default).id,
      )
      expect(response).to redirect_to servers_path
      expect(flash[:notice]).to be_present

      # Check that the ServerBootstrapJob was enqueued
      expect(ServerBootstrapJob).to have_been_enqueued.with(server.id, talos_version:)
    end
  end

  describe "GET /admin/servers/<server-id>/reboot_command" do
    it "returns http success" do
      server = servers(:cloud_botstrapped)

      get "/admin/servers/#{server.id}/reboot_command"
      expect(response).to have_http_status 200
    end
  end

  describe "GET /admin/servers/<server-id>/upgrade_command" do
    it "returns http success" do
      schematic = talos_image_factory_schematics(:default)
      TalosImageFactorySetting.singleton.update!(schematic_id: schematic.id)
      server = servers(:cloud_botstrapped)

      get "/admin/servers/#{server.id}/upgrade_command"
      expect(response).to have_http_status 200
    end
  end
end
