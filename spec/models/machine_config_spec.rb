RSpec.describe MachineConfig do
  describe "#generate_config" do
    it "raises an error if hostname is blank" do
      server = Server.new(name: "worker-1")
      machine_config = MachineConfig.new(hostname: nil, server:)
      expect { machine_config.generate_config }.to raise_error "can't generate config before assigning hostname"
    end

    it "raises an error if private_ip is blank" do
      server = Server.new(name: "worker-1")
      machine_config = MachineConfig.new(hostname: server.name, private_ip: nil, server: server)
      expect { machine_config.generate_config }.to raise_error "can't generate config before assigning private_ip"
    end

    it "generates a config" do
      hetzner_vswitch = HetznerVswitch.new(name: "vswitch", vlan: 1337)
      cluster = Cluster.create!(
        name: "cluster",
        endpoint: "https://cluster.example.com:6443",
        hetzner_vswitch:,
        secrets: File.read("spec/fixtures/files/secrets.yaml"),
      )
      server = Server.new(name: "worker-1", ip: "72.14.201.110", cluster:)
      config = Config.new(
        name: "config",
        install_image: "ghcr.io/siderolabs/installer:v1.10.3",
        kubernetes_version: "1.30.1",
        kubespan: true,
        patch: <<~YAML,
          machine:
            network:
              hostname: ${hostname}
              interfaces:
                - dhcp: true
                  interface: eth0
                  addresses:
                    - ${public_ip}/24
                  vlans:
                    - addresses:
                        - ${private_ip}/21
                      mtu: 1400
                      vlanId: ${vlan}
        YAML
        patch_control_plane: <<~YAML,
          cluster:
            aescbcEncryptionSecret: 1hP1IcdbHz/XYOwl03Ro0+E6rCRfhn2NjiZZ+WKGqew=
        YAML
        patch_worker: <<~YAML,
          machine:
            kubelet:
              extraMounts:
                - destination: /var/openebs/local
                  options:
                    - rbind
                    - rshared
                    - rw
                  source: /var/openebs/local
                  type: bind
        YAML
      )
      machine_config = MachineConfig.new(
        hostname: server.name,
        private_ip: "10.0.1.1",
        install_disk: "/dev/nvme0n1",
        config:,
        server:,
      )
      expect(machine_config.generate_config).to eq <<~YAML
        version: v1alpha1
        debug: false
        persist: true
        machine:
          type: worker
          token: tjbj5r.y78u7e6vioadusxr
          ca:
            crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJQekNCOHFBREFnRUNBaEVBdVNrWDBwcUhiVlAzdEZJMVBqa2J1ekFGQmdNclpYQXdFREVPTUF3R0ExVUUKQ2hNRmRHRnNiM013SGhjTk1qUXhNVEV6TURreU9EQXpXaGNOTXpReE1URXhNRGt5T0RBeldqQVFNUTR3REFZRApWUVFLRXdWMFlXeHZjekFxTUFVR0F5dGxjQU1oQUVoUEJrMUd6MmlwRkpMemxTVnNkU2ZZYnU5SnUwcU5waGV6CnppamNONmZ4bzJFd1h6QU9CZ05WSFE4QkFmOEVCQU1DQW9Rd0hRWURWUjBsQkJZd0ZBWUlLd1lCQlFVSEF3RUcKQ0NzR0FRVUZCd01DTUE4R0ExVWRFd0VCL3dRRk1BTUJBZjh3SFFZRFZSME9CQllFRkxrcWFGbzhneWdGQUxtcwpmVHFSL0pVeDN5Z2dNQVVHQXl0bGNBTkJBR0lKNmxQZXJoSEc4QXJLYzdwblM1WXRZRkFDdTE2THV3aFlDYW0wCjV6VXNOU0VHZDd2VHphRXgydjdTU1R3ZmxHVjN0UjNVN0VYdDRGdHE1QlpFa3dFPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
            key: ''
          certSANs: []
          kubelet:
            image: ghcr.io/siderolabs/kubelet:v1.30.1
            extraMounts:
            - destination: "/var/openebs/local"
              type: bind
              source: "/var/openebs/local"
              options:
              - rbind
              - rshared
              - rw
            defaultRuntimeSeccompProfileEnabled: true
            disableManifestsDirectory: true
          network:
            hostname: worker-1
            interfaces:
            - interface: eth0
              addresses:
              - 72.14.201.110/24
              vlans:
              - addresses:
                - 10.0.1.1/21
                routes: []
                vlanId: 1337
                mtu: 1400
              dhcp: true
            kubespan:
              enabled: true
          install:
            disk: "/dev/nvme0n1"
            image: ghcr.io/siderolabs/installer:v1.10.3
            wipe: false
          features:
            rbac: true
            stableHostname: true
            apidCheckExtKeyUsage: true
            diskQuotaSupport: true
            kubePrism:
              enabled: true
              port: 7445
            hostDNS:
              enabled: true
              forwardKubeDNSToHost: true
        cluster:
          id: tU5mLlegKAEG9dzpYl2AUmzqjvWrOgosLmcsdBgotuU=
          secret: 7sfcLtpX8+5+Pf/dWVSr6bXBcYtLFn9g9L0FOn60h0s=
          controlPlane:
            endpoint: https://cluster.example.com:6443
          clusterName: cluster
          network:
            dnsDomain: cluster.local
            podSubnets:
            - 10.244.0.0/16
            serviceSubnets:
            - 10.96.0.0/12
          token: nhniwa.a7f4n48gws059jra
          ca:
            crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJpakNDQVRDZ0F3SUJBZ0lSQUx3Z1o1ckVjZGliTFJFdVpYRTdXM0l3Q2dZSUtvWkl6ajBFQXdJd0ZURVQKTUJFR0ExVUVDaE1LYTNWaVpYSnVaWFJsY3pBZUZ3MHlOREV4TVRNd09USTRNRE5hRncwek5ERXhNVEV3T1RJNApNRE5hTUJVeEV6QVJCZ05WQkFvVENtdDFZbVZ5Ym1WMFpYTXdXVEFUQmdjcWhrak9QUUlCQmdncWhrak9QUU1CCkJ3TkNBQVNLVWZjMkVsM2QwM1JDMHhEa1hyMCtYTkdncWFUQVBuRitja25COGwvU2d5K0ZRd1FUdVNqQUxiWGYKc3FodGg1eE1rbFRDY1c2bDd5Q0N0WWh1OTJGU28yRXdYekFPQmdOVkhROEJBZjhFQkFNQ0FvUXdIUVlEVlIwbApCQll3RkFZSUt3WUJCUVVIQXdFR0NDc0dBUVVGQndNQ01BOEdBMVVkRXdFQi93UUZNQU1CQWY4d0hRWURWUjBPCkJCWUVGTi9mYWIzalczUmhiNmZ3dElqWHdkbFhvZEFtTUFvR0NDcUdTTTQ5QkFNQ0EwZ0FNRVVDSUNWdmVYeS8KZWsvZUt4cC9OV3NDWUNrMmVnaVViMzhtMW5aY2Z6cmxNQnlCQWlFQWdmQXNnaFZIeHMwMlhST2tQUjJONGVySgp4QU9DRXBFRXh3KzYySE41amJJPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
            key: ''
          discovery:
            enabled: true
            registries:
              kubernetes:
                disabled: true
              service: {}
      YAML
    end
  end
end
