#!/bin/sh

set -e

if [[ -f $1/rksd_loader.img ]]; then
    dd if=$1/rksd_loader.img of=$2 seek=64 conv=notrunc status=none > /dev/null 2>&1;
else
    if [[ -f $1/u-boot.itb ]]; then
        dd if=$1/idbloader.img of=$2 seek=64 conv=notrunc status=none > /dev/null 2>&1;
        dd if=$1/u-boot.itb of=$2 seek=16384 conv=notrunc status=none > /dev/null 2>&1;
    else
        if [[ -f $1/uboot.img ]]; then
            dd if=$1/idbloader.bin of=$2 seek=64 conv=notrunc status=none > /dev/null 2>&1;
            dd if=$1/uboot.img of=$2 seek=16384 conv=notrunc status=none > /dev/null 2>&1;
            dd if=$1/trust.bin of=$2 seek=24576 conv=notrunc status=none > /dev/null 2>&1;
        else
            echo "Unsupported u-boot processing configuration!";
            exit 1;
        fi;
    fi;
fi
