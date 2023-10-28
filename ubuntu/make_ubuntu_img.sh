#!/bin/sh

# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

# script exit codes:
#   1: missing utility
#   2: download failure
#   3: image mount failure
#   4: missing file
#   5: invalid file hash
#   9: superuser required

main() {
    # file media is sized with the number between 'mmc_' and '.img'
    #   use 'm' for 1024^2 and 'g' for 1024^3
    local media='mmc_4g.img' # or block device '/dev/sdX'
    local ubu_dist='mantic'
    local hostname='visionfive2'
    local acct_uid='ubuntu'
    local acct_pass='ubuntu'
    local extra_pkgs='curl, pciutils, nano, unzip, wget, xxd, xz-utils, zip, zstd'

    # partition table sector offsets
    local sec_spl=4096
    local sec_itb=8192
    local sec_rfs=16384

    if is_param 'clean' "$@"; then
        rm -rf cache*/var
        rm -f "$media"*
        rm -rf "$mountpt"
        rm -rf rootfs
        echo '\nclean complete\n'
        exit 0
    fi

    check_installed 'debootstrap' 'wget' 'xz-utils'

    if [ -f "$media" ]; then
        read -p "file $media exists, overwrite? <y/N> " yn
        if ! [ "$yn" = 'y' -o "$yn" = 'Y' -o "$yn" = 'yes' -o "$yn" = 'Yes' ]; then
            echo 'exiting...'
            exit 0
        fi
    fi

    # no compression if disabled or block media
    local compress=$(is_param 'nocomp' "$@" || [ -b "$media" ] && echo false || echo true)

    if $compress && [ -f "$media.xz" ]; then
        read -p "file $media.xz exists, overwrite? <y/N> " yn
        if ! [ "$yn" = 'y' -o "$yn" = 'Y' -o "$yn" = 'yes' -o "$yn" = 'Yes' ]; then
            echo 'exiting...'
            exit 0
        fi
    fi

    print_hdr 'downloading files'
    local cache="cache.$ubu_dist"

    # u-boot
    local uboot_spl=$(download "$cache" 'https://github.com/inindev/visionfive2/releases/download/v23.10.0/u-boot-spl.bin.normal.out')
    [ -f "$uboot_spl" ] || { echo "unable to fetch $uboot_spl"; exit 4; }
    local uboot_itb=$(download "$cache" 'https://github.com/inindev/visionfive2/releases/download/v23.10.0/u-boot.itb')
    [ -f "$uboot_itb" ] || { echo "unable to fetch: $uboot_itb"; exit 4; }

    # dtb
    local dtb=$(download "$cache" 'https://github.com/inindev/visionfive2/releases/download/v23.10.0/jh7110-starfive-visionfive-2-v1.3b.dtb')
    [ -f "$dtb" ] || { echo "unable to fetch $dtb"; exit 4; }

    # setup media
    if [ ! -b "$media" ]; then
        print_hdr 'creating image file'
        make_image_file "$media"
    fi

    print_hdr 'partitioning media'
    parition_media "$media" $sec_spl $sec_itb $sec_rfs

    print_hdr 'formatting media'
    format_media "$media" 3

    print_hdr 'mounting media'
    mount_media "$media" 3 $sec_rfs

    print_hdr 'configuring files'
    install -Dvm 644 'files/kernel-img.conf' "$mountpt/etc/kernel-img.conf"

    # setup fstab
    local mdev="$(findmnt -no source "$mountpt")"
    local uuid="$(blkid -o value -s UUID "$mdev")"
    echo "$(file_fstab $uuid)\n" > "$mountpt/etc/fstab"

    # setup extlinux boot
    install -Dvm 754 'files/dtb_cp' "$mountpt/etc/kernel/postinst.d/dtb_cp"
    install -Dvm 754 'files/kernel_chmod' "$mountpt/etc/kernel/postinst.d/kernel_chmod"
    install -Dvm 754 'files/dtb_rm' "$mountpt/etc/kernel/postrm.d/dtb_rm"
    install -Dvm 754 'files/mk_extlinux' "$mountpt/boot/mk_extlinux"
    ln -svf '../../../boot/mk_extlinux' "$mountpt/etc/kernel/postinst.d/update_extlinux"
    ln -svf '../../../boot/mk_extlinux' "$mountpt/etc/kernel/postrm.d/update_extlinux"

    # install device tree
    install -vm 644 "$dtb" "$mountpt/boot"

    # install ubuntu linux from packages (debootstrap)
    print_hdr 'installing root filesystem from ubuntu.com'

    # do not write the cache to the image
    mkdir -p "$cache/var/cache" "$cache/var/lib/apt/lists"
    mkdir -p "$mountpt/var/cache" "$mountpt/var/lib/apt/lists"
    mount -o bind "$cache/var/cache" "$mountpt/var/cache"
    mount -o bind "$cache/var/lib/apt/lists" "$mountpt/var/lib/apt/lists"

    local pkgs='ubuntu-minimal, linux-image-starfive, initramfs-tools'
    pkgs="$pkgs, bc, binutils, fdisk"
    pkgs="$pkgs, dbus, dhcpcd, libpam-systemd, openssh-server, systemd-timesyncd, wpasupplicant"
    pkgs="$pkgs, $extra_pkgs"
    debootstrap --arch riscv64 --components=main,universe --include "$pkgs" --exclude 'isc-dhcp-client' "$ubu_dist" "$mountpt" 'http://ports.ubuntu.com/ubuntu-ports'

    umount "$mountpt/var/cache"
    umount "$mountpt/var/lib/apt/lists"

    # apt sources & default locale
    echo "$(file_apt_sources $ubu_dist)\n" > "$mountpt/etc/apt/sources.list"
    echo "$(file_locale_cfg)\n" > "$mountpt/etc/default/locale"

    # wpa supplicant
#    rm -rfv "$mountpt/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service"
#    echo "$(file_wpa_supplicant_conf)\n" > "$mountpt/etc/wpa_supplicant/wpa_supplicant.conf"
#    cp -v "$mountpt/usr/share/dhcpcd/hooks/10-wpa_supplicant" "$mountpt/usr/lib/dhcpcd/dhcpcd-hooks"

    # hostname
    echo $hostname > "$mountpt/etc/hostname"
    sed -i "s/127.0.0.1\tlocalhost/127.0.0.1\tlocalhost\n127.0.1.1\t$hostname/" "$mountpt/etc/hosts"

    print_hdr 'creating user account'
    chroot "$mountpt" /usr/sbin/useradd -m "$acct_uid" -s '/bin/bash'
    chroot "$mountpt" /bin/sh -c "/usr/bin/echo $acct_uid:$acct_pass | /usr/sbin/chpasswd -c YESCRYPT"
    chroot "$mountpt" /usr/bin/passwd -e "$acct_uid"
    (umask 377 && echo "$acct_uid ALL=(ALL) NOPASSWD: ALL" > "$mountpt/etc/sudoers.d/$acct_uid")

    print_hdr 'installing rootfs expansion script to /etc/rc.local'
    install -Dvm 754 'files/rc.local' "$mountpt/etc/rc.local"

    # disable sshd until after keys are regenerated on first boot
    rm -fv "$mountpt/etc/systemd/system/sshd.service"
    rm -fv "$mountpt/etc/systemd/system/multi-user.target.wants/ssh.service"
    rm -fv "$mountpt/etc/ssh/ssh_host_"*

    # generate machine id on first boot
    rm -fv "$mountpt/etc/machine-id"

    # reduce entropy on non-block media
    [ -b "$media" ] || fstrim -v "$mountpt"

    umount "$mountpt"
    rm -rf "$mountpt"

    print_hdr 'installing u-boot'
    dd if="$uboot_spl" of="$media" bs=512 seek=$sec_spl conv=notrunc
    dd if="$uboot_itb" of="$media" bs=512 seek=$sec_itb conv=notrunc

    if $compress; then
        print_hdr 'compressing image file'
        xz -z8v "$media"
        echo "\n${cya}compressed image is now ready${rst}"
        echo "\n${cya}copy image to target media:${rst}"
        echo "  ${cya}sudo sh -c 'xzcat $media.xz > /dev/sdX && sync'${rst}"
    elif [ -b "$media" ]; then
        echo "\n${cya}media is now ready${rst}"
    else
        echo "\n${cya}image is now ready${rst}"
        echo "\n${cya}copy image to media:${rst}"
        echo "  ${cya}sudo sh -c 'cat $media > /dev/sdX && sync'${rst}"
    fi
    echo
}

make_image_file() {
    local filename="$1"
    rm -f "$filename"*
    local size="$(echo "$filename" | sed -rn 's/.*mmc_([[:digit:]]+[m|g])\.img$/\1/p')"
    truncate -s "$size" "$filename"
}

parition_media() {
    local media="$1"
    local sec_spl="$2"
    local sec_itb="$3"
    local sec_rfs="$4"

    # partition with gpt
    cat <<-EOF | sfdisk "$media"
	label: gpt
	unit: sectors
	sector-size: 512
	part1: start=$sec_spl, size=$((sec_itb - sec_spl)), type=2e54b353-1271-4842-806f-e436d6af6985, name=spl
	part2: start=$sec_itb, size=$((sec_rfs - sec_itb)), type=5b193300-fc78-40cd-8002-e86c45580b47, name=uboot
	part3: start=$sec_rfs,                              type=0fc63daf-8483-4772-8e79-3d69d8477de4, name=rootfs
	EOF
    sync
}

format_media() {
    local media="$1"
    local partnum="${2:-3}"

    # create ext4 filesystem
    if [ -b "$media" ]; then
        local rdn="$(basename "$media")"
        local sbpn="$(echo /sys/block/${rdn}/${rdn}*${partnum})"
        local part="/dev/$(basename "$sbpn")"
        mkfs.ext4 -L rootfs -vO metadata_csum_seed "$part" && sync
    else
        local lodev="$(losetup -f)"
        losetup -vP "$lodev" "$media" && sync
        mkfs.ext4 -L rootfs -vO metadata_csum_seed "${lodev}p${partnum}" && sync
        losetup -vd "$lodev" && sync
    fi
}

mount_media() {
    local media="$1"
    local partnum="${2:-3}"
    local sec_rfs="$3"

    if [ -d "$mountpt" ]; then
        mountpoint -q "$mountpt/var/cache" && umount "$mountpt/var/cache"
        mountpoint -q "$mountpt/var/lib/apt/lists" && umount "$mountpt/var/lib/apt/lists"
        mountpoint -q "$mountpt" && umount "$mountpt"
    else
        mkdir -p "$mountpt"
    fi

    local part
    if [ -b "$media" ]; then
        local rdn="$(basename "$media")"
        local sbpn="$(echo /sys/block/${rdn}/${rdn}*${partnum})"
        part="/dev/$(basename "$sbpn")"
        mount "$part" "$mountpt"
    elif [ -f "$media" ]; then
        mount -no loop,offset=$(($sec_rfs * 512)) "$media" "$mountpt"
        part="$(losetup -nO name -j "$media")"
    else
        echo "file not found: $media"
        exit 4
    fi

    if [ ! -d "$mountpt/lost+found" ]; then
        echo 'failed to mount the image file'
        exit 3
    fi

    echo "partition ${cya}$part${rst} successfully mounted on ${cya}$mountpt${rst}"
}

check_mount_only() {
    local item img flag=false
    for item in "$@"; do
        case "$item" in
            mount) flag=true ;;
            *.img) img=$item ;;
            *.img.xz) img=$item ;;
        esac
    done
    ! $flag && return

    if [ ! -f "$img" ]; then
        if [ -z "$img" ]; then
            echo "no image file specified"
        else
            echo "file not found: ${red}$img${rst}"
        fi
        exit 3
    fi

    if [ "$img" = *.xz ]; then
        local tmp=$(basename "$img" .xz)
        if [ -f "$tmp" ]; then
            echo "compressed file ${bld}$img${rst} was specified but uncompressed file ${bld}$tmp${rst} exists..."
            echo -n "mount ${bld}$tmp${rst}"
            read -p " instead? <Y/n> " yn
            if ! [ -z "$yn" -o "$yn" = 'y' -o "$yn" = 'Y' -o "$yn" = 'yes' -o "$yn" = 'Yes' ]; then
                echo 'exiting...'
                exit 0
            fi
            img=$tmp
        else
            echo -n "compressed file ${bld}$img${rst} was specified"
            read -p ', decompress to mount? <Y/n>' yn
            if ! [ -z "$yn" -o "$yn" = 'y' -o "$yn" = 'Y' -o "$yn" = 'yes' -o "$yn" = 'Yes' ]; then
                echo 'exiting...'
                exit 0
            fi
            xz -dk "$img"
            img=$(basename "$img" .xz)
        fi
    fi

    echo "mounting file ${yel}$img${rst}..."
    mount_media "$img" 3 16384  # todo: remove hardcode
    trap - EXIT INT QUIT ABRT TERM
    echo "media mounted, use ${grn}sudo umount $mountpt${rst} to unmount"

    exit 0
}

file_fstab() {
    local uuid="$1"

    cat <<-EOF
	# if editing the device name for the root entry, it is necessary
	# to regenerate the extlinux.conf file by running /boot/mk_extlinux

	# <device>					<mount>	<type>	<options>		<dump> <pass>
	UUID=$uuid	/	ext4	errors=remount-ro	0      1
	EOF
}

file_apt_sources() {
    local ubu_dist="$1"

    cat <<-EOF
	# For information about how to configure apt package sources,
	# see the sources.list(5) manual.

	deb http://ports.ubuntu.com/ubuntu-ports ${ubu_dist} main universe
	# deb-src http://ports.ubuntu.com/ubuntu-ports ${ubu_dist} main universe

	deb http://ports.ubuntu.com/ubuntu-ports ${ubu_dist}-security main universe
	# deb-src http://ports.ubuntu.com/ubuntu-ports ${ubu_dist}-security main universe

	deb http://ports.ubuntu.com/ubuntu-ports ${ubu_dist}-updates main universe
	# deb-src http://ports.ubuntu.com/ubuntu-ports ${ubu_dist}-updates main universe
	EOF
}

file_wpa_supplicant_conf() {
    cat <<-EOF
	ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
	update_config=1
	EOF
}

file_locale_cfg() {
    cat <<-EOF
	LANG="C.UTF-8"
	LANGUAGE=
	LC_CTYPE="C.UTF-8"
	LC_NUMERIC="C.UTF-8"
	LC_TIME="C.UTF-8"
	LC_COLLATE="C.UTF-8"
	LC_MONETARY="C.UTF-8"
	LC_MESSAGES="C.UTF-8"
	LC_PAPER="C.UTF-8"
	LC_NAME="C.UTF-8"
	LC_ADDRESS="C.UTF-8"
	LC_TELEPHONE="C.UTF-8"
	LC_MEASUREMENT="C.UTF-8"
	LC_IDENTIFICATION="C.UTF-8"
	LC_ALL=
	EOF
}

# download / return file from cache
download() {
    local cache="$1"
    local url="$2"

    [ -d "$cache" ] || mkdir -p "$cache"

    local filename="$(basename "$url")"
    local filepath="$cache/$filename"
    [ -f "$filepath" ] || wget "$url" -P "$cache"
    [ -f "$filepath" ] || exit 2

    echo "$filepath"
}

is_param() {
    local item match
    for item in "$@"; do
        if [ -z "$match" ]; then
            match="$item"
        elif [ "$match" = "$item" ]; then
            return 0
        fi
    done
    return 1
}

check_installed() {
    local item todo
    for item in "$@"; do
        dpkg -l "$item" 2>/dev/null | grep -q "ii  $item" || todo="$todo $item"
    done

    if [ ! -z "$todo" ]; then
        echo "this script requires the following packages:${bld}${yel}$todo${rst}"
        echo "   run: ${bld}${grn}sudo apt update && sudo apt -y install$todo${rst}\n"
        exit 1
    fi
}

print_hdr() {
    local msg="$1"
    echo "\n${h1}$msg...${rst}"
}
rst='\033[m'
bld='\033[1m'
red='\033[31m'
grn='\033[32m'
yel='\033[33m'
blu='\033[34m'
mag='\033[35m'
cya='\033[36m'
h1="${blu}==>${rst} ${bld}"

# ensure inner mount points get cleaned up
on_exit() {
    if mountpoint -q "$mountpt"; then
        mountpoint -q "$mountpt/var/cache" && umount "$mountpt/var/cache"
        mountpoint -q "$mountpt/var/lib/apt/lists" && umount "$mountpt/var/lib/apt/lists"

        read -p "$mountpt is still mounted, unmount? <Y/n> " yn
        if [ -z "$yn" -o "$yn" = 'y' -o "$yn" = 'Y' -o "$yn" = 'yes' -o "$yn" = 'Yes' ]; then
            echo "unmounting $mountpt"
            umount "$mountpt"
            sync
            rm -rf "$mountpt"
        fi
    fi
}
mountpt='rootfs'
trap on_exit EXIT INT QUIT ABRT TERM

if [ 0 -ne $(id -u) ]; then
    echo 'this script must be run as root'
    echo "   run: ${bld}${grn}sudo sh $(basename "$0")${rst}\n"
    exit 9
fi

cd "$(dirname "$(realpath "$0")")"
check_mount_only "$@"
main "$@"

