setenv kernel_comp_addr_r "0x8000000"
setenv kernel_comp_size "0xf00000"
setenv load_addr "0x9000000"
setenv overlay_error "false"

# default values
setenv rootdev "/dev/mmcblk0p1"
setenv rootfstype "ext4"
setenv consoleargs "earlycon console=ttyS2,1500000 consoleblank=0 loglevel=1"
setenv dockerargs "memory.use_hierarchy=1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1"
setenv extraargs "fsprotect=1G"
setenv fdtfile "rockchip/rk3328-rock64.dtb"
setenv image "vmlinuz"
setenv ramdisk "initramfs"

echo "Boot script loaded from ${devtype} ${devnum}"

load ${devtype} ${devnum} ${load_addr} ${prefix}boot.env
env import -t ${load_addr} ${filesize}

# get PARTUUID of first partition on SD/eMMC the boot script was loaded from
if test "${devtype}" = "mmc"; then part uuid mmc ${devnum}:1 partuuid; fi

setenv rootargs "root=${rootdev} rootwait rootfstype=${rootfstype} ubootpart=${partuuid}"
setenv bootargs " ${consoleargs} ${rootargs} ${dockerargs} ${extraargs}"

load ${devtype} ${devnum} ${ramdisk_addr_r} ${prefix}${ramdisk}
load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}${image}
load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}

fdt addr ${fdt_addr_r}
fdt resize 65536
for overlay_file in ${overlays}; do
	if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/rockchip/overlay/${overlay_prefix}-${overlay_file}.dtbo; then
		echo "Applying kernel provided DT overlay ${overlay_prefix}-${overlay_file}.dtbo"
		fdt apply ${load_addr} || setenv overlay_error "true"
	fi
done
for overlay_file in ${user_overlays}; do
	if load ${devtype} ${devnum} ${load_addr} ${prefix}overlay-user/${overlay_file}.dtbo; then
		echo "Applying user provided DT overlay ${overlay_file}.dtbo"
		fdt apply ${load_addr} || setenv overlay_error "true"
	fi
done
if test "${overlay_error}" = "true"; then
	echo "Error applying DT overlays, restoring original DT"
	load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
else
	if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/rockchip/overlay/${overlay_prefix}-fixup.scr; then
		echo "Applying kernel provided DT fixup script (${overlay_prefix}-fixup.scr)"
		source ${load_addr}
	fi
	if test -e ${devtype} ${devnum} ${prefix}fixup.scr; then
		load ${devtype} ${devnum} ${load_addr} ${prefix}fixup.scr
		echo "Applying user provided fixup script (fixup.scr)"
		source ${load_addr}
	fi
fi
booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
