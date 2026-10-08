RSpec.describe Talosctl do
  describe "#kubernetes_version" do
    it "returns the version of the first apiserverconfig image" do
      talosctl = Talosctl.new("talosconfig")
      stdout = "registry.k8s.io/kube-apiserver:v1.33.3\nregistry.k8s.io/kube-apiserver:v1.33.3\n"
      allow(talosctl).to receive(:run).with("get apiserverconfig -o jsonpath={.spec.image}").and_return([true, stdout, ""])

      expect(talosctl.kubernetes_version).to eq "1.33.3"
    end

    it "returns nil if the apiserverconfig can't be read" do
      talosctl = Talosctl.new("talosconfig")
      allow(talosctl).to receive(:run).and_return([false, "", "error"])

      expect(talosctl.kubernetes_version).to be_nil
    end

    it "returns nil if the image doesn't contain a version" do
      talosctl = Talosctl.new("talosconfig")
      allow(talosctl).to receive(:run).and_return([true, "registry.k8s.io/kube-apiserver:latest\n", ""])

      expect(talosctl.kubernetes_version).to be_nil
    end
  end
end
