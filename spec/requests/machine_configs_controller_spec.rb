RSpec.describe "MachineConfigsController" do
  describe "GET /admin/machine_configs/new" do
    it "shows the server name as a read-only hostname" do
      server = servers(:cloud_bootstrappable)

      get "/admin/machine_configs/new", params: { server_id: server.id }

      expect(response).to have_http_status 200
      hostname_field = response.body[/<input[^>]*name="machine_config\[hostname\]"[^>]*>/]
      expect(hostname_field).to include 'value="worker-1"'
      expect(hostname_field).to include "disabled"
    end
  end

  describe "POST /admin/machine_configs" do
    it "shows an error if the server name isn't a valid hostname" do
      server = servers(:cloud_bootstrappable)
      server.update!(name: "Worker")

      post "/admin/machine_configs", params: {
        machine_config: { server_id: server.id, private_ip: "10.0.1.1", install_disk: "/dev/nvme0n1" },
      }

      expect(response).to have_http_status 422
      expect(response.body).to include "rename the server to change it"
    end
  end
end
