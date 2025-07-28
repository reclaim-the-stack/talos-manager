RSpec.describe LabelAndTaintJob do
  it "applies labels and taints to a server via kubectl and updates label_and_taint_job_completed_at" do
    LabelAndTaintRule.create!(
      match: "worker",
      labels: "node-role.kubernetes.io/worker=",
    )
    LabelAndTaintRule.create!(
      match: "database",
      labels: "node-role.kubernetes.io/database=",
      taints: "role=database:NoSchedule",
    )

    api_key = api_keys(:hetzner_cloud)
    cluster = Cluster.create!(name: "test", endpoint: "https://kubernetes.localhost:6443")

    server = Server.create!(
      name: "worker-108",
      accessible: true,
      api_key_id: api_key.id,
      cluster_id: cluster.id,
      data_center: "DC1",
      ip: "10.10.10.10",
      ipv6: "::1",
      product: "P",
      status: "running",
    )

    kubectl_mock = Kubectl.new("kubeconf")

    expect(kubectl_mock).to receive(:run).with("get node worker-108")
      .and_return([true, "", ""])
    expect(kubectl_mock).to receive(:run).with("label node worker-108 --overwrite node-role.kubernetes.io/worker=")
      .and_return([true, "", ""])

    allow_any_instance_of(Server).to receive(:kubectl).and_return(kubectl_mock)

    LabelAndTaintJob.perform_now(server.id)

    expect(server.reload.label_and_taint_job_completed_at).to be_present

    server.update!(name: "staging-database-108", label_and_taint_job_completed_at: nil)

    kubectl_mock = Kubectl.new("kubeconf")

    expect(kubectl_mock).to receive(:run).with("get node staging-database-108")
      .and_return([true, "", ""])
    expect(kubectl_mock).to receive(:run).with("label node staging-database-108 --overwrite node-role.kubernetes.io/database=")
      .and_return([true, "", ""])
    expect(kubectl_mock).to receive(:run).with("taint node staging-database-108 role=database:NoSchedule")
      .and_return([true, "", ""])

    allow_any_instance_of(Server).to receive(:kubectl).and_return(kubectl_mock)

    LabelAndTaintJob.perform_now(server.id)

    expect(server.reload.label_and_taint_job_completed_at).to be_present
  end
end
