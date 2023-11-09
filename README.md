# visionfive2
#### *Stock Ubuntu riscv64 Linux for the StarFive VisionFive 2*

This stock Ubuntu riscv64 Linux image is built directly from official ports packages using the Debian [debootstrap](https://packages.ubuntu.com/mantic/debootstrap) utility.

Being an unmodified [ubuntu-ports](http://ports.ubuntu.com/ubuntu-ports/dists/mantic/main/binary-riscv64/) build, patches are directory available from the Ubuntu repos using the stock **apt** package manager.

If you want to run out-of-the-box Ubuntu Linux on your StarFive VisionFive 2 riscv64 device, this is the way to do it.

<br/>

---
### ubuntu mantic setup

<br/>

**1. download image**
```
wget https://github.com/inindev/visionfive2/releases/download/v23.10-6.6.1/visionfive2_mantic-v23.10-6.6.1.img.xz
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
xzcat visionfive2_mantic-v23.10-6.6.1.img.xz > /dev/sdX
sync
```

#### when the micro sd has finished imaging, eject and use it to boot the visionfive2 to finish setup
#### Note the [boot switch configuration setting](https://github.com/inindev/visionfive2/blob/main/misc/vf2_mmc.jpg) needed to select mmc boot.

<br/>

**4. login account**
```
login id: ubuntu
password: ubuntu
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

**7. lockout and/or delete ubuntu account**
```
sudo passwd -l ubuntu
sudo chsh -s /usr/sbin/nologin ubuntu
```

```
sudo deluser --remove-home ubuntu
sudo rm /etc/sudoers.d/ubuntu
```

<br/>

**8. change hostname (optional)**
```
sudo nano /etc/hostname
sudo nano /etc/hosts
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
wget https://github.com/inindev/visionfive2/releases/download/v23.10-6.6.1/u-boot-spl.bin.normal.out
wget https://github.com/inindev/visionfive2/releases/download/v23.10-6.6.1/u-boot.itb
sudo flashcp -v u-boot-spl.bin.normal.out /dev/mtd0
sudo flashcp -v u-boot.itb /dev/mtd2
```

<br/>

Once the spi flash has been written, the boot sequence should prefer removable mmc media if present, then boot m.2 nvme ssd.

Note: Configure the [boot switch setting](https://github.com/inindev/visionfive2/blob/main/misc/vf2_spi.jpg) needed to select spi boot.

<br />

---

### building ubuntu mantic riscv64 for the visionfive2 from scratch

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

**2. run the ubuntu build script**
```
cd ubuntu
sudo sh make_ubuntu_img.sh
```
* note: edit the build script to change various options: ```nano make_ubuntu_img.sh```

<br/>

**3. the output if the build completes successfully**
```
mmc_4g.img.xz
```

<br/>
