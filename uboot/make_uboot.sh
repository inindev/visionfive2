#!/bin/sh

# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

# script exit codes:
#   1: missing utility

main() {
    local utag='v2023.10.01' # hack: will force tag to c41df16b27 below
    local osbi_file='./opensbi/build/platform/generic/firmware/fw_dynamic.bin'

    # branch name is yyyy.mm[-rc]
    local branch="$(echo "$utag" | grep -Po '[\d.]+(.*-rc\d)*')"

    if is_param 'clean' "$@"; then
        rm -f *.img *.itb
        if [ -d u-boot ]; then
            rm -f 'mkimage'*
            rm -f 'spl-img.map'
            make -C u-boot distclean
            git -C u-boot clean -f
            git -C u-boot checkout master
            git -C u-boot branch -D "$branch" 2>/dev/null || true
            git -C u-boot pull --ff-only
        fi
        echo '\nclean complete\n'
        exit 0
    fi

    check_installed 'bc' 'bison' 'flex' 'libssl-dev' 'make' 'python3-dev' 'python3-setuptools' 'swig'

    if [ ! -d opensbi ]; then
        print_hdr 'cloning opensbi'
        git clone https://github.com/riscv-software-src/opensbi.git
    fi

    if [ ! -d u-boot ]; then
        print_hdr 'cloning u-boot'
        git clone https://github.com/u-boot/u-boot.git
        git -C u-boot fetch --tags
    fi

    # we are building from ref c41df16b27 right now...
    if ! git -C u-boot show-ref --tags "$utag" --quiet; then
        git -C u-boot tag "$utag" 'c41df16b27'
    fi

    print_hdr "u-boot branch: $branch"
    if ! git -C u-boot branch | grep -q "$branch"; then
        git -C u-boot checkout -b "$branch" "$utag"

        print_hdr 'patching u-boot'
        local patch
        for patch in patches/*.patch; do
            git -C u-boot am "../$patch"
        done
    elif [ "$branch" != "$(git -C u-boot branch --show-current)" ]; then
        git -C u-boot checkout "$branch"
    fi

    # compile opensbi if needed
    if [ ! -e "$osbi_file" ]; then
        print_hdr 'compiling opensbi'
        nice make -C opensbi -j$(nproc) PLATFORM=generic FW_TEXT_START=0x40000000 FW_OPTIONS=1
    fi

    # outputs: u-boot-spl.bin.normal.out, u-boot.itb
    rm -f 'u-boot-spl.bin.normal.out' 'u-boot.itb'
    print_hdr 'compiling u-boot'
    if ! is_param 'inc' "$@"; then
        make -C u-boot distclean
        make -C u-boot starfive_visionfive2_defconfig
    fi
    nice make -C u-boot -j$(nproc) OPENSBI="../$osbi_file"
    ln -sfv 'u-boot/spl/u-boot-spl.bin.normal.out'
    ln -sfv 'u-boot/u-boot.itb'

    is_param 'cp' "$@" && cp_to_dists

    echo "\n${cya}u-boot-spl.bin.normal.out and u-boot binaries are now ready${rst}"
    echo "\n${cya}copy images to media:${rst}"
    echo "  ${cya}sudo su${rst}"
    echo "  ${cya}cat u-boot-spl.bin.normal.out > /dev/mmcblkX1${rst}"
    echo "  ${cya}cat u-boot.itb > /dev/mmcblkX2${rst}"
    echo
    echo "${blu}optionally, flash to spi (apt install mtd-utils):${rst}"
    echo "  ${blu}sudo flashcp -Av u-boot-spl.bin.normal.out /dev/mtd0${rst}"
    echo "  ${blu}sudo flashcp -Av u-boot.itb /dev/mtd1${rst}"
    echo
}

cp_to_dists() {
    local deb_dist=$(cat "../debian/make_debian_img.sh" | sed -n 's/\s*local deb_dist=.\([[:alpha:]]\+\).*/\1/p')
    if [ -n "$deb_dist" ]; then
        print_hdr 'copying to debian cache'
        sudo mkdir -pv "../debian/cache.$deb_dist"
        sudo cp -v './u-boot-spl.bin.normal.out' './u-boot.itb' "../debian/cache.$deb_dist"
    fi

    local ubu_dist=$(cat "../ubuntu/make_ubuntu_img.sh" | sed -n 's/\s*local ubu_dist=.\([[:alpha:]]\+\).*/\1/p')
    if [ -n "$ubu_dist" ]; then
        print_hdr 'copying to ubuntu cache'
        sudo mkdir -pv "../ubuntu/cache.$ubu_dist"
        sudo cp -v './u-boot-spl.bin.normal.out' './u-boot.itb' "../ubuntu/cache.$ubu_dist"
    fi
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

cd "$(dirname "$(realpath "$0")")"
main "$@"

