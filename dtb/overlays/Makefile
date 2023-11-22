#
# Copyright (C) 2023, John Clark <inindev@gmail.com>
#

targets = \
	rtc-ds3231.dtbo \
	rtc-pcf8523.dtbo

dtbo: $(targets)
	@echo "overlay files ready"

%.dtbo:
	@echo making $@
	@dtc -@ -Hepapr -I dts -O dtb -o $@ $*-overlay.dts

clean:
	@rm *.dtbo


.PHONY: dtbo clean

