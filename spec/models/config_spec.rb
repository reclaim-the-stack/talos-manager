RSpec.describe Config do
  it "validates talos config" do
    invalid_nameservers_patch = <<~YAML
      machine:
        install:
          extraKernelArgs:
            - cpufreq.default_governor=performance
        network:
          hostname: ${hostname}
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

    config = Config.new(install_image: "image", kubernetes_version: "1.29.2", patch: invalid_nameservers_patch)
    config.validate

    expect(config.errors[:config].to_sentence).to include "error parsing config JSON patch"
  end
end
