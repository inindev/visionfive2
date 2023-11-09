#!/bin/sh

set -e


main() {
    local img_name img_sha dtb_name dtb_sha opensbi_sha uboot_spl_sha uboot_itb_sha
    parse_sha_file 'sha256sums.txt'
    #echo "img name: $img_name"
    #echo "img sha: $img_sha"
    #echo "dtb name: $dtb_name"
    #echo "dtb sha: $dtb_sha"
    #echo "uboot spl sha: $uboot_spl_sha"
    #echo "uboot itb sha: $uboot_itb_sha"

    local img board dn dv lv rc branch
    parse_img_name "$img_name"
    #echo "board: $board"
    #echo "dist name: $dn"
    #echo "dist ver: $dv"
    #echo "linux ver: $lv"
    #echo "linux rc: $rc"
    #echo "branch: $branch"

    branch='main'
    echo '-------------------------'
    echo "$(render)\n"
    echo '-------------------------'
}

render() {
    local tag="$dv-$lv"
    local uboot_ver="$(strings u-boot.itb | grep 'U-Boot 20' | cut -f2 -d' ' | sed 's/\(.*\)-.\{5\}-.\{11\}/\1/')"

    cat <<-EOF
	tag: $tag
	title: ubuntu $dn $tag for the $board
	---
	**$board mmc / emmc / nvme image file**
	 - [$img_name](https://github.com/inindev/$board/releases/download/$tag/$img_name) - complete image of riscv64 ubuntu linux $dv built from linux $lv, [patched kernel](https://github.com/inindev/$board/tree/$branch/kernel/patches)
	        \`\`\`sha256: $img_sha\`\`\`

	**device tree**
	 - [$dtb_name](https://github.com/inindev/$board/releases/download/$tag/$dtb_name) - device tree binary (dtb) built from linux $lv, [patched](https://github.com/inindev/$board/tree/$branch/dtb/patches)
	        \`\`\`sha256: $dtb_sha\`\`\`

	**opensbi**
	- [fw_dynamic.bin](https://github.com/inindev/$board/releases/download/$tag/fw_dynamic.bin)
	        \`\`\`sha256: $opensbi_sha\`\`\`

	**u-boot** - signed with opensbi
	 - [u-boot-spl.bin.normal.out](https://github.com/inindev/$board/releases/download/$tag/u-boot-spl.bin.normal.out) - uboot spl v$uboot_ver, patched loader for the $board
	        \`\`\`sha256: $uboot_spl_sha\`\`\`
	 - [u-boot.itb](https://github.com/inindev/$board/releases/download/$tag/u-boot.itb) - uboot v$uboot_ver, patched loader for the $board
	        \`\`\`sha256: $uboot_itb_sha\`\`\`

	<br/>
	EOF
}

parse_img_name() {
    # rock-5b_trixie-v13-6.6-rc4.img.xz
    local img_name="$1"

    # rock-5b
    board="$(echo "$img_name" | cut -f1 -d_)"
    # trixie-v13-6.6-rc4
    local temp="$(echo "$img_name" | cut -f2 -d_ | sed 's/\.img\.xz//')"
    # trixie
    dn="$(echo "$temp" | cut -f1 -d-)"
    # v13
    dv="$(echo "$temp" | cut -f2 -d-)"
    # 6.6-rc4
    lv="$(echo "$temp" | cut -f3 -d-)"
    # rc4
    rc="$(echo "$temp" | cut -f4 -d-)"

    branch='main'
    if [ -n "$rc" ]; then
        lv="$lv-$rc"
        branch='next'
    fi
}

parse_sha_file() {
    local sha_file="$1"

    img_name="$(cat "$sha_file" | grep '\.img.xz$' | sed 's/.*  \(.*\.img\.xz\)$/\1/')"
    img_sha="$(cat "$sha_file" | grep '\.img.xz$' | head -c64)"

    dtb_name="$(cat "$sha_file" | grep '\.dtb$' | sed 's/.*  \(.*\.dtb\)$/\1/')"
    dtb_sha="$(cat "$sha_file" | grep '\.dtb$' | head -c64)"

    opensbi_sha="$(cat "$sha_file" | grep 'fw_dynamic\.bin$' | head -c64)"
    uboot_spl_sha="$(cat "$sha_file" | grep 'u-boot-spl\.bin\.normal\.out$' | head -c64)"
    uboot_itb_sha="$(cat "$sha_file" | grep 'u-boot\.itb$' | head -c64)"
}

main "$@"
