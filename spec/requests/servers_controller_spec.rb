RSpec.describe "ServersController" do
  describe "GET /admin/index" do
    it "returns http success" do
      get "/admin/servers"
      expect(response).to have_http_status 200
    end
  end

  describe "POST /admin/servers/sync" do
    it "syncs servers with the provider and redirects back to index" do
      lsblk_output = File.read("spec/fixtures/files/lsblk.json")

      # Hetzner Robot API key requests
      hetzner_robot_response = File.read("spec/fixtures/files/hetzner-robot-servers.json")
      stub_request(:get, "https://robot-ws.your-server.de/vswitch")
        .to_return(status: 200, body: "[]")
      stub_request(:get, "https://robot-ws.your-server.de/server")
        .to_return(status: 200, body: hetzner_robot_response)

      # Hetzner Cloud API key requests
      hetzner_cloud_response = File.read("spec/fixtures/files/hetzner-cloud-servers.json")
      stub_request(:get, "https://api.hetzner.cloud/v1/servers?per_page=50")
        .to_return(status: 200, body: hetzner_cloud_response)

      # Make the first cloud server bootstrappable
      ssh_session_mock = instance_double(Net::SSH::Connection::Session)
      expect(ssh_session_mock).to receive(:exec!)
        .with("hostname")
        .and_return("rescue\n")
      expect(ssh_session_mock).to receive(:exec!)
        .with("dmidecode -s system-uuid")
        .and_return("123e4567-e89b-12d3-a456-426614174000\n")
      expect(ssh_session_mock).to receive(:exec!)
        .with("lsblk --output NAME,TYPE,SIZE,UUID,MODEL,WWN --bytes --json")
        .and_return(lsblk_output)
      expect(ssh_session_mock).to receive(:shutdown!)

      hetzner_cloud_servers = JSON.parse(hetzner_cloud_response)

      key_data = [ENV.fetch("SSH_PRIVATE_KEY")]
      first_server_ip = hetzner_cloud_servers.dig("servers", 0, "public_net", "ipv4", "ip")
      expect(Net::SSH).to receive(:start)
        .with(first_server_ip, "root", key_data:, non_interactive: true, verify_host_key: :never, timeout: 2)
        .and_return(ssh_session_mock)

      second_server_ip = hetzner_cloud_servers.dig("servers", 1, "public_net", "ipv4", "ip")
      expect(Net::SSH).to receive(:start)
        .with(second_server_ip, "root", key_data:, non_interactive: true, verify_host_key: :never, timeout: 2)
        .and_raise(Errno::ECONNREFUSED)

      # Make the first robot server bootstrappable
      ssh_robot_session_mock = instance_double(Net::SSH::Connection::Session)
      expect(ssh_robot_session_mock).to receive(:exec!)
        .with("hostname")
        .and_return("rescue\n")
      expect(ssh_robot_session_mock).to receive(:exec!)
        .with("dmidecode -s system-uuid")
        .and_return("63391acf-ceb9-1891-72fc-c87f545220d8\n")
      expect(ssh_robot_session_mock).to receive(:exec!)
        .with("lsblk --output NAME,TYPE,SIZE,UUID,MODEL,WWN --bytes --json")
        .and_return(lsblk_output)
      expect(ssh_robot_session_mock).to receive(:shutdown!)

      hetzner_robot_servers = JSON.parse(hetzner_robot_response)

      first_robot_server_ip = hetzner_robot_servers.dig(0, "server", "server_ip")
      expect(Net::SSH).to receive(:start)
        .with(first_robot_server_ip, "root", key_data:, non_interactive: true, verify_host_key: :never, timeout: 2)
        .and_return(ssh_robot_session_mock)

      second_robot_server_ip = hetzner_robot_servers.dig(1, "server", "server_ip")
      expect(Net::SSH).to receive(:start)
        .with(second_robot_server_ip, "root", key_data:, non_interactive: true, verify_host_key: :never, timeout: 2)
        .and_raise(Errno::ECONNREFUSED)

      post "/admin/servers/sync"

      expect(Server.count).to eq 4

      expect(Server.find_by!(name: "worker-1")).to have_attributes(
        accessible: true,
        uuid: "123e4567-e89b-12d3-a456-426614174000",
        lsblk: JSON.parse(lsblk_output),
      )

      expect(Server.find_by!(name: "worker-2")).to have_attributes(
        accessible: false,
        uuid: nil,
        lsblk: nil,
      )

      expect(Server.find_by!(name: "worker-3")).to have_attributes(
        accessible: true,
        uuid: "63391acf-ceb9-1891-72fc-c87f545220d8",
        lsblk: JSON.parse(lsblk_output),
      )

      expect(Server.find_by!(name: "worker-4")).to have_attributes(
        accessible: false,
        uuid: nil,
        lsblk: nil,
      )

      expect(response).to redirect_to servers_path
      expect(flash[:notice]).to be_present
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
    it "enqueues the bootstrapping job, updates the server and redirects back to servers" do
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

      # Check that the ServerBootstrapJob was enqueued
      expect(ServerBootstrapJob).to have_been_enqueued.with(server.id, talos_version:)

      expect(server.reload).to have_attributes(
        accessible: false,
        label_and_taint_job_completed_at: nil,
        last_configured_at: nil,
        last_request_for_configuration_at: nil,
        talos_image_factory_schematic_id: talos_image_factory_schematics(:default).id,
      )

      expect(response).to redirect_to servers_path
      expect(flash[:notice]).to be_present
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
