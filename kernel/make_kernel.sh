#!/bin/sh

set -e

# script exit codes:
#   1: missing utility
#   5: invalid file hash
#   7: use screen session
#   8: superuser disallowed

config_fixups() {
    local lpath="$1"

    [ -e "$lpath/.version" ] || echo 3000 > "$lpath/.version"
}

main() {
    local linux='https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.2.tar.xz'
    local lxsha='73d4f6ad8dd6ac2a41ed52c2928898b7c3f2519ed5dbdb11920209a36999b77e'

    local lf="$(basename "$linux")"
    local lv="$(echo "$lf" | sed -nE 's/linux-(.*)\.tar\..z/\1/p')"
    local lpath="kernel-$lv/linux-$lv"

    if [ '_clean' = "_$1" ]; then
        print_hdr 'cleaning'
        rm -fv *.deb
        rm -rfv kernel-$lv/*.deb
        rm -rfv kernel-$lv/*.buildinfo
        rm -rfv kernel-$lv/*.changes
        rm -rf "$lpath"
        echo '\nclean complete\n'
        exit 0
    fi

    check_installed 'screen' 'build-essential' 'python3' 'flex' 'bison' 'pahole' 'debhelper'  'bc' 'rsync' 'libncurses-dev' 'libelf-dev' 'libssl-dev' 'lz4' 'zstd'

    if [ -z "$STY$TMUX" ]; then
        echo 'reminder: run from a screen or tmux session, this can take a while...'
        exit 7
    fi

    mkdir -p "kernel-$lv"
    if [ ! -e "kernel-$lv/$lf" ]; then
        if [ -e "../dtb/$lf" ]; then
            print_hdr "linking local copy of linux $lv from ../dtb"
            ln -sv "../../dtb/$lf" "kernel-$lv/$lf"
        else
            print_hdr "downloading linux $lv"
            wget "$linux" -P "kernel-$lv"
        fi
    fi

    if [ "_$lxsha" != "_$(sha256sum "kernel-$lv/$lf" | cut -c1-64)" ]; then
        echo "invalid hash for linux source file: $lf"
        exit 5
    fi

    if [ ! -d "$lpath" ]; then
        tar -C "kernel-$lv" -xavf "kernel-$lv/$lf"

        local patch patches="$(find patches -name '*.patch' 2>/dev/null | sort)"
        for patch in $patches; do
            patch -p1 -d "$lpath" -i "../../$patch"
        done
    fi

    # build
    if [ '_inc' != "_$1" ]; then
        print_hdr 'configuring source tree'
        make -C "$lpath" mrproper
        [ -z "$1" ] || echo "$1" > "$lpath/.version"
        make -C "$lpath" ARCH=riscv starfive_visionfive2_defconfig
        config_fixups "$lpath"
    fi

    print_hdr 'beginning compile'
    rm -f linux-*.deb
    local kver="$(make --no-print-directory -C "$lpath" kernelversion)"
    local bver="$(expr "$(cat "$lpath/.version" 2>/dev/null || echo 0)" + 1 2>/dev/null)"
    local lver="$bver-starfive"
    export SOURCE_DATE_EPOCH="$(stat -c %Y "$lpath/README")"
    export KDEB_CHANGELOG_DIST='mantic'
    export KBUILD_BUILD_TIMESTAMP="$(date -d @$SOURCE_DATE_EPOCH)"
    export KBUILD_BUILD_HOST='github.com/inindev'
    export KBUILD_BUILD_USER='linux-kernel'
    export KBUILD_BUILD_VERSION="$bver"

    local t1=$(date +%s)
    nice make -C "$lpath" -j"$(nproc)" ARCH=riscv CC="$(readlink /usr/bin/gcc)" bindeb-pkg KBUILD_IMAGE='arch/riscv/boot/Image' LOCALVERSION="-$lver"
    local t2=$(date +%s)
    echo "\n${cya}kernel package ready (elapsed: $(date -d@$((t2-t1)) '+%H:%M:%S'))${mag}"
    ln -sfv "kernel-$lv/linux-image-${kver}-${lver}_${kver}-${bver}_riscv64.deb"
    ln -sfv "kernel-$lv/linux-headers-${kver}-${lver}_${kver}-${bver}_riscv64.deb"
    echo "${rst}"
}

check_installed() {
    local todo
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

if [ 0 -eq $(id -u) ]; then
    echo 'do not compile as root'
    exit 8
fi

cd "$(dirname "$(realpath "$0")")"
main "$@"

