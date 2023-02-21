# devops-talos-manager

App built to help bootstrap and manage Talos Linux servers.

Based on using the `talos.config` kernel parameter. You can apply this inside the grub config of the talos metal image. Ie. write it to disk with `dd` and then `mount /dev/nvme0n1p3 /mnt` followed by `vi /mnt/grub/grub.cfg`.

The value should be eg:
```
talos.config=https://devops-talos-manager.mynewsdesk.dev/config?uuid=${uuid}
```

## Solving invalid UUID issues

Login to Hetzner robot UI. Navigate to support and get support for the server which is having issues. Send them an email in the style of:

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