#!/usr/bin/bash

set -euo pipefail

SCRIPT_DIR=$(realpath "$(dirname "$0")")

main() {
    local device=${1:?device not specified}

    if [[ ! -b "$device" ]]; then
        echo "Device $device doesn't exist"
        exit 1
    fi
    dd if=/dev/zero of="$device" oflag=direct bs=1M count=100
    bash "$SCRIPT_DIR/u-boot/platform_install.sh" "$SCRIPT_DIR/u-boot" "$device"
    parted "$device" mklabel msdos
    parted "$device" mkpart primary ext4 24M 100%
    blockdev --rereadpt "$device"
    mkfs.ext4 -L ROOT "${device}1"
    mount "${device}1" /mnt/
    rm -rf -- /mnt/*
    tar -xf "$SCRIPT_DIR/output/rootfs.tar" -C /mnt/
    sync
    umount /mnt
    fsck "${device}1"
}

main "$@"
