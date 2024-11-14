#!/bin/bash

set -euo pipefail

ROOTFS_PRISTINE=$1
ROOTFS=$2
MODULE_PLAYGROUND=$3
CONFIG_H=$4
SYSCONFDIR=$5
MODULE_DIRECTORY=$6

# create rootfs from rootfs-pristine

create_rootfs() {
	local -r SED_PATTERN="s|/lib/modules|$MODULE_DIRECTORY|g;s|$MODULE_DIRECTORY/external|/lib/modules/external|g"

	rm -rf "$ROOTFS"
	mkdir -p "$(dirname "$ROOTFS")"
	cp -r "$ROOTFS_PRISTINE" "$ROOTFS"
	find "$ROOTFS" -type d -exec chmod +w {} \;
	find "$ROOTFS" -type f -name .gitignore -exec rm -f {} \;
	if [ "$MODULE_DIRECTORY" != "/lib/modules" ] ; then
		find "$ROOTFS" \( -name '*.txt' -o -name '*.conf' -o -name '*.dep' \) -exec sed -i -e "$SED_PATTERN" {} +
		for i in "$ROOTFS"/*/lib/modules/* "$ROOTFS"/*/*/lib/modules/* ; do
			version="$(basename "$i")"
			[ "$version" != 'external' ] || continue
			mod="$(dirname "$i")"
			lib="$(dirname "$mod")"
			up="$(dirname "$lib")$MODULE_DIRECTORY"
			mkdir -p "$up"
			mv "$i" "$up"
		done
	fi

	if [ "$SYSCONFDIR" != "/etc" ]; then
		find "$ROOTFS" -type d -name etc -printf "%h\n" | while read -r e; do
			mkdir -p "$(dirname "$e/$SYSCONFDIR")"
			mv "$e"/{etc,"$SYSCONFDIR"}
		done
	fi
}

feature_enabled() {
	local feature=$1
	grep KMOD_FEATURES "$CONFIG_H" | head -n 1 | grep -q \+"$feature"
}

declare -A map
map=(
    ["test-depmod/search-order-simple$MODULE_DIRECTORY/4.4.4/kernel/crypto/"]="mod-simple.ko"
    ["test-depmod/search-order-simple$MODULE_DIRECTORY/4.4.4/updates/"]="mod-simple.ko"
    ["test-depmod/search-order-same-prefix$MODULE_DIRECTORY/4.4.4/foo/"]="mod-simple.ko"
    ["test-depmod/search-order-same-prefix$MODULE_DIRECTORY/4.4.4/foobar/"]="mod-simple.ko"
    ["test-depmod/detect-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-a.ko"]="mod-loop-a.ko"
    ["test-depmod/detect-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-b.ko"]="mod-loop-b.ko"
    ["test-depmod/detect-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-c.ko"]="mod-loop-c.ko"
    ["test-depmod/detect-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-d.ko"]="mod-loop-d.ko"
    ["test-depmod/detect-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-e.ko"]="mod-loop-e.ko"
    ["test-depmod/detect-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-f.ko"]="mod-loop-f.ko"
    ["test-depmod/detect-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-g.ko"]="mod-loop-g.ko"
    ["test-depmod/detect-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-h.ko"]="mod-loop-h.ko"
    ["test-depmod/detect-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-i.ko"]="mod-loop-i.ko"
    ["test-depmod/detect-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-j.ko"]="mod-loop-j.ko"
    ["test-depmod/detect-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-k.ko"]="mod-loop-k.ko"
    ["test-depmod/search-order-external-first$MODULE_DIRECTORY/4.4.4/foo/"]="mod-simple.ko"
    ["test-depmod/search-order-external-first$MODULE_DIRECTORY/4.4.4/foobar/"]="mod-simple.ko"
    ["test-depmod/search-order-external-first/lib/modules/external/"]="mod-simple.ko"
    ["test-depmod/search-order-external-last$MODULE_DIRECTORY/4.4.4/foo/"]="mod-simple.ko"
    ["test-depmod/search-order-external-last$MODULE_DIRECTORY/4.4.4/foobar/"]="mod-simple.ko"
    ["test-depmod/search-order-external-last/lib/modules/external/"]="mod-simple.ko"
    ["test-depmod/search-order-override$MODULE_DIRECTORY/4.4.4/foo/"]="mod-simple.ko"
    ["test-depmod/search-order-override$MODULE_DIRECTORY/4.4.4/override/"]="mod-simple.ko"
    ["test-depmod/check-weakdep$MODULE_DIRECTORY/4.4.4/kernel/mod-weakdep.ko"]="mod-weakdep.ko"
    ["test-depmod/check-weakdep$MODULE_DIRECTORY/4.4.4/kernel/mod-simple.ko"]="mod-simple.ko"
    ["test-depmod/test-dependencies/lib/modules/4.4.4/kernel/fs/foo/"]="mod-foo-a.ko"
    ["test-depmod/test-dependencies/lib/modules/4.4.4/kernel/"]="mod-foo-c.ko"
    ["test-depmod/test-dependencies/lib/modules/4.4.4/kernel/lib/"]="mod-foo-b.ko"
    ["test-depmod/test-dependencies/lib/modules/4.4.4/kernel/fs/"]="mod-foo.ko"
    ["test-depmod/test-dependencies-1/lib/modules/4.4.4/kernel/fs/foo/"]="mod-foo-a.ko"
    ["test-depmod/test-dependencies-1/lib/modules/4.4.4/kernel/"]="mod-foo-c.ko"
    ["test-depmod/test-dependencies-1/lib/modules/4.4.4/kernel/lib/"]="mod-foo-b.ko"
    ["test-depmod/test-dependencies-1/lib/modules/4.4.4/kernel/fs/mod-foo.ko"]="mod-foo.ko"
    ["test-depmod/test-dependencies-1/lib/modules/4.4.4/kernel/fs/mod-bar.ko"]="mod-bar.ko"
    ["test-depmod/test-dependencies-2/lib/modules/4.4.4/kernel/fs/foo/"]="mod-foo-a.ko"
    ["test-depmod/test-dependencies-2/lib/modules/4.4.4/kernel/"]="mod-foo-c.ko"
    ["test-depmod/test-dependencies-2/lib/modules/4.4.4/kernel/lib/"]="mod-foo-b.ko"
    ["test-depmod/test-dependencies-2/lib/modules/4.4.4/kernel/fs/mod-foo.ko"]="mod-foo.ko"
    ["test-depmod/test-dependencies-2/lib/modules/4.4.4/kernel/fs/mod-bah.ko"]="mod-bar.ko"
    ["test-dependencies$MODULE_DIRECTORY/4.0.20-kmod/kernel/fs/foo/"]="mod-foo-b.ko"
    ["test-dependencies$MODULE_DIRECTORY/4.0.20-kmod/kernel/"]="mod-foo-c.ko"
    ["test-dependencies$MODULE_DIRECTORY/4.0.20-kmod/kernel/lib/"]="mod-foo-a.ko"
    ["test-dependencies$MODULE_DIRECTORY/4.0.20-kmod/kernel/fs/"]="mod-foo.ko"
    ["test-init/"]="mod-simple.ko"
    ["test-remove/"]="mod-simple.ko"
    ["test-modprobe/show-depends$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-a.ko"]="mod-loop-a.ko"
    ["test-modprobe/show-depends$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-b.ko"]="mod-loop-b.ko"
    ["test-modprobe/show-depends$MODULE_DIRECTORY/4.4.4/kernel/mod-simple.ko"]="mod-simple.ko"
    ["test-modprobe/show-exports/mod-loop-a.ko"]="mod-loop-a.ko"
    ["test-modprobe/softdep-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-a.ko"]="mod-loop-a.ko"
    ["test-modprobe/softdep-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-b.ko"]="mod-loop-b.ko"
    ["test-modprobe/weakdep-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-a.ko"]="mod-loop-a.ko"
    ["test-modprobe/weakdep-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-b.ko"]="mod-loop-b.ko"
    ["test-modprobe/weakdep-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-simple.ko"]="mod-simple.ko"
    ["test-modprobe/install-cmd-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-a.ko"]="mod-loop-a.ko"
    ["test-modprobe/install-cmd-loop$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-b.ko"]="mod-loop-b.ko"
    ["test-modprobe/force$MODULE_DIRECTORY/4.4.4/kernel/"]="mod-simple.ko"
    ["test-modprobe/oldkernel$MODULE_DIRECTORY/3.3.3/kernel/"]="mod-simple.ko"
    ["test-modprobe/oldkernel-force$MODULE_DIRECTORY/3.3.3/kernel/"]="mod-simple.ko"
    ["test-modprobe/alias-to-none$MODULE_DIRECTORY/4.4.4/kernel/"]="mod-simple.ko"
    ["test-modprobe/module-param-kcmdline$MODULE_DIRECTORY/4.4.4/kernel/"]="mod-simple.ko"
    ["test-modprobe/external/lib/modules/external/"]="mod-simple.ko"
    ["test-modprobe/module-from-abspath/home/foo/"]="mod-simple.ko"
    ["test-modprobe/module-from-relpath/home/foo/"]="mod-simple.ko"
    ["test-depmod/modules-order-compressed$MODULE_DIRECTORY/4.4.4/kernel/drivers/block/cciss.ko"]="mod-fake-cciss.ko"
    ["test-depmod/modules-order-compressed$MODULE_DIRECTORY/4.4.4/kernel/drivers/scsi/hpsa.ko"]="mod-fake-hpsa.ko"
    ["test-depmod/modules-order-compressed$MODULE_DIRECTORY/4.4.4/kernel/drivers/scsi/scsi_mod.ko"]="mod-fake-scsi-mod.ko"
    ["test-depmod/modules-outdir$MODULE_DIRECTORY/4.4.4/kernel/drivers/block/cciss.ko"]="mod-fake-cciss.ko"
    ["test-depmod/modules-outdir$MODULE_DIRECTORY/4.4.4/kernel/drivers/scsi/hpsa.ko"]="mod-fake-hpsa.ko"
    ["test-depmod/modules-outdir$MODULE_DIRECTORY/4.4.4/kernel/drivers/scsi/scsi_mod.ko"]="mod-fake-scsi-mod.ko"
    ["test-depmod/another-moddir/foobar/4.4.4/kernel/"]="mod-simple.ko"
    ["test-depmod/another-moddir/foobar2/4.4.4/kernel/"]="mod-simple.ko"
    # TODO: add cross-compiled modules to the test
    ["test-modinfo/mod-simple.ko"]="mod-simple.ko"
    ["test-modinfo/mod-simple-sha1.ko"]="mod-simple.ko"
    ["test-modinfo/mod-simple-sha256.ko"]="mod-simple.ko"
    ["test-modinfo/mod-simple-pkcs7.ko"]="mod-simple.ko"
    ["test-modinfo/external/lib/modules/external/mod-simple.ko"]="mod-simple.ko"
    ["test-weakdep$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-a.ko"]="mod-loop-a.ko"
    ["test-weakdep$MODULE_DIRECTORY/4.4.4/kernel/mod-loop-b.ko"]="mod-loop-b.ko"
    ["test-weakdep$MODULE_DIRECTORY/4.4.4/kernel/mod-simple.ko"]="mod-simple.ko"
    ["test-weakdep$MODULE_DIRECTORY/4.4.4/kernel/mod-weakdep.ko"]="mod-weakdep.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/block/t10-pi.ko"]="ex-t10-pi.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/cdrom/cdrom.ko"]="ex-cdrom.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/scsi/scsi_mod.ko"]="ex-scsi_mod.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/scsi/scsi_transport_fc.ko"]="ex-scsi_transport_fc.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/scsi/scsi_transport_sas.ko"]="ex-scsi_transport_sas.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/scsi/sd_mod.ko"]="ex-sd_mod.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/scsi/sr_mod.ko"]="ex-sr_mod.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/scsi/ses.ko"]="ex-ses.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/scsi/device_handler/scsi_dh_alua.ko"]="ex-scsi_dh_alua.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/scsi/raid_class.ko"]="ex-raid_class.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/scsi/mpt3sas.ko"]="ex-mpt3sas.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/scsi/qla2xxx/qla2xxx.ko"]="ex-qla2xxx.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/scsi/qla2xxx/tcm_qla2xxx.ko"]="ex-tcm_qla2xxx.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/nvme/host/nvme-fc.ko"]="ex-nvme-fc.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/nvme/host/nvme-fabrics.ko"]="ex-nvme-fabrics.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/nvme/host/nvme-core.ko"]="ex-nvme-core.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/target/target_core_mod.ko"]="ex-target_core_mod.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/misc/enclosure.ko"]="ex-enclosure.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/md/dm-multipath.ko"]="ex-dm-multipath.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/md/dm-service-time.ko"]="ex-dm-multipath.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/drivers/md/dm-mod.ko"]="ex-dm-mod.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/kernel/fs/configfs/configfs.ko"]="ex-configfs.ko"
    ["test-depmod/big-01/lib/modules/5.3.18/symvers"]="symvers"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/block/t10-pi.ko"]="ex-t10-pi.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/cdrom/cdrom.ko"]="ex-cdrom.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/scsi/scsi_mod.ko"]="ex-scsi_mod.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/scsi/scsi_transport_fc.ko"]="ex-scsi_transport_fc.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/scsi/scsi_transport_sas.ko"]="ex-scsi_transport_sas.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/scsi/sd_mod.ko"]="ex-sd_mod.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/scsi/sr_mod.ko"]="ex-sr_mod.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/scsi/ses.ko"]="ex-ses.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/scsi/device_handler/scsi_dh_alua.ko"]="ex-scsi_dh_alua.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/scsi/raid_class.ko"]="ex-raid_class.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/scsi/mpt3sas.ko"]="ex-mpt3sas.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/scsi/qla2xxx/qla2xxx.ko"]="ex-qla2xxx.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/scsi/qla2xxx/tcm_qla2xxx.ko"]="ex-tcm_qla2xxx.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/nvme/host/nvme-fc.ko"]="ex-nvme-fc.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/nvme/host/nvme-fabrics.ko"]="ex-nvme-fabrics.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/nvme/host/nvme-core.ko"]="ex-nvme-core.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/target/target_core_mod.ko"]="ex-target_core_mod.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/misc/enclosure.ko"]="ex-enclosure.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/md/dm-multipath.ko"]="ex-dm-multipath.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/md/dm-service-time.ko"]="ex-dm-multipath.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/drivers/md/dm-mod.ko"]="ex-dm-mod.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/kernel/fs/configfs/configfs.ko"]="ex-configfs.ko"
    ["test-depmod/big-01-incremental/lib/modules/5.3.18/symvers"]="symvers"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/block/t10-pi.ko"]="ex-t10-pi.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/cdrom/cdrom.ko"]="ex-cdrom.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/scsi/scsi_mod.ko"]="ex-scsi_mod.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/scsi/scsi_transport_fc.ko"]="ex-scsi_transport_fc.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/scsi/sd_mod.ko"]="ex-sd_mod.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/scsi/sr_mod.ko"]="ex-sr_mod.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/scsi/device_handler/scsi_dh_alua.ko"]="ex-scsi_dh_alua.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/scsi/raid_class.ko"]="ex-raid_class.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/nvme/host/nvme-fc.ko"]="ex-nvme-fc.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/nvme/host/nvme-fabrics.ko"]="ex-nvme-fabrics.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/nvme/host/nvme-core.ko"]="ex-nvme-core.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/target/target_core_mod.ko"]="ex-target_core_mod.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/misc/enclosure.ko"]="ex-enclosure.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/md/dm-multipath.ko"]="ex-dm-multipath.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/md/dm-service-time.ko"]="ex-dm-multipath.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/drivers/md/dm-mod.ko"]="ex-dm-mod.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/kernel/fs/configfs/configfs.ko"]="ex-configfs.ko"
    ["test-depmod/big-01-delete/lib/modules/5.3.18/symvers"]="symvers"
)

gzip_array=(
    "test-depmod/modules-order-compressed$MODULE_DIRECTORY/4.4.4/kernel/drivers/block/cciss.ko"
    )

xz_array=(
    "test-depmod/modules-order-compressed$MODULE_DIRECTORY/4.4.4/kernel/drivers/scsi/scsi_mod.ko"
    )

zstd_array=(
    "test-depmod/modules-order-compressed$MODULE_DIRECTORY/4.4.4/kernel/drivers/scsi/hpsa.ko"
    )

attach_sha256_array=(
    "test-modinfo/mod-simple-sha256.ko"
    )

attach_sha1_array=(
    "test-modinfo/mod-simple-sha1.ko"
    )

attach_pkcs7_array=(
    "test-modinfo/mod-simple-pkcs7.ko"
    )

create_rootfs

for k in "${!map[@]}"; do
    dst=${ROOTFS}/$k
    src=${MODULE_PLAYGROUND}/${map[$k]}

    if [[ $dst = */ ]]; then
        install -d "$dst"
        install -t "$dst" "$src"
    else
        install -D "$src" "$dst"
    fi
done

# start poking the final rootfs...

# compress modules with each format if feature is enabled
if feature_enabled ZLIB; then
	for m in "${gzip_array[@]}"; do
	    gzip "$ROOTFS/$m"
	done
fi

if feature_enabled XZ; then
	for m in "${xz_array[@]}"; do
	    xz "$ROOTFS/$m"
	done
fi

if feature_enabled ZSTD; then
	for m in "${zstd_array[@]}"; do
	    zstd --rm "$ROOTFS/$m"
	done
fi

for m in "${attach_sha1_array[@]}"; do
    cat "${MODULE_PLAYGROUND}/dummy.sha1" >>"${ROOTFS}/$m"
done

for m in "${attach_sha256_array[@]}"; do
    cat "${MODULE_PLAYGROUND}/dummy.sha256" >>"${ROOTFS}/$m"
done

for m in "${attach_pkcs7_array[@]}"; do
    cat "${MODULE_PLAYGROUND}/dummy.pkcs7" >>"${ROOTFS}/$m"
done

# if CONFIG_MODVERSIONS is off, modules-symbols.bin is different.
# both the input (if present) and the correct output must be replaced.
. "${MODULE_PLAYGROUND}/modversions"
if [ "${CONFIG_MODVERSIONS}" != y ]; then
    find "$ROOTFS" -name 'novers-*modules.symbols.bin' | \
	while read f; do
	    rm -fv "${f/novers-/}"
	    ln -sv "${f##*/}" "${f/novers-/}"
	done
fi

touch testsuite/stamp-rootfs
