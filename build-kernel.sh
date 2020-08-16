#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(realpath "$(dirname "$0")")

CACHE_DIR=${CACHE_DIR:?}
OUTPUT_DIR=${OUTPUT_DIR:?}
KERNEL_VERSION=${KERNEL_VERSION:?}
MAKE_JOBS=${MAKE_JOBS:-4}
KERNEL_ARCH=arm64
KERNEL_COMPILER=aarch64-linux-gnu-
KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz

install_deps() {
	apt-get update
	apt-get install --yes --no-install-recommends \
		bc \
		bison \
		build-essential \
		ca-certificates \
		ccache \
		curl \
		flex \
		gcc-aarch64-linux-gnu \
		kmod \
		libssl-dev \
		make \
		xz-utils
}

kernel_make() {
	make -j "$MAKE_JOBS" ARCH=$KERNEL_ARCH CROSS_COMPILE="ccache $KERNEL_COMPILER" "$@"
}

build_kernel() {
    local archive_path
    archive_path=$CACHE_DIR/$(basename "$KERNEL_URL")
    if [ ! -r "$archive_path" ] ; then
        curl -Lo "$archive_path" "$KERNEL_URL"
    fi
    local src_path
    src_path=/tmp/linux-$KERNEL_VERSION
    rm -rf "$src_path"
    tar -xf "$archive_path" -C /tmp
    (
        cd "$src_path"
        cp "$SCRIPT_DIR/config/kernel/config" "$src_path/.config"
        rm -rf /tmp/boot
        rm -rf /tmp/lib
        mkdir -p /tmp/boot
        mkdir -p /tmp/lib
        kernel_make Image dtbs modules
        kernel_make Image.gz
        kernel_make INSTALL_DTBS_PATH=/tmp/boot/dtb INSTALL_PATH=/tmp/boot INSTALL_MOD_PATH=/tmp \
        	zinstall dtbs_install modules_install
        ln -s "vmlinuz-$KERNEL_VERSION" /tmp/boot/vmlinuz
    )
    (
    	cd /tmp
    	rm -rf "$OUTPUT_DIR/kernel-$KERNEL_VERSION.tar"
    	tar -cf "$OUTPUT_DIR/kernel-$KERNEL_VERSION.tar" boot lib
    )
}

install_deps
build_kernel
