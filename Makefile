
LDIST ?= $(shell cat "ubuntu/make_ubuntu_img.sh" | sed -n 's/\s*local ubu_dist=.\([[:alpha:]]\+\)./\1/p')


all: uboot dtb ubuntu
	@echo "all binaries ready"

ubuntu: uboot dtb ubuntu/mmc_4g.img
	@echo "ubuntu image ready"

dtb: dtb/jh7110-starfive-visionfive-2-v1.3b.dtb
	@echo "device tree binaries ready"

uboot: uboot/opensbi/build/platform/generic/firmware/fw_dynamic.bin uboot/u-boot-spl.bin.normal.out uboot/u-boot.itb
	@echo "u-boot binaries ready"

package-%: all
	@echo "building package for version $*"

	@rm -rfv distfiles
	@mkdir -v distfiles

	@cp -v uboot/opensbi/build/platform/generic/firmware/fw_dynamic.bin uboot/u-boot-spl.bin.normal.out uboot/u-boot.itb distfiles
	@cp -v dtb/jh7110-starfive-visionfive-2-v1.3b.dtb distfiles
	@cp -v ubuntu/mmc_4g.img distfiles/visionfive2_$(LDIST)-$*.img
	@xz -zve8 distfiles/visionfive2_$(LDIST)-$*.img

	@cd distfiles ; sha256sum * > sha256sums.txt

clean:
	@rm -rfv distfiles
	sudo sh ubuntu/make_ubuntu_img.sh clean
	sh dtb/make_dtb.sh clean
	sh uboot/make_uboot.sh clean
	@echo "all targets clean"

ubuntu/mmc_4g.img:
	sudo sh ubuntu/make_ubuntu_img.sh nocomp

dtb/jh7110-starfive-visionfive-2-v1.3b.dtb:
	sh dtb/make_dtb.sh cp

uboot/u-boot-spl.bin.normal.out uboot/u-boot.itb:
	sh uboot/make_uboot.sh cp


.PHONY: ubuntu dtb uboot all package-* clean

