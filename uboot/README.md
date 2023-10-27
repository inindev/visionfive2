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

---
## booting from spi nor flash

**1. boot from removable mmc**

[Follow the instructions](https://github.com/inindev/visionfive2#ubuntu-mantic-setup) for creating bootable mmc media.

Note: Configure the [boot switch setting](https://github.com/inindev/visionfive2/blob/main/misc/vf2_mmc.jpg) needed to select mmc boot.

<br/>

**2. install mtd-utils**

once linux is booted from the removable mmc, install mtd-utils
```
sudo apt update
sudo apt -y install mtd-utils
```

<br/>

**3. erase spi flash**
```
sudo flash_erase /dev/mtd0 0 0
sudo flash_erase /dev/mtd1 0 0
sudo flash_erase /dev/mtd2 0 0
sudo flash_erase /dev/mtd3 0 0
```

<br/>

**4. write u-boot to spi flash**
```
wget https://github.com/inindev/visionfive2/releases/download/v23.10-6.6-rc7/u-boot-spl.bin.normal.out
wget https://github.com/inindev/visionfive2/releases/download/v23.10-6.6-rc7/u-boot.itb
sudo flashcp -v u-boot-spl.bin.normal.out /dev/mtd0
sudo flashcp -v u-boot.itb /dev/mtd2
```

<br/>

Once the spi flash has been written, the boot sequence should prefer removable mmc media if present, then boot m.2 nvme ssd.

Note: Configure the [boot switch setting](https://github.com/inindev/visionfive2/blob/main/misc/vf2_spi.jpg) needed to select spi boot.

