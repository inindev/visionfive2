## linux device tree for the visionfive2

<br/>

**build device the tree for the visionfive2**
```
sh make_dtb.sh
```

<i>the build will produce the target file jh7110-starfive-visionfive-2-v1.3b.dtb</i>

<br/>

**optional: create symbolic links**
```
sh make_dtb.sh links
```

<i>convenience links to jh7110-starfive-visionfive-2-v1.3b.dts and other relevant device tree files will be created in the project directory</i>

<br/>

**optional: clean target**
```
sh make_dtb.sh clean
```

