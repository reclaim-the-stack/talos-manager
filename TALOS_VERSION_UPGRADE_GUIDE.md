# Talos Version Upgrade Guide

Talos Manager generates machine configs with `talosctl gen config --talos-version <version>`, where the version is the "Default Talos Version" on the Settings page. Newer Talos versions move settings out of the legacy `v1alpha1` machine config into separate config documents, and a config patch which sets a legacy field that `gen config` now generates as a document is rejected. Hence changing the default Talos version can require changes to your Config patches.

This guide describes the patch changes needed per Talos version. For upgrading Talos itself on your nodes, see [Upgrading Talos on a node](README.md#upgrading-talos-on-a-node).

Note that Talos Manager only generates configs for servers being bootstrapped. Already running nodes keep their legacy config, which newer Talos versions still accept. But where behaviour differs between a legacy field and its replacement (eg. kernel args, OpenEBS paths and etcd encryption below), new nodes will behave differently from existing ones unless you also patch the existing nodes, eg. with `talosctl patch machineconfig`.

## Upgrade procedure

1. Read the upgrade notes for the target Talos version, eg. [What's New in Talos 1.14](https://docs.siderolabs.com/talos/v1.14/getting-started/what%27s-new-in-talos).
2. Upgrade Talos on all nodes in all clusters, since the default Talos version applies to every cluster.
3. Update your Talos Schematics if needed, eg. to add kernel args which move out of the machine config.
4. Change the "Default Talos Version" on the Settings page.
5. Open and save every Config. Saving validates the patches against the new Talos version with `talosctl validate --strict` and reports any conflicting fields. Fix them according to the sections below.
6. Open the machine config of an existing server in each cluster and sanity check it.

Talos Manager doesn't validate machine configs when serving them to servers. Until every Config has been saved successfully, don't bootstrap any servers, since they may receive a config they reject.

## Upgrading to Talos 1.12+

### Conflicting legacy fields

| Legacy field in patch | Rejected from | Replacement |
|---|---|---|
| `machine.network.hostname` | 1.12 | Remove it. Talos Manager sets the hostname. |
| `machine.install.extraKernelArgs` | 1.12 | `customization.extraKernelArgs` in your Talos Schematic |
| `machine.network.kubespan` | 1.13 (if "Enable Kubespan" is checked) | `KubeSpanConfig` |
| `machine.install` | 1.14 | Remove it. Talos Manager sets the install disk. |
| `machine.kubelet` | 1.14 | `KubeletConfig`, `extraMounts` become a `UserVolumeConfig` |
| `machine.nodeLabels`, `machine.nodeTaints` | 1.14 | `KubeNodeConfig` |
| `machine.network.nameservers` | 1.14 | `ResolverConfig` |
| `machine.features.hostDNS` | 1.14 | `ResolverConfig` |
| `machine.files` | 1.14 (deprecation warning, fails strict validation) | Dedicated config documents |
| `cluster.apiServer` | 1.14 | `KubeAPIServerConfig`, OIDC flags become `KubeAuthenticationConfig` |
| `cluster.controllerManager` | 1.14 | `KubeControllerManagerConfig` |
| `cluster.scheduler` | 1.14 | `KubeSchedulerConfig` |
| `cluster.proxy` | 1.14 | `KubeProxyConfig` |
| `cluster.network` | 1.14 | `KubeNetworkConfig`, `KubeFlannelCNIConfig` |
| `cluster.allowSchedulingOnControlPlanes` | 1.14 | Remove the control plane taint via `KubeNodeConfig` |
| `cluster.aescbcEncryptionSecret`, `cluster.secretboxEncryptionSecret` | 1.14 | Remove them, see [Etcd encryption](#etcd-encryption) |

These legacy fields are deprecated but still accepted on Talos 1.14: `machine.network.interfaces` (including VLANs), `machine.sysctls`, `machine.registries`, `machine.systemDiskEncryption`, `machine.logging`, `machine.features.kubernetesTalosAPIAccess`, `machine.time`, `machine.env`, `machine.certSANs`, `machine.kernel`, `cluster.etcd`, `cluster.externalCloudProvider` and `cluster.inlineManifests`. Migrating them is optional, eg. `machine.sysctls` becomes:

```yaml
apiVersion: v1alpha1
kind: SysctlConfig
params:
  vm.max_map_count: "262144"
```

### How patches merge with config documents

A patch can contain multiple YAML documents separated by `---`, mixing the legacy `machine:` / `cluster:` format with config documents. Each config document is merged into the generated document of the same `kind` (and `name`), eg:

```yaml
machine:
  sysctls:
    vm.max_map_count: "262144"
---
apiVersion: v1alpha1
kind: ResolverConfig
hostDNS:
  resolveMemberNames: true
```

Things to be aware of:
- Lists inside documents are appended to, not replaced. To replace a generated document, delete it and add it back in the same patch:
  ```yaml
  apiVersion: v1alpha1
  kind: KubeEtcdEncryptionConfig
  $patch: delete
  ---
  apiVersion: v1alpha1
  kind: KubeEtcdEncryptionConfig
  config:
    ...
  ```
- Some fields are replaced as a whole by a patch, eg. `configuration` in `KubeAuthenticationConfig`. You then need to repeat the defaults you want to keep.
- Documents which only exist on control planes (`KubeAPIServerConfig`, `KubeAuthenticationConfig`, `KubeEtcdEncryptionConfig` etc.) belong in the control plane patch.

### Hostname

Talos Manager sets each server's hostname to the hostname chosen when configuring it, using a `HostnameConfig` document for Talos 1.12+. Remove any `hostname: ${hostname}` from your patches. Saving a Config which sets the hostname fails validation. The `${hostname}` substitution variable can still be used elsewhere.

### Kernel args

From Talos 1.12, kernel args are taken from the boot image rather than the machine config. Move `machine.install.extraKernelArgs` to the Schematic YAML on the Talos Schematics page:

```yaml
customization:
  extraKernelArgs:
    - cpufreq.default_governor=performance
```

New servers get the kernel args when bootstrapped. Existing nodes get them on their next upgrade to an image with the updated schematic. Verify with `talosctl read /proc/cmdline -n <node>`.

### Install disk

Remove the whole `machine.install` section, including any `diskSelector` using `${bootstrap_disk_wwid}`. Talos Manager generates the install disk selection as part of the `UnattendedInstallConfig` document. For servers bootstrapped by Talos Manager it isn't used anyway, since Talos skips installation on an already installed system, and upgrades install to the disk Talos booted from.

### DNS

Move `machine.network.nameservers` and `machine.features.hostDNS` into a single `ResolverConfig` document. `enabled` and `forwardKubeDNSToHost` are already enabled in the generated `ResolverConfig`, so only set what you changed from the defaults:

```yaml
apiVersion: v1alpha1
kind: ResolverConfig
nameservers:
  - address: 8.8.8.8
  - address: 1.1.1.1
hostDNS:
  resolveMemberNames: true
```

### KubeSpan

If "Enable Kubespan" is checked for the Config, move additional KubeSpan settings to a `KubeSpanConfig` document:

```yaml
apiVersion: v1alpha1
kind: KubeSpanConfig
enabled: true
advertiseKubernetesNetworks: true
mtu: 1320
```

### OpenEBS LocalPV directory

`KubeletConfig` has no equivalent of `machine.kubelet.extraMounts`. Instead, create a directory user volume:

```yaml
apiVersion: v1alpha1
kind: UserVolumeConfig
name: openebs-local
volumeType: directory
```

Talos mounts user volumes at `/var/mnt/<name>`, which kubelet already has access to. Hence the OpenEBS hostpath `BasePath` in your StorageClass must change from `/var/openebs/local` to `/var/mnt/openebs-local`:

```yaml
cas.openebs.io/config: |
  - name: StorageType
    value: hostpath
  - name: BasePath
    value: /var/mnt/openebs-local
```

Existing persistent volumes keep their original path. Before changing the StorageClass, add the `UserVolumeConfig` to existing nodes as well (eg. with `talosctl patch machineconfig`), since new volumes may be scheduled on them. Verify by writing to a test PVC.

### Other kubelet and Kubernetes component settings

`extraArgs` move to the documents of each component, eg:

```yaml
apiVersion: v1alpha1
kind: KubeletConfig
extraArgs:
  max-pods: "200"
```

The same goes for `KubeAPIServerConfig`, `KubeControllerManagerConfig` and `KubeSchedulerConfig`. Node labels and taints move to `KubeNodeConfig`:

```yaml
apiVersion: v1alpha1
kind: KubeNodeConfig
labels:
  example.com/role: database
taints:
  role: database:NoSchedule
```

To disable kube-proxy, use `enabled: false` in `KubeProxyConfig`. To replace the default Flannel CNI, delete the generated `KubeFlannelCNIConfig` document with `$patch: delete`.

### OIDC

kube-apiserver now always runs with `--authentication-config`, which rejects the `--oidc-*` flags. Move them to the `KubeAuthenticationConfig` document in the control plane patch. Since a patch replaces `configuration` as a whole, it must repeat Talos's default `anonymous` section:

```yaml
apiVersion: v1alpha1
kind: KubeAuthenticationConfig
configuration:
  anonymous:
    enabled: true
    conditions:
      - path: /livez
      - path: /readyz
      - path: /healthz
  jwt:
    - issuer:
        url: https://accounts.google.com # --oidc-issuer-url
        audiences:
          - <client-id> # --oidc-client-id
      claimMappings:
        username:
          claim: email # --oidc-username-claim
          prefix: "" # required when claim is set, "" matches the old flag behaviour for the email claim
```

### Etcd encryption

On Talos 1.14 `talosctl gen config` generates a `KubeEtcdEncryptionConfig` document from the cluster's secrets bundle, so remove `aescbcEncryptionSecret` and `secretboxEncryptionSecret` from your patches. What gets generated depends on the bundle (shown via "Show secrets" when editing the cluster):

**The bundle has `secretboxencryptionsecret`:** the document contains only the `secretbox` provider. Legacy configs also included `identity` and, if your patch set `aescbcEncryptionSecret`, an `aescbc` provider. A new control plane can't read Secrets stored with those. Check what your running control planes use with `talosctl read /system/secrets/kubernetes/kube-apiserver/encryptionconfig.yaml -n <control-plane>`. If `secretbox` isn't the only provider, rewrite all Secrets with the first one before bootstrapping control planes with the new config:

```bash
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

This only rewrites Secrets that aren't already stored with the first provider. If you run Argo CD, check `argocd-secret` afterwards: rewriting it can cause Argo CD's next sync of its own Application to empty it. Restarting `argocd-server` regenerates its keys.

**The bundle only has `aescbcencryptionsecret`** (clusters created before Talos generated secretbox keys): `talosctl` 1.14 incorrectly puts the aescbc key under a `secretbox` provider. Replace the generated document in the control plane patch with what your running control planes use, eg:

```yaml
apiVersion: v1alpha1
kind: KubeEtcdEncryptionConfig
$patch: delete
---
apiVersion: v1alpha1
kind: KubeEtcdEncryptionConfig
config:
  resources:
    - resources:
        - secrets
      providers:
        - aescbc:
            keys:
              - name: key1
                secret: <aescbcencryptionsecret from the bundle>
        - identity: {}
```

Alternatively rotate the running control planes to a secretbox key, which makes the generated document correct without any patch. Using `talosctl patch machineconfig --mode=no-reboot` on one control plane at a time (kube-apiserver restarts automatically):
1. Remove `cluster.aescbcEncryptionSecret` (`$patch: delete`) and add a `KubeEtcdEncryptionConfig` with the providers `aescbc key1`, `secretbox key2` (a new key from `head -c 32 /dev/urandom | base64`), `identity`. Every control plane can now read secretbox, but still writes aescbc.
2. Replace the document with the providers in the order `secretbox key2`, `aescbc key1`, `identity` to write with secretbox.
3. Rewrite all Secrets with `kubectl get secrets --all-namespaces -o json | kubectl replace -f -` (see the Argo CD note above).
4. Replace the document with only `secretbox key2`.

Then replace `aescbcencryptionsecret` in the cluster's secrets bundle with `secretboxencryptionsecret: <key2>`. After each step, check `talosctl read /system/secrets/kubernetes/kube-apiserver/encryptionconfig.yaml` on every control plane before continuing, and don't bootstrap control planes until the rotation is complete.

### Secrets bundle

The `talosctl` version bundled with Talos Manager (1.14 or later) refuses secrets bundles without an encryption key, regardless of the target Talos version:

```
one of [secrets.secretboxencryptionsecret, secrets.aescbcencryptionsecret] is required
```

The bundle keys are all lowercase. A camelCase `aescbcEncryptionSecret` (the machine config field name) in the bundle is ignored. Rename it to `aescbcencryptionsecret`.

### RAID

From Talos 1.14 mdadm is built into Talos and the `siderolabs/mdadm` extension does nothing. Once all your nodes run Talos 1.14 or later you can remove it from your schematics. Keep it for servers bootstrapped with older Talos versions.
