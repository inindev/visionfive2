## u-boot 2023.10+ for the visionfive2

<i>Note: This script is intended to be run from a 64 bit risc-v device such as an visionfive2.</i>

<br/>

**1. build u-boot images for the visionfive2**
```
sh make_uboot.sh
```

<i>the build will produce the target files u-boot-spl.bin.normal.out, and u-boot.itb</i>

<br/>

**2. copy u-boot to mmc or file image**
```
sudo dd bs=4K seek=512 if=u-boot-spl.bin.normal.out of=/dev/sdX conv=notrunc
sudo dd bs=4K seek=1024 if=u-boot.itb of=/dev/sdX conv=notrunc,fsync
```
* note: to write to emmc while booted from mmc, use ```/dev/mmcblk0``` for ```/dev/sdX```

<br/>

**4. optional: clean target**
```
sh make_uboot.sh clean
```

<br/>

**reference: storage devices**
```
/dev/mmcblk0  -> internal emmc
/dev/mmcblk1  -> removable mmc
```

<br/>

