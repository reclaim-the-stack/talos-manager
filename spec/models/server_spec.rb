RSpec.describe Server do
  it "validates uniqueness of name but only if it changed (to allow other attributes to be updated while duplicates exists)" do
    api_key = api_keys(:hetzner_cloud)

    common_attributes = {
      name: "worker-1",
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
      ]
    )

    server = Server.first
    server.update!(status: "stopping") # we can update status even though name is not unique
    server.update!(name: "worker-2")

    server.update(name: "worker-1") # we can't update name to an existing one

    expect(server.errors[:name]).to include "has already been taken"
  end
end
