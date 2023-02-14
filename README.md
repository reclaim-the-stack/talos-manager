# devops-talos-manager

App built to help bootstrap and manage Talos Linux servers.

Based on using the `talos.config` kernel parameter. You can apply this inside the grub config of the talos metal image. Ie. write it to disk with `dd` and then `mount /dev/nvme0n1p3 /mnt` followed by `vi /mnt/grub/grub.cfg`.

The value should be eg:
```
talos.config=https://<subdomain>.eu.ngrok.io/config?uuid=${uuid}
```