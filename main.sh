#!/bin/sh

set -eu

SCRIPT_DIR=$(pwd)

BASE_DIR=$SCRIPT_DIR/
CACHE_DIR=$SCRIPT_DIR/cache
ROOTFS=$CACHE_DIR/rootfs

KERNEL_ARCH=arm64
U_BOOT_ARCH=arm
ROOT_ARCH=aarch64
KERNEL_COMPILER=aarch64-none-linux-gnu-
KERNEL_VERSION=5.9.3
KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz

create_rootfs() {
	for i in etcd etcdctl ; do
		cp "$CACHE_DIR/etcd/$i" "$ROOTFS/usr/local/bin/"
	done
    for i in kube-apiserver kubelet kube-controller-manager kubectl kube-scheduler kube-proxy ; do
    	cp "$CACHE_DIR/kubernetes/$i" "$ROOTFS/usr/local/bin/"
    done
    cp "$BASE_DIR/config/inittab" "$ROOTFS/etc/"
    cp "$BASE_DIR/config/interfaces" "$ROOTFS/etc/network/"
    cp "$BASE_DIR/config/sudoers" "$ROOTFS/etc/"

    chroot "$ROOTFS" useradd --system -M etcd
	cp "$BASE_DIR/config/etcd/etcd.confd" "$ROOTFS/etc/conf.d/etcd"
    cp "$BASE_DIR/config/etcd/etcd.initd" "$ROOTFS/etc/init.d/etcd"
    mkdir -p "$ROOTFS/etc/etcd"
    cp "$BASE_DIR/config/etcd/etcd.yaml" "$ROOTFS/etc/etcd/etcd.yaml"
    chmod a+x "$ROOTFS/etc/init.d/etcd"

    cp "$BASE_DIR/config/containerd/containerd.confd" "$ROOTFS/etc/conf.d/containerd"
    cp "$BASE_DIR/config/containerd/containerd.initd" "$ROOTFS/etc/init.d/containerd"
    cp "$BASE_DIR/config/containerd/containerd.logrotate" "$ROOTFS/etc/logrotate.d/containerd"
    chmod a+x "$ROOTFS/etc/init.d/containerd"
}

bootstrap_in_chroot() {
	apk add --no-cache \
    	bash \
    	cni-plugins@community \
    	containerd@community \
        curl \
        dropbear \
        e2fsprogs \
        htop \
        iproute2 \
        iptables \
        logrotate \
        mkinitfs \
        nano \
        rsyslog \
        shadow \
        sudo
}
