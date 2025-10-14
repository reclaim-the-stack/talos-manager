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

  describe "#bootstrap_image_url" do
    it "returns a URL to a Talos image with the correct schematic ID and Talos version" do
      talos_version = "v1.10.5"
      server = servers(:cloud_bootstrappable)
      server.update! talos_image_factory_schematic: talos_image_factory_schematics(:default)
      expected_url = "#{TalosImageFactory::BASE_URL}/image/#{talos_image_factory_schematics(:default).schematic_id}/#{talos_version}/metal-#{server.architecture}.raw.zst" # rubocop:disable Layout/LineLength
      expect(server.bootstrap_image_url(talos_version:)).to eq(expected_url)
    end

    it "uses the default Talos version and schematic_id if none are provided" do
      server = Server.new
      default_setting = TalosImageFactorySetting.singleton
      default_setting.update! talos_image_factory_schematic: talos_image_factory_schematics(:default)
      expected_url = "#{TalosImageFactory::BASE_URL}/image/#{default_setting.talos_image_factory_schematic&.schematic_id}/#{default_setting.version}/metal-#{server.architecture}.raw.zst" # rubocop:disable Layout/LineLength
      expect(server.bootstrap_image_url).to eq(expected_url)
    end
  end

  describe "#bootstrap!" do
    it "writes a Talos image to an eligble disk, saves metadata and reboots" do
      talos_version = "v1.10.5"

      server = servers(:cloud_bootstrappable)
      server.update! talos_image_factory_schematic: talos_image_factory_schematics(:default)

      ssh_session_mock = instance_double(Net::SSH::Connection::Session)
      ssh_channel_mock = instance_double(Net::SSH::Connection::Channel)
      expect(ssh_channel_mock).to receive(:on_data).at_least(:once)
      expect(ssh_channel_mock).to receive(:on_extended_data).at_least(:once)
      expect(ssh_channel_mock).to receive(:wait).at_least(:once)

      image = server.bootstrap_image_url(talos_version:)
      expect(ssh_session_mock).to receive(:exec)
        .with("sfdisk --delete /dev/nvme0n1 || echo 'ignoring non-zero exit code from sfdisk'", status: {}) do |_, options|
          options[:status][:exit_code] = 0
          ssh_channel_mock
        end
      expect(ssh_session_mock).to receive(:exec)
        .with("wipefs -a -f /dev/nvme0n1", status: {}) do |_, options|
          options[:status][:exit_code] = 0
          ssh_channel_mock
        end
      expect(ssh_session_mock).to receive(:exec)
        .with("wget #{image} --quiet -O - | zstd -d | dd of=/dev/nvme0n1 status=progress", status: {}) do |_, options|
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

      expect(server.reload).not_to be_accessible
    end
  end

  describe "#bootstrap_disk_wwid=" do
    it "converts SCSI WWIDs to the correct format" do
      server = Server.new(bootstrap_disk_wwid: "0x5002538c6003052d")
      expect(server.bootstrap_disk_wwid).to eq "naa.5002538c6003052d"

      # sanity check regular WWIDs are not changed
      server = Server.new(bootstrap_disk_wwid: "eui.00000000000000178ce38e02001d0b64")
      expect(server.bootstrap_disk_wwid).to eq "eui.00000000000000178ce38e02001d0b64"
    end
  end
end
