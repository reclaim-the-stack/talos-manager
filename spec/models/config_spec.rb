RSpec.describe Config do
  it "validates talos config" do
    invalid_nameservers_patch = <<~YAML
      machine:
        install:
          extraKernelArgs:
            - cpufreq.default_governor=performance
        network:
          interfaces:
            - interface: enp1s0
              addresses:
                - 2a01:4f9:c012:c66c::1/64
              routes:
                - network: '::/0' # This specifies the default route for IPv6.
                  gateway: fe80::1
              # The MAC address match and set-name options from Hetzner's example are not directly applicable in Talos as per the given documentation snippet.
          # This is incorrect, should be just an Array of Strings
          nameservers:
            addresses:
              - 2a01:4ff:ff00::add:2
              - 2a01:4ff:ff00::add:1
    YAML

    config = Config.new(install_image: "image", kubernetes_version: "1.30.1", patch: invalid_nameservers_patch)
    config.validate

    expect(config.errors[:config].to_sentence).to include "error parsing config JSON patch"
  end

  it "validates YAML syntax of every document in every patch" do
    config = Config.new(
      install_image: "image",
      kubernetes_version: "1.30.1",
      patch: "machine: {}\n---\napiVersion: v1alpha1\nkind: [",
      patch_worker: "machine: [",
    )
    config.validate

    expect(config.errors[:patch]).to be_present
    expect(config.errors[:patch_control_plane]).to be_empty
    expect(config.errors[:patch_worker]).to be_present
  end

  it "rejects patches setting the hostname since it's always the name of the server" do
    hostname_patches = {
      patch: <<~YAML,
        machine:
          network:
            hostname: ${hostname}
      YAML
      patch_control_plane: <<~YAML,
        apiVersion: v1alpha1
        kind: SysctlConfig
        params:
          vm.max_map_count: "262144"
        ---
        apiVersion: v1alpha1
        kind: HostnameConfig
        auto: "off"
        hostname: ${hostname}
      YAML
      patch_worker: <<~YAML,
        - op: add
          path: /machine/network/hostname
          value: ${hostname}
      YAML
    }

    config = Config.new(install_image: "image", kubernetes_version: "1.30.1", **hostname_patches)
    config.validate

    hostname_patches.each_key do |attribute|
      expect(config.errors[attribute])
        .to include "must not set the hostname since Talos Manager sets it to the name of the server"
    end
  end

  it "accepts multi document patches for Talos 1.12+" do
    TalosImageFactorySetting.singleton.update!(version: "v1.14.2")

    config = Config.new(
      install_image: "ghcr.io/siderolabs/installer:v1.14.2",
      kubernetes_version: "1.33.3",
      patch: <<~YAML,
        apiVersion: v1alpha1
        kind: SysctlConfig
        params:
          vm.max_map_count: "262144"
        ---
        apiVersion: v1alpha1
        kind: KubeSpanConfig
        enabled: true
        advertiseKubernetesNetworks: true
      YAML
      patch_worker: <<~YAML,
        apiVersion: v1alpha1
        kind: UserVolumeConfig
        name: openebs-local
        volumeType: directory
      YAML
    )
    config.validate

    expect(config.errors[:config]).to be_empty
    expect(config.errors[:patch]).to be_empty
    expect(config.errors[:patch_worker]).to be_empty
  end
end
