#!/bin/bash
# Runs INSIDE the pi-ios-root container (privileged, as root). Use ../mkios-root.sh from the host.
#
#   mkios-root.sh OS.dmg SYSTEMOS.dmg APPOS.dmg OUT.img SIZE
#
# One case-sensitive journaled HFS+ volume holding the iOS OS root plus both cryptexes
# (adapted from ios-sweet's tools/mkiosroot.sh). The IPSW images are raw APFS with compressed
# files: apfs-fuse reads (and decompresses) them, so the HFS+ copy is uncompressed.
set -euo pipefail
[[ $# -eq 5 ]] || { sed -n '2,8p' "$0"; exit 2; }
os=$(realpath "$1") sysos=$(realpath "$2") appos=$(realpath "$3") out=$4 size=$5
[[ ! -e $out ]] || { echo "refusing to overwrite $out" >&2; exit 1; }

modprobe hfsplus 2>/dev/null || true
grep -qw hfsplus /proc/filesystems || { echo "host kernel has no hfsplus (mount /lib/modules)" >&2; exit 1; }

work=$(mktemp -d)
mounts=()
cleanup() {
	for m in "${mounts[@]}"; do mountpoint -q "$m" && umount "$m" 2>/dev/null || true; done
	rm -f "$work"/*.dmg
	rmdir "$work"/* "$work" 2>/dev/null || true
}
trap cleanup EXIT

# apfs-fuse splits options on ',' (iPhone10,3 in IPSW names) and only parses UDIF images
# when the file name ends in .dmg: mount through a comma-free link.
apfs_mount() {
	ln -s "$1" "$work/$2.dmg"
	mkdir "$work/$2"
	apfs-fuse "$work/$2.dmg" "$work/$2"
	mounts+=("$work/$2")
}
apfs_mount "$os" os
apfs_mount "$sysos" sysos
apfs_mount "$appos" appos

truncate -s "$size" "$out"
mkfs.hfsplus -s -J -v iOSRoot "$out"
mkdir "$work/root"
mount -t hfsplus -o loop,force "$out" "$work/root"
mounts=("$work/root" "${mounts[@]}")

copy() {
	echo "copying $1 -> ${2#"$work/root"}"
	mkdir -p "$2"
	rsync -aH --numeric-ids "$1/" "$2/"
}
copy "$work/os/root" "$work/root"
copy "$work/sysos/root" "$work/root/private/preboot/Cryptexes/OS"
copy "$work/appos/root" "$work/root/private/preboot/Cryptexes/App"

# dyld at ignition level 1 looks for the shared cache here: hard links, no extra space.
dsc=private/preboot/Cryptexes/OS/System/Library/Caches/com.apple.dyld
mkdir -p "$work/root/System/Library/Caches/com.apple.dyld"
for f in "$work/root/$dsc"/*; do
	ln "$f" "$work/root/System/Library/Caches/com.apple.dyld/${f##*/}"
done

# ...and it does not search the cryptexes: hard-link every cryptex file that has no
# counterpart in the OS root (libobjc-trampolines, libffi-trampolines, ...).
for c in OS App; do
	(cd "$work/root/private/preboot/Cryptexes/$c" && find . ! -type d ! -path './System/Library/Caches/com.apple.dyld/*') |
	while IFS= read -r f; do
		f=${f#./}
		if ! test -e "$work/root/$f" && ! test -L "$work/root/$f"; then
			mkdir -p "$work/root/$(dirname "$f")"
			src="$work/root/private/preboot/Cryptexes/$c/$f"
			# Linux hfsplus cannot hard-link symlinks: copy those.
			if test -L "$src"; then cp -P "$src" "$work/root/$f"; else ln "$src" "$work/root/$f"; fi
		fi
	done
done

# logd's log stores are normally made at restore; it checks owner _logd (272), mode and a marker.
db="$work/root/private/var/db"
install -d -o 272 -g 272 -m 0751 "$db/diagnostics"
install -d -o 272 -g 272 -m 0755 "$db/uuidtext" "$db/diagnostics/timesync"
for d in diagnostics uuidtext diagnostics/timesync; do
	install -o 272 -g 272 -m 0644 /dev/null "$db/$d/.migrated"
done

df -h "$work/root"
umount "$work/root"
# Linux hfsplus decomposes some non-ASCII names differently from Apple's tables: let fsck rewrite them.
fsck.hfsplus -f -y "$out" | grep -v 'Illegal name' || true
fsck.hfsplus -f -n "$out"
