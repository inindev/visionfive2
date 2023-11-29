#!/bin/sh

# Copyright (C) 2023, John Clark <inindev@gmail.com>

set -e

# script exit codes:
#   1: missing utility
#   5: invalid file hash

main() {
    local linux='https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.3.tar.xz'
    local lxsha='28edfc3d4f90cd738f2a20f5a2d68510268176d6111f6278d8f495edfd9495a7'

    local lf="$(basename "$linux")"
    local lv="$(echo "$lf" | sed -nE 's/linux-(.*)\.tar\..z/\1/p')"

    if is_param 'clean' "$@"; then
        rm -f *.dtb *-top.dts
        find . -maxdepth 1 -type l -delete
        rm -rf "linux-$lv"
        echo '\nclean complete\n'
        exit 0
    fi

    check_installed 'device-tree-compiler' 'gcc' 'wget' 'xz-utils'

    if [ ! -e "$lf" ]; then
        if [ -e "../kernel/kernel-$lv/$lf" ]; then
            print_hdr "linking local copy of linux $lv from ../kernel"
            ln -sv "../kernel/kernel-$lv/$lf"
        else
            print_hdr "downloading linux $lv"
            wget "$linux"
        fi
    fi

    if [ "_$lxsha" != "_$(sha256sum "$lf" | cut -c1-64)" ]; then
        echo "invalid hash for linux source file: $lf"
        exit 5
    fi

    local sfpath="linux-$lv/arch/riscv/boot/dts/starfive"
    if ! [ -d "linux-$lv" ]; then
        print_hdr "unpacking linux $lv"
        tar xavf "$lf" "linux-$lv/include/dt-bindings" "$sfpath"

        print_hdr 'applying patches'
        local patch patches="$(find patches -name '*.patch' 2>/dev/null | sort)"
        for patch in $patches; do
            patch -p1 -d "linux-$lv" -i "../$patch"
        done
    fi

    if is_param 'links' "$@"; then
        local sff sffl='jh7110-starfive-visionfive-2-v1.3b.dts jh7110-starfive-visionfive-2.dtsi jh7110.dtsi'
        for sff in $sffl; do
            ln -sfv "$sfpath/$sff"
        done
        echo '\nlinks created\n'
        exit 0
    fi

    # build
    local dt='jh7110-starfive-visionfive-2-v1.3b'
    print_hdr "building device tree ${dt}.dtb"
    local fldtc='-Wno-interrupt_provider -Wno-unique_unit_address -Wno-unit_address_vs_reg -Wno-avoid_unnecessary_addr_size -Wno-alias_paths -Wno-graph_child_address -Wno-simple_bus_reg'
    gcc -I "linux-$lv/include" -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o "${dt}-top.dts" "$sfpath/${dt}.dts"
    dtc -I dts -O dtb -b 0 ${fldtc} -o "${dt}.dtb" "${dt}-top.dts"
    make -C overlays
    is_param 'cp' "$@" && cp_to_ubuntu "${dt}.dtb" && make -C overlays install
    echo "\n${cya}device tree ready: ${dt}.dtb${rst}\n"
}

cp_to_ubuntu() {
    local target="$1"
    local ubu_dist=$(cat "../ubuntu/make_ubuntu_img.sh" | sed -n 's/\s*local ubu_dist=.\([[:alpha:]]\+\)./\1/p')
    [ -z "$ubu_dist" ] && return
    local cdir="../ubuntu/cache.$ubu_dist"
    print_hdr 'copying to ubuntu cache'
    sudo mkdir -p "$cdir"
    sudo cp -v "$target" "$cdir"
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

