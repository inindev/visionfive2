
LDIST ?= $(shell cat "ubuntu/make_ubuntu_img.sh" | sed -n 's/\s*local ubu_dist=.\([[:alpha:]]\+\)./\1/p')


all: uboot dtb ubuntu
	@echo "all binaries ready"

ubuntu: uboot dtb ubuntu/mmc_4g.img
	@echo "ubuntu image ready"

ubuntuk: screen uboot dtb ubuntu/mmc_4g.img kernel
	sudo sh ubuntu/install_kernel.sh
	@echo "ubuntu with kernel image ready"

dtb: dtb/jh7110-starfive-visionfive-2-v1.3b.dtb
	@echo "device tree binaries ready"

kernel: screen kernel/linux-image-*_riscv64.deb
	@echo "kernel package is ready"

uboot: uboot/opensbi/build/platform/generic/firmware/fw_dynamic.bin uboot/u-boot-spl.bin.normal.out uboot/u-boot.itb
	@echo "u-boot binaries ready"

package-%: screen ubuntu
	@echo "building package for version $*"

	@rm -rfv distfiles
	@mkdir -v distfiles

	@install -vm 644 uboot/opensbi/build/platform/generic/firmware/fw_dynamic.bin uboot/u-boot-spl.bin.normal.out uboot/u-boot.itb distfiles
	@install -vm 644 dtb/jh7110-starfive-visionfive-2-v1.3b.dtb distfiles
	@install -vm 644 ubuntu/mmc_4g.img distfiles/visionfive2_$(LDIST)-$*.img
	@xz -zve8 distfiles/visionfive2_$(LDIST)-$*.img

	@cd distfiles ; sha256sum * | tee sha256sums.txt

packagek-%: ubuntuk package-%
	@echo "package with kernel $* ready"

clean:
	@rm -rfv distfiles
	sudo sh ubuntu/make_ubuntu_img.sh clean
	sh dtb/make_dtb.sh clean
	sh kernel/make_kernel.sh clean
	sh uboot/make_uboot.sh clean
	@echo "all targets clean"

screen:
ifeq ($(origin STY), undefined)
	$(error please start a screen session)
endif

ubuntu/mmc_4g.img:
	sudo sh ubuntu/make_ubuntu_img.sh nocomp

dtb/jh7110-starfive-visionfive-2-v1.3b.dtb:
	sh dtb/make_dtb.sh cp

kernel/linux-image-*_riscv64.deb:
	sh kernel/make_kernel.sh $(kver)

uboot/opensbi/build/platform/generic/firmware/fw_dynamic.bin uboot/u-boot-spl.bin.normal.out uboot/u-boot.itb:
	sh uboot/make_uboot.sh cp


.PHONY: all ubuntu ubuntuk dtb kernel uboot all package-* packagek-* clean screen

