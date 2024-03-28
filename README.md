# Talos Manager

App built to help bootstrap and manage Talos Linux servers on Hetzner.

## Approach

Based on bootstrapping nodes via the `talos.config` kernel parameter (https://www.talos.dev/latest/reference/kernel/#talosconfig). This can be applied inside the Grub config of a Talos installation image. By writing the image to disk with `dd` and then mounting the boot partition we can inject the parameter into its `grub/grub.cfg`.

Example of passing a URL into the talos.config parameter:

```
talos.config=https://talos-manager.example.com/config?uuid=${uuid}
```

## Deploying

Feel free to deploy the application using our published container images at https://hub.docker.com/r/reclaimthestack/talos-manager/tags

Apart from deploying the application you'll also need to deploy a Postgres database and configure some ENV variables. Follow the SSH key and Heroku deployment instructions and apply the same ENV variables in whatever environment you're deploying on.

### Creating an SSH key and upload to Hetzner

Talos Manager will bootstrap servers by putting servers into Rescue Mode and then running commands on the servers via SSH. We need an SSH key configured for this.

Note: Due to Ruby's `net-ssh` library not being compatible with OpenSSL3 private keys we need to make sure we generate the private key in PEM format.

```
ssh-keygen -m PEM -t rsa -P "" -f ~/.ssh/talos-manager.pem -C talos-manager
```

Now add the public key (`cat ~/.ssh/talos-manager.pem.pub`) with the name `talos-manager` at:
- Hetzner Robot at https://robot.hetzner.com/key/index -> New key
- Hetzner Cloud at https://console.hetzner.cloud/ -> Select Project -> Security -> Add SSH Key

### Deploying on Heroku

First we'll create a Heroku application where we can deploy Talos Manager. For Postgres we'll use the `crunchy-postgres:hobby-1` costing $30/month. This plan provides continuous data protection and point in time recovery. If you plan to manually backup your postgres database you can also consider using `heroku-postgres:mini` at $5/month.

```
heroku create --stack container --region <eu/us> --addons crunchy-postgres:hobby-1 [--team <heroku-account>] <name-of-application>
```

Now clone the talos-manager repository and connect it to the heroku repository.

```
git clone https://github.com/reclaim-the-stack/talos-manager.git
cd talos-manager
heroku git:remote -a <name-of-application>
```

Now we can configure the application.

```
# We'll start by setting some standard Rails variables
function random_string() { cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1; }

heroku config:set \
  RAILS_ENV=production \
  RAILS_MAX_THREADS=20 \
  SECRET_KEY_BASE=$(random_string) \
  AR_ENCRYPTION_PRIMARY_KEY=$(random_string) \
  AR_ENCRYPTION_DETERMINISTIC_KEY=$(random_string) \
  AR_ENCRYPTION_KEY_DERIVATION_SALT=$(random_string)

# Rails expects DATABASE_URL to connect to Postgres but crunchy uses CRUNCHY_DATABASE_URL
heroku config:set DATABASE_URL=$(heroku config:get CRUNCHY_DATABASE_URL)

# Manage Hetzner cloud API token at:
# https://console.hetzner.cloud -> Project -> Security -> API Tokens
# If you're not planning to use Hetzner cloud servers you can skip this part.
heroku config:set HETZNER_CLOUD_API_TOKEN=<hetzner-cloud-api-token>

# Manage Hetzner webservice API credentials at:
# https://robot.hetzner.com/preferences/index -> Webservice and app settings
# If you're not planning to use dedicated servers you can skip this part.
heroku config:set HETZNER_WEBSERVICE_USER=<username> HETZNER_WEBSERVICE_PASSWORD=<password>

# For application host you have two options:

# 1. Deploy to your own domain
# Full documentation at https://devcenter.heroku.com/articles/custom-domains
heroku domains:add <your-custom-url>
heroku config:set HOST=<your-custom-url>

# 2. Deploy to a Heroku subdomain
# For this you'll want to enable the runtime-dyno-metadata lab feature which will provide us
# with the HEROKU_APP_DEFAULT_DOMAIN_NAME environment variable.
heroku labs:enable runtime-dyno-metadata
heroku config:set HOST=$(heroku config:get HEROKU_APP_DEFAULT_DOMAIN_NAME)

# Assumes you created the SSH key for bootstrapping according to the instructions above
heroku config:set SSH_PRIVATE_KEY="$(cat ~/.ssh/talos-manager.pem)"

# Set a HTTP basic auth password to protect the app
heroku config:set BASIC_AUTH_PASSWORD=$(random_string)
```

Confirm that the Crunchy Postgres cluster is in ready status. This can take a few minutes after initial creation.

```
# If you can successfully psql to the database you're good to go
psql $(heroku config:get DATABASE_URL)

# If psql failed you can track the cluster status in the crunchy postgres dashboard
heroku addons:open crunchy-postgres
```

Once Postgres is ready, we're can go ahead and git push to build and deploy the application 🚀

```
git push heroku
```

Once the build has completed you should be able to access Talos Manager at `<name>.herokuapp.com` with the `BASIC_AUTH_PASSWORD` value as password.

#### Deploying with a specific talos version

If you need to support a legacy version of Talos you can set the `TALOS_AMD64_IMAGE_URL` and `TALOS_ARM64_IMAGE_URL` ENV variables to point to the specific version you need. You will also need to manually build the docker container using the `TALOS_VERSION` build arg. Eg:

```
docker build --platform linux/amd64 --build-arg TALOS_VERSION=1.3.7 -t registry.heroku.com/<heroku-app-name>/web .
docker push registry.heroku.com/<heroku-app-name>/web
heroku container:release web --app <heroku-app-name>
```

## Config Patch Examples

### Basic

As a baseline config we recommend:
- setting the Linux CPU governor to `performance` to ensure you're not missing out on performance
- setting `network.hostname` to interpolate the servername
- setting `vm.max_map_count` to `262144` (or higher) to avoid issues with eg. Elastic Search

```yaml
machine:
  install:
    extraKernelArgs:
      - cpufreq.default_governor=performance
  network:
    hostname: ${hostname}
  sysctls:
    vm.max_map_count: 262144 # Increase max_map_count required by eg. elasticsearch
```

### KubeSpan Network

This patch will enable Talos [KubeSpan](https://www.talos.dev/v1.4/kubernetes-guides/network/kubespan/) and also allow KubeSpan to run the pod - pod network via the `advertiseKubernetesNetworks` setting. This allows simplified hybrid cloud / metal node networking (eg. cloud nodes using public IP's can communicate with bare metal nodes on a private VLAN).

```yaml
machine:
  network:
    kubespan:
      enabled: true
      advertiseKubernetesNetworks: true
      mtu: 1320 # should be 80 less than the underlying network, which is 1400 on Hetzner VLAN
```

### Disk Encryption

Talos supports disk encryption based on SMBIOS UUID of each server. This provides an easy way to get encryption at rest for all your nodes.

```yaml
machine:
  systemDiskEncryption:
    ephemeral:
      provider: luks2
      keys:
        - nodeID: {}
          slot: 0
    state:
      provider: luks2
      keys:
        - nodeID: {}
          slot: 0
```

### OpenEBS LocalPV directory

If you want to use the OpenEBS LocalPV local storage provider you need to add an extra mounted directory under `/var/openebs/local`.

```yaml
machine:
  kubelet:
    # OpenEBS LocalPV provisioner needs a directory available at /var/openebs/local
    extraMounts:
      - destination: /var/openebs/local
        options:
          - rbind
          - rshared
          - rw
        source: /var/openebs/local
        type: bind
```

### Providing access to a private Docker registry

For real world production deployments you're likely using a private Docker registry to manage your application images. One option to support pulling images from a private registry is to do it inside of Kubernetes using the `imagePullSecrets` Pod resource field. But to avoid extra boilerplate in your resource YAML files it can be convenient to provide access directly on the Talos OS level instead.

For a reference on all available fields for registry config see: https://www.talos.dev/v1.3/reference/configuration/#registriesconfig

```yaml
machine:
  registries:
    config:
      <registry-host>:
        auth:
          <auth-details>
```

### Configuring private network on a Hetzner vSwitch

To ease private network configuration you can make use of the `${private_ip}` and `${vlan}` substitution variables. The `vlan` number will be picked up from your Hetzner vSwitch, provided you have associated your cluster with one.

Note: We currently do not support hybrid cloud / metal server configuration when using this approach since the patches will be applied to cloud servers as well, which can't be connected to the vSwitch.

```yaml
machine:
  network:
    hostname: ${hostname}
    interfaces:
      - dhcp: true
        interface: eth0
        vlans:
          - addresses:
              - ${private_ip}/21
            mtu: 1400
            vlanId: ${vlan}
```

## Assigning node roles and taints

Example of setting the appropriate roles and taints for compatibility with the default Reclaim the Stack platform scheduling rules. Before running, ensure you are targeting the correct kubernetes cluster either by setting the `KUBECONFIG=...` ENV variable or merging the cluster `kubeconfig` into your `~/.kube/config` file.

```
kubectl label node worker-1 node-role.kubernetes.io/worker=
kubectl label node database-1 node-role.kubernetes.io/database=
kubectl taint node database-1 role=database:NoSchedule
```

Note: If you don't want to separate database workloads to specific nodes you can apply the database roles to your regular workers and skip adding the taints.

## Solving invalid UUID issues

We have had some occasions where a newly rented dedicated server did not come with a properly configured SMBIOS UUID. If Talos Manager encounters a node with an invalid UUID it will raise an error during bootstrapping. To fix the issue: Login to Hetzner Robot UI. Navigate to support and get support for the server which is having issues. Send them an email in the style of:

```
Hi,

We have found that this server has an invalid SMBIOS UUID.

When running `dmidecode -t system` the output is:
<insert-output-of-dmidecode>

Note the pending fields + the UUID ending with 0'es.

We need to have a proper UUID since our disk encryption scheme is based on the entropy
of this UUID and with the one present here it doesn't work.

Downtime for the serving while solving this is fine, we won't be making use of the server until we get this solved.
```
