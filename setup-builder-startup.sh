#!/bin/bash

# called on every startup

set -ex

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

systemctl stop docker
umount /ephemeral || true
sfdisk -f /dev/nvme1n1 <<EOF
label: dos
label-id: 0x7d7e658b
device: /dev/nvme1n1
unit: sectors

/dev/nvme1n1p1 : start=     3999744, size=   120999936, type=82
/dev/nvme1n1p2 : start=   124999680, size=   656248832, type=83
EOF
sync
sleep 2 # let the device get registered
mkswap /dev/nvme1n1p1
swapon /dev/nvme1n1p1
mkfs.ext4 -F /dev/nvme1n1p2
rm -rf /ephemeral
mkdir /ephemeral
mount /dev/nvme1n1p2 /ephemeral

cat >/etc/docker/daemon.json <<EOF
{
        "data-root": "/ephemeral/docker"
}
EOF

mount_opt() {
    mkdir -p /opt/compiler-explorer
    mountpoint /opt/compiler-explorer || mount --bind /efs/compiler-explorer /opt/compiler-explorer

    mkdir -p /opt/intel
    mountpoint /opt/intel || mount --bind /efs/intel /opt/intel

    mkdir -p /opt/arm
    mountpoint /opt/arm || mount --bind /efs/arm /opt/arm

    [ -f /opt/.health ] || touch /opt/.health
    mountpoint /opt/.health || mount --bind /efs/.health /opt/.health

    ./mount-all-img.sh
}

mount_opt

systemctl start docker
