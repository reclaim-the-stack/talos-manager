- Auto sync once per minute or so
- Realtime bootstrapping log
- Better tracking of rescue mode
- Better tracking of bootstrapping
- Change name from Server::HetznerDedicated to Server::HetznerRobot
- Primary key on servers should probably be compound key of type + id in case robot and cloud servers end up sharing ID
- Support RAID

mdadm --create --verbose /dev/md0 --level=0 --raid-devices=2 /dev/nvme2n1 /dev/nvme0n1
mdadm --detail /dev/md0 # uuid:1a462672:bd83888c:df8fa57e:6b38f998
