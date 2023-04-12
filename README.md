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

Apart from deploying the application you'll also need to deploy a Postgres database and configure some ENV variables:

- `DATABASE_URL` - a postgres URL for the postgresql database
- `BASIC_AUTH_PASSWORD` - simple way of securing access to the application via HTTP basic auth
- `HETZNER_CLOUD_API_TOKEN` - a read + write Hetzner cloud API token
- `HOST` - the hostname on which you are deploying this app (eg. `talos-manager.yourdomain.com`)
- `SSH_PRIVATE_KEY` - a private key used to connect to servers for bootstrapping, the public key must be added to Hetzner Robot as well as Hetzner Cloud with a name including `talos-manager`

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
