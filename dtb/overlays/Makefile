#
# Copyright (C) 2023, John Clark <inindev@gmail.com>
#

DDIST ?= $(shell cat "../../debian/make_debian_img.sh" | sed -n 's/\s*local deb_dist=.\([[:alpha:]]\+\).*/\1/p')
UDIST ?= $(shell cat "../../ubuntu/make_ubuntu_img.sh" | sed -n 's/\s*local ubu_dist=.\([[:alpha:]]\+\).*/\1/p')

DCDIR := "../../ubuntu/cache.$(DDIST)/overlays"
UCDIR := "../../ubuntu/cache.$(UDIST)/overlays"

targets = \
	rtc-ds3231.dtbo \
	rtc-pcf8523.dtbo

dtbo: $(targets)
	@echo "overlay files ready"

%.dtbo:
	@echo making $@
	@dtc -@ -Hepapr -I dts -O dtb -o $@ $*-overlay.dts

install: dtbo
	@sudo mkdir -p $(DCDIR)
	@sudo cp -v *.dtbo $(DCDIR)
	@sudo mkdir -p $(UCDIR)
	@sudo cp -v *.dtbo $(UCDIR)

clean:
	@rm -v *.dtbo


.PHONY: dtbo install clean
