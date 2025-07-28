RSpec.describe Server do
  it "validates uniqueness of name but only if it changed (to allow other attributes to be updated while duplicates exists)" do
    api_key = api_keys(:hetzner_cloud)

    common_attributes = {
      name: "unique-worker-1",
      ipv6: "::1",
      product: "P",
      status: "running",
      data_center: "DC1",
      api_key_id: api_key.id,
    }
    Server.insert_all!(
      [
        common_attributes.merge(ip: "10.0.0.1"),
        common_attributes.merge(ip: "10.0.0.2"),
      ],
    )

    server = Server.first
    server.update!(status: "stopping") # we can update status even though name is not unique
    server.update!(name: "unique-worker-2")

    server.update(name: "unique-worker-1") # we can't update name to an existing one

    expect(server.errors[:name]).to include "has already been taken"
  end

  describe "#bootstrap!" do
    it "writes a Talos image to an eligble disk, saves metadata and reboots" do
      talos_version = "v1.10.5"

      server = servers(:cloud_bootstrappable)
      server.update! talos_image_factory_schematic: talos_image_factory_schematics(:default)

      ssh_session_mock = instance_double(Net::SSH::Connection::Session)
      expect(ssh_session_mock).to receive(:exec!)
        .with("dmidecode -s system-uuid")
        .and_return("123e4567-e89b-12d3-a456-426614174000")
      expect(ssh_session_mock).to receive(:exec!)
        .with("lsblk --output NAME,TYPE,SIZE,UUID,MODEL,WWN --bytes --json")
        .and_return(File.read("spec/fixtures/files/lsblk.json"))

      ssh_channel_mock = instance_double(Net::SSH::Connection::Channel)
      expect(ssh_channel_mock).to receive(:on_data).at_least(:once)
      expect(ssh_channel_mock).to receive(:on_extended_data).at_least(:once)
      expect(ssh_channel_mock).to receive(:wait).at_least(:once)

      image = server.bootstrap_image_url(talos_version:)
      expect(ssh_session_mock).to receive(:exec)
        .with("wget #{image} --quiet -O - | zstd -d | dd of=/dev/nvme1n1 status=progress", status: {}) do |_command, options|
          options[:status][:exit_code] = 0
          ssh_channel_mock
        end
      expect(ssh_session_mock).to receive(:exec)
        .with("sync", status: {}) do |_command, options|
          options[:status][:exit_code] = 0
          ssh_channel_mock
        end

      expect(ssh_session_mock).to receive(:exec!).with("reboot")
      expect(ssh_session_mock).to receive(:shutdown!)

      expect(Net::SSH).to receive(:start).and_return(ssh_session_mock)

      server.bootstrap!(talos_version:)

      expect(server.reload).to have_attributes(
        accessible: false,
        bootstrap_disk: "/dev/nvme1n1",
        bootstrap_disk_wwid: "eui.36344630528029720025384500000002", # see lsblk fixture
        uuid: "123e4567-e89b-12d3-a456-426614174000",
      )
    end
  end
end
