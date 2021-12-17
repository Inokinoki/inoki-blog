---
title: Build and run Hello World on OVMF Qemu
date: 2021-12-17 13:47:00
tags:
- Qemu
- EDK2
categories:
- [EDK2]
---

This post records how I build and run an EDK2 HelloWorld on Qemu, based on OVMF UEFI shell.

# Prepare environment

Clone edk2:

```
git clone --recursive https://github.com/tianocore/edk2.git
```

Enter edk2 build environment:

```
. edksetup.sh BaseTools
```

Build base tools:

```
make -C <edk2-dir>/BaseTools/Source/C
```

# Create and build HelloWorld

Build HelloWorld package for x64 architecture and using GCC:

```
build -a X64 -p HelloWorldPkg/HelloWorldPkg.dsc -t GCC5
```

The built `HelloWorld.efi` is under `Build/HelloWorldPkg/DEBUG_GCC5/X64`, we can run it under UEFI shell on an x64 PC or an emulator.

# Build edk2 for OVMF

Modify the following contents in `Conf/target.txt`:

```
ACTIVE_PLATFORM       = OvmfPkg/OvmfPkgX64.dsc
TARGET_ARCH           = X64
TOOL_CHAIN_TAG        = GCC5
```

Then, build it:

```
build
```

# Boot and run Hello World

Make an image to store efi files:

```
dd if=/dev/null of=example.img bs=1M seek=512
mount -t ext4 -o loop example.img /mnt/example
cp Build/HelloWorldPkg/DEBUG_GCC5/X64/HelloWorld.efi /mnt/example
umount /mnt/example
```

Run OVMF as the firmware and mount the images:

```
qemu-system-x86_64 -L . --bios ./ovmf.fd -hda ./example.img
```

In the UEFI shell, list disk mappings:

```
map -r
Mapping table
    FS0: ...
        ...
    BLK1: ...
        ...
```

The files are under fs0, list them:

```
ls fs0:\
... HelloWorld.efi
```

Run our Hello Wolrd:

```
fs0:\HelloWorld.efi
Hello World!
```

# Conclusion

In this post, I noted all the steps to build an edk2 HelloWorld. I will write some interesting UEFI applications sooner.
