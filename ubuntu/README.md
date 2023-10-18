## ubuntu mantic linux for the visionfive2

<i>Note: This script is intended to be run from a 64 bit risc-v device such as the starfive visionfive2.</i>

<br/>

**build ubuntu mantic using debootstrap**
```
sudo sh make_ubuntu_img.sh nocomp
```

<i>the build will produce the target file ```mmc_4g.img```</i>

<br/>

**copy the image to mmc media**
```
sudo su
cat mmc_4g.img > /dev/sdX
sync
```

<br/>

**multiple build options are available by editing make_ubuntu_img.sh**
```
media='mmc_4g.img' # or block device '/dev/sdX'
ubu_dist='mantic'
hostname='visionfive2'
acct_uid='ubuntu'
acct_pass='ubuntu'
extra_pkgs='curl, pciutils, nano, unzip, wget, xxd, xz-utils, zip, zstd'
```
