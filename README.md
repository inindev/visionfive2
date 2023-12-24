# visionfive2
#### *Debian riscv64 Linux for the StarFive VisionFive 2*

This Debian riscv64 Linux image is built directly from official packages using the Debian [debootstrap](https://wiki.debian.org/Debootstrap) utility, see: https://github.com/inindev/visionfive2/blob/main/debian/make_debian_img.sh#L132

Most patches are directly available from the Debian repos using the built-in apt package manager, see: https://github.com/inindev/visionfive2/blob/main/debian/make_debian_img.sh#L354-L361

Note: The kernel in this bundle is from kernel.org and will not get updates from debian.

<br/>

---
### debian trixie setup

<br/>

**1. download image**
```
wget https://github.com/inindev/visionfive2/releases/download/v13-6.6.5/visionfive2_trixie-v13-6.6.5.img.xz
```

<br/>

**2. determine the location of the target micro sd card**

 * before plugging-in device
```
ls -l /dev/sd*
ls: cannot access '/dev/sd*': No such file or directory
```

 * after plugging-in device
```
ls -l /dev/sd*
brw-rw---- 1 root disk 8, 0 Apr 10 15:56 /dev/sda
```
* note: for mac, the device is ```/dev/rdiskX```

<br/>

**3. in the case above, substitute 'a' for 'X' in the command below (for /dev/sda)**
```
sudo su
xzcat visionfive2_trixie-v13-6.6.5.img.xz > /dev/sdX
sync
```

#### when the micro sd has finished imaging, eject and use it to boot the visionfive2 to finish setup
#### Note the [boot switch configuration setting](https://github.com/inindev/visionfive2/blob/main/misc/vf2_mmc.jpg) needed to select mmc boot.

<br/>

**4. login account**
```
login id: debian
password: debian
```

<br/>

**5. take updates**
```
sudo apt update
sudo apt upgrade
```

<br/>

**6. create account & login as new user**
```
sudo adduser youruserid
echo '<youruserid> ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/<youruserid>
sudo chmod 440 /etc/sudoers.d/<youruserid>
```

<br/>

**7. lockout and/or delete debian account**
```
sudo passwd -l debain
sudo chsh -s /usr/sbin/nologin debian
```

```
sudo deluser --remove-home debian
sudo rm /etc/sudoers.d/debian
```

<br/>

**8. change hostname (optional)**
```
sudo nano /etc/hostname
sudo nano /etc/hosts
```

<br/>

---
### installing on m.2 nvme media

<br/>

**1. boot from removable mmc**

[Follow the instructions](https://github.com/inindev/visionfive2#debian-trixie-setup) for creating bootable mmc media.

**2. download and copy the image file on to the nvme media**
```
wget https://github.com/inindev/visionfive2/releases/download/v13-6.6.5/visionfive2_trixie-v13-6.6.5.img.xz
sudo su
xzcat visionfive2_trixie-v13-6.6.5.img.xz > /dev/nvme0n1
sync
```

**3. the u-boot partitions are not used on nvme media and can be removed**
```
sfdisk --delete /dev/nvme0n1 1
sfdisk --delete /dev/nvme0n1 2
sfdisk -r /dev/nvme0n1
```

**4. remove mmc media and reboot**

<br/>

---
### booting from spi nor flash

<br/>

**1. boot from removable mmc**

[Follow the instructions](https://github.com/inindev/visionfive2#debian-trixie-setup) for creating bootable mmc media.

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
wget https://github.com/inindev/visionfive2/releases/download/v13-6.6.5/u-boot-spl.bin.normal.out
wget https://github.com/inindev/visionfive2/releases/download/v13-6.6.5/u-boot.itb
sudo flashcp -v u-boot-spl.bin.normal.out /dev/mtd0
sudo flashcp -v u-boot.itb /dev/mtd2
```

<br/>

Once the spi flash has been written, the boot sequence should prefer removable mmc media if present, then boot m.2 nvme ssd.

Note: Configure the [boot switch setting](https://github.com/inindev/visionfive2/blob/main/misc/vf2_spi.jpg) needed to select spi boot.

<br/>

---

### building debian trixie riscv64 for the visionfive2 from scratch

<br/>

The build script builds native riscv64 binaries, and thus needs to be run from an riscv64 device such as visionfive2 running 
a 64 bit risc-v linux.

<br/>

**1. clone the repo**
```
git clone https://github.com/inindev/visionfive2.git
cd visionfive2
```

<br/>

**2. run the debian build script**
```
cd debian
sudo sh make_debian_img.sh
```
* note: edit the build script to change various options: ```nano make_debian_img.sh```

<br/>

**3. the output if the build completes successfully**
```
mmc_2g.img.xz
```

<br/>
