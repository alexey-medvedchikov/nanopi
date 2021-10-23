#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(realpath "$(dirname "$0")")

CACHE_DIR=${CACHE_DIR:?}
OUTPUT_DIR=${OUTPUT_DIR:?}
KERNEL_VERSION=${KERNEL_VERSION:?}
DEBIAN_VERSION=${DEBIAN_VERSION:?}
ROOTFS=/tmp/rootfs

INCLUDE_PACKAGES=(
    apt-transport-https
    ca-certificates
    curl
    dbus
    dropbear
    e2fsprogs
    gnupg2
    htop
    ifupdown
    initramfs-tools
    iproute2
    iptables
    less
    locales
    localepurge
    logrotate
    nano
    net-tools
    procps
    python3
    sudo
    systemd
    systemd-sysv
    util-linux
)

function join_by {
    local d=$1
    shift
    local f=$1
    shift
    printf %s "$f" "${@/#/$d}"
}

install_deps() {
    apt-get update
    apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        binfmt-support \
        debootstrap \
        qemu \
        qemu-system-arm \
        qemu-user-static \
        u-boot-tools
}

inrootfs() {
    chroot "$ROOTFS" "$@"
}

build_rootfs() {
    rm -rf "$ROOTFS"
    mkdir -p "$ROOTFS"
    local include_packages
    include_packages=$(join_by , "${INCLUDE_PACKAGES[@]}")
    debootstrap --arch=arm64 --variant=minbase --include="$include_packages" buster "$ROOTFS"
    tar -xhf "$OUTPUT_DIR/kernel-$KERNEL_VERSION.tar" -C "$ROOTFS"
    cp "$SCRIPT_DIR/config/uboot/boot.env" "$ROOTFS/boot/"
    cp "$SCRIPT_DIR/config/uboot/boot.cmd" "$ROOTFS/boot/"
    mkimage -A arm -C gzip -T script -d "$ROOTFS/boot/boot.cmd" "$ROOTFS/boot/boot.scr"
    inrootfs mount -t proc none /proc
    inrootfs mount -t sysfs none /sys
    inrootfs update-initramfs -c -k "$KERNEL_VERSION"
    inrootfs umount /proc
    inrootfs umount /sys
    mkimage -A arm -O linux -C none -T ramdisk -d "$ROOTFS/boot/initrd.img-$KERNEL_VERSION" "$ROOTFS/boot/initramfs-$KERNEL_VERSION"
    inrootfs ln -s "initramfs-$KERNEL_VERSION" /boot/initramfs
    inrootfs rm -rf "/boot/initrd.img-$KERNEL_VERSION"
}

customize_rootfs() {
    (
        cd "$SCRIPT_DIR/config/rootfs"
        install -o root -g root -m 0644 \
            resolv.conf \
            hostname \
            hosts \
            fstab \
            "$ROOTFS/etc/"
        install -o root -g root -m 0644 interfaces "$ROOTFS/etc/network/"
        mkdir -p "$ROOTFS/root/.ssh/"
        install -o root -g root -m 0644 id_rsa.pub "$ROOTFS/root/.ssh/authorized_keys"
        install -o root -g root -m 0755 mac-customize "$ROOTFS/usr/local/bin/"
        install -o root -g root -m 0644 mac-customize.service "$ROOTFS/etc/systemd/system/"
        install -o root -g root -m 0644 modules-load.d/br_netfilter.conf "$ROOTFS/etc/modules-load.d/"
        install -o root -g root -m 0644 sysctl.d/ipv4_forward.conf "$ROOTFS/etc/sysctl.d/"
    )
    inrootfs systemctl enable mac-customize.service
    # debian:debian
    inrootfs useradd -G sudo -U -m -p 8jVgL5t.kdCbU debian
    inrootfs chsh --shell /bin/bash debian
    inrootfs locale-gen --purge en_US.UTF-8
    echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US:en"\n' > "$ROOTFS/etc/default/locale"
    echo -e 'MANDELETE\nDONTBOTHERNEWLOCALE\nSHOWFREEDSPACE\nen_US.UTF-8' > "$ROOTFS/etc/locale.nopurge"
}

prune_rootfs() {
    inrootfs apt-get clean
    inrootfs localepurge
    find "$ROOTFS/var/lib/apt/lists/" -type f -delete
}

pack_rootfs() {
    (
        cd "$ROOTFS"
        tar -cf "$OUTPUT_DIR/rootfs.tar" ./*
    )
}

install_deps
build_rootfs
customize_rootfs
prune_rootfs
pack_rootfs
