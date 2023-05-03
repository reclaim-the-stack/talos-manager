# Bootstrapping Commands

If you're having trouble bootstrapping via the web applications here are some commands you can run manually from within rescue mode. Replace amd64 with arm64 in the Talos image download URL according to your architecture.

Hetzner bare metal:

```
mdadm --stop /dev/md[0-4] # if Raid is enabled
sfdisk --delete /dev/nvme0n1
wipefs -a -f /dev/nvme0n1
sfdisk --delete /dev/nvme1n1
wipefs -a -f /dev/nvme1n1
wget https://github.com/siderolabs/talos/releases/download/v1.3.7/metal-amd64.tar.gz --quiet -O - | tar xvfzO - | dd of=/dev/nvme0n1 status=progress
sync
mount /dev/nvme0n1p3 /mnt # assuming that p3 is the BOOT partition, can make sure with `gdisk /dev/nvme0n1` and `s` command
vi /mnt/grub/grub.cfg # add talos.config=https://<app-host>/config?uuid=${uuid}
umount /mnt
reboot
```

Hetzner cloud:

```
sfdisk --delete /dev/sda
wipefs -a -f /dev/sda
wget https://github.com/siderolabs/talos/releases/download/v1.3.7/metal-amd64.tar.gz --quiet -O - | tar xvfzO - | dd of=/dev/sda status=progress
sync
mount /dev/sda3 /mnt # assuming that sda3 is the BOOT partition
vi /mnt/grub/grub.cfg # add talos.config=https://<app-host>/config?uuid=${uuid}
umount /mnt
reboot
```