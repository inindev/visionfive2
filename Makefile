#
# Copyright (C) 2023, John Clark <inindev@gmail.com>
#

DDIST ?= $(shell cat "debian/make_debian_img.sh" | sed -n 's/\s*local deb_dist=.\([[:alpha:]]\+\).*/\1/p' | sed 's/sid/trixie/')
UDIST ?= $(shell cat "ubuntu/make_ubuntu_img.sh" | sed -n 's/\s*local ubu_dist=.\([[:alpha:]]\+\).*/\1/p')

all: uboot dtb dtbo debian ubuntu
	@echo "all binaries ready"

debian: screen uboot dtb dtbo debian/mmc_2g.img kernel
	sudo sh debian/install_kernel.sh
	@echo "debian with kernel image ready"

ubuntu: screen uboot dtb dtbo ubuntu/mmc_2g.img kernel
	sudo sh ubuntu/install_kernel.sh
	@echo "ubuntu with kernel image ready"

dtb: dtb/jh7110-starfive-visionfive-2-v1.3b.dtb
	@echo "device tree binaries ready"

dtbo: dtb/overlays/rtc-ds3231.dtbo dtb/overlays/rtc-pcf8523.dtbo
	$(MAKE) -C dtb/overlays install

kernel: screen kernel/linux-image-*_riscv64.deb
	@echo "kernel package is ready"

uboot: uboot/opensbi/build/platform/generic/firmware/fw_dynamic.bin uboot/u-boot-spl.bin.normal.out uboot/u-boot.itb
	@echo "u-boot binaries ready"

package-%: screen debian ubuntu
	@echo "building package for version $*"

	@rm -rfv distfiles
	@mkdir -v distfiles

	@install -vm 644 uboot/opensbi/build/platform/generic/firmware/fw_dynamic.bin uboot/u-boot-spl.bin.normal.out uboot/u-boot.itb distfiles
	@install -vm 644 dtb/jh7110-starfive-visionfive-2-v1.3b.dtb distfiles
	@install -vm 644 kernel/linux-image-*_riscv64.deb distfiles
	@install -vm 644 kernel/linux-headers-*_riscv64.deb distfiles
	@install -vm 644 debian/mmc_2g.img distfiles/visionfive2_$(DDIST)-$*.img
	@install -vm 644 ubuntu/mmc_2g.img distfiles/visionfive2_$(UDIST)-$*.img
	@xz -zve8 distfiles/visionfive2_$(DDIST)-$*.img
	@xz -zve8 distfiles/visionfive2_$(UDIST)-$*.img

	@cd distfiles ; sha256sum * | tee sha256sums.txt

clean:
	@rm -rfv distfiles
	sudo sh debian/make_debian_img.sh clean
	sudo sh ubuntu/make_ubuntu_img.sh clean
	sh dtb/make_dtb.sh clean
	$(MAKE) -C dtb/overlays clean
	sh kernel/make_kernel.sh clean
	sh uboot/make_uboot.sh clean
	@echo "all targets clean"

screen:
ifeq ($(STY)$(TMUX),)
	$(error please start a screen or tmux session)
endif

debain/mmc_2g.img:
	sudo sh ubuntu/make_debian_img.sh nocomp

ubuntu/mmc_2g.img:
	sudo sh ubuntu/make_ubuntu_img.sh nocomp

dtb/jh7110-starfive-visionfive-2-v1.3b.dtb:
	sh dtb/make_dtb.sh cp

kernel/linux-image-*_riscv64.deb:
	sh kernel/make_kernel.sh $(kver)

uboot/opensbi/build/platform/generic/firmware/fw_dynamic.bin uboot/u-boot-spl.bin.normal.out uboot/u-boot.itb:
	sh uboot/make_uboot.sh cp


.PHONY: all debian ubuntu dtb kernel uboot all package-* packagek-* clean screen
