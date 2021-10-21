---
title: Android bootloader analysis -- ABL(1)
date: 2021-10-18 19:48:00
tags:
- Android
- ABL
- Linux
- Bootloader
categories:
- [Linux, Android, Bootloader]
---

In my previous article ["Android Bootloader Analysis -- Aboot"](https://blog.inoki.cc/2021/10/17/android-bootloader-analysis-aboot-en/), I analyzed the overall boot flow and corresponding code of the previous generation of Aboot for Qualcomm platforms.

After 2016, the PBL of the MSM8996 (Snapdragon 820) platform loads the new XBL, followed by a chain load of ABL or Aboot (only for the MSM8996 platform where the XBL is not yet mature), which is a boot loader built on EDK II to replace Aboot, which can choose to stay in It can choose to stay in fastboot, boot to Android using the system kernel and ramdisk in the system directory, or boot to Recovery using the recovery ramdisk, depending on key combinations.

This article describes the code organization and general boot process of ABL. Due to space limitation, the code analysis for booting Linux and fastboot will be published in separate articles.

# Code Organization

The Qualcomm ABL source code can be found at [Code Aurora Forum](https://source.codeaurora.org/quic/la/abl/tianocore/edk2/)
).

The ABL is built on EDK II and the overall project structure is the standard EDK II source tree. This article uses the `uefi.lnx.3.0.r1` branch as written for analysis, committed as c4da6fcb959fa67cb2aa89007beebfab66226268.

In the Makefile of the project, the two most important build targets are

```makefile
ABL_FV_IMG := $(BUILD_ROOT)/FV/abl.fv
ABL_FV_ELF := $(BOOTLOADER_OUT)/... /... /unsigned_abl.elf
```

Of these, ``ABL_FV_IMG`` is the most important build target, which is the firmware (fv, firmware) built from ``QcomModulePkg``.

```makefile
ABL_FV_IMG: EDK_TOOLS_BIN
	@. . /edksetup.sh BaseTools && \
	build -p $(WORKSPACE)/QcomModulePkg/QcomModulePkg.dsc

    cp $(BUILD_ROOT)/FV/FVMAIN_COMPACT.Fv $(ABL_FV_IMG)
```

Whereas `ABL_FV_ELF` just calls `QcomModulePkg/Tools/image_header.py` to convert `abl.fv` to an ELF file that can be flushed to the abl partition in the device's EMMC or flash memory.

In `QcomModulePkg`, the firmware entry is `FV.FVMAIN_COMPACT`, which contains `FV.FVMAIN`, a module that encapsulates the base ARM stack, MMU, and other components provided by EDK II, and contains `QcomModulePkg/Application/ LinuxLoader/LinuxLoader.inf`, a Linux loader, is used to boot the firmware and load the Android Linux kernel on the ARM platform.

This LinuxLoader is a UEFI application and its program entry point is defined as follows.

```
ENTRY_POINT = LinuxLoaderEntry
```

It contains some modules from EDK II.

```
[Packages]
	ArmPkg/ArmPkg.dec
	MdePkg/MdePkg.dec
	EmbeddedPkg/EmbeddedPkg.dec
	ArmPlatformPkg/ArmPlatformPkg.dec
	MdeModulePkg/MdeModulePkg.dec
	QcomModulePkg/QcomModulePkg.dec
```

In the `Library` of `QcomModulePkg`, there are `FastbootLib`, `BootLib`, `zlib`, etc. The implementation of Fastboot is in `FastbootLib`, while `BootLib` contains the specific implementation for booting the Linux kernel, and `zlib` because Linux kernels are sometimes compressed.

# Boot process

In the `LinuxLoaderEntry` entry point function, the program first calls some basic platform code to set up the environment, then gets the boot verification status and device status with `DeviceInfoInit ()`, then uses `EnumeratePartitions ()` and ` UpdatePartitionEntries ()` to get and update the partition information.

If there is more than one boot slot (in this case, Android devices with A/B partitions, where A and B are generally two slots), find the activated slot and record it.

Next, it gets the keystroke status and sets the boot to fastboot flag when `SCAN_DOWN` is pressed, `SCAN_UP` for boot to recovery, and `SCAN_ESC` for reboot to Emergency Download (EDL) mode. The program then gets the reason for the reboot and sets the appropriate flag.

When not booting to fastboot, the boot image is loaded and verified, and if it is loaded and verified successfully, `BootLinux (&Info)` is called to boot the Linux kernel. Otherwise, call `FastbootInitialize ()` to initialize and run fastboot.

# Summary

This article has analyzed the project structure and overall boot process of ABL. In the next article, we will discuss the code flow for booting Linux normally (also including recovery booting).
