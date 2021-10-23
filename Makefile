#!/usr/bin/env make -f

SHELL := /bin/bash

IMAGE := nanopi:build
PWD := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
MAKE_JOBS := $(shell grep -c processor /proc/cpuinfo)

KERNEL_VERSION := 5.16.2
DEBIAN_VERSION := buster

output/kernel-$(KERNEL_VERSION).tar:
	docker run \
		-e KERNEL_VERSION=$(KERNEL_VERSION) \
		-e MAKE_JOBS=$(MAKE_JOBS) \
		-e CCACHE_DIR=/workdir/cache/ccache \
		-e CACHE_DIR=/workdir/cache \
		-e OUTPUT_DIR=/workdir/output \
		-v $(shell pwd):/workdir \
		-w /workdir \
		-t -i \
		debian:buster \
		bash -x build-kernel.sh

.PHONY: kernel-term
kernel-term:
	docker run \
		-e KERNEL_VERSION=$(KERNEL_VERSION) \
		-e MAKE_JOBS=$(MAKE_JOBS) \
		-e CCACHE_DIR=/workdir/cache/ccache \
		-e CACHE_DIR=/workdir/cache \
		-e OUTPUT_DIR=/workdir/output \
		-v $(shell pwd):/workdir \
		-w /workdir \
		-t -i \
		debian:buster \
		bash

.PHONY: kernel
kernel: output/kernel-$(KERNEL_VERSION).tar

output/rootfs.tar: output/kernel-$(KERNEL_VERSION).tar
	docker run \
		--privileged \
		-e KERNEL_VERSION=$(KERNEL_VERSION) \
		-e DEBIAN_VERSION=$(DEBIAN_VERSION) \
		-e CACHE_DIR=/workdir/cache \
		-e OUTPUT_DIR=/workdir/output \
		-v $(shell pwd):/workdir \
		-w /workdir \
		-t -i \
		debian:buster \
		bash -x build-rootfs.sh

.PHONY: rootfs
rootfs: output/rootfs.tar
