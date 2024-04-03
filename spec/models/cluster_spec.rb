RSpec.describe Cluster do
  it "validates that endpoint is a valid URL" do
    cluster = Cluster.new(endpoint: "example.com")
    cluster.validate

    expect(cluster.errors[:endpoint]).to include "must start with https://"
    expect(cluster.errors[:endpoint]).to include "must end with an explicit port, eg. :6443"

    cluster.endpoint = "https:// example.com:6443"
    cluster.validate

    expect(cluster.errors[:endpoint]).to include "must be a valid URL"

    cluster.endpoint = "https://example.com:6443"
    cluster.validate

    expect(cluster.errors[:endpoint]).to be_empty
  end
end
