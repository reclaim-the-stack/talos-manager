# Talos Manager

App built to help bootstrap and manage Talos Linux servers on Hetzner.

## Approach

Based on bootstrapping nodes via the `talos.config` kernel parameter (https://www.talos.dev/latest/reference/kernel/#talosconfig). You can apply this inside the Grub config of a Talos installation image. By write the image to disk with `dd` and then mounting the boot partition we can inject the parameter into its `grub/grub.cfg`.

Example of passing a URL into the talos.config parameter:

```
talos.config=https://talos-manager.example.com/config?uuid=${uuid}
```

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
