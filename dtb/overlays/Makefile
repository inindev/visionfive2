#
# Copyright (C) 2023, John Clark <inindev@gmail.com>
#

LDIST := $(shell cat "../../ubuntu/make_ubuntu_img.sh" | sed -n 's/\s*local ubu_dist=.\([[:alpha:]]\+\)./\1/p')
CDIR := "../../ubuntu/cache.$(LDIST)/overlays"

targets = \
	rtc-ds3231.dtbo \
	rtc-pcf8523.dtbo

dtbo: $(targets)
	@echo "overlay files ready"

%.dtbo:
	@echo making $@
	@dtc -@ -Hepapr -I dts -O dtb -o $@ $*-overlay.dts

install: dtbo
	@sudo mkdir -p $(CDIR)
	@sudo cp -v *.dtbo $(CDIR)

clean:
	@rm -v *.dtbo


.PHONY: dtbo install clean
