---
title: Android 启动加载器分析 —— ABL(1)
date: 2021-10-18 19:48:00
tags:
- Android
- ABL
- Linux
- Bootloader
- 中文
categories:
- [Linux, Android, Bootloader]
---

我的前一篇文章[《Android 启动加载器分析 —— Aboot》](https://blog.inoki.cc/2021/10/17/android-bootloader-analysis-aboot/)中分析了高通平台前代的 Aboot 的整体启动流程和相应的代码。

在 2016 年之后，MSM8996（Snapdragon 820）平台的 PBL 加载全新的 XBL，紧接着链式加载 ABL 或 Aboot（仅对于 XBL 还未成熟的 MSM8996 平台），这个程序是基于 EDK II 构建的用来替换 Aboot 的启动加载器，它可以根据按键组合选择留在 fastboot、使用系统 kernel 和在系统目录的 ramdisk 启动到 Android 系统、或是使用 recovery 的 ramdisk 启动到 Recovery。

本文介绍 ABL 的代码组织和大致启动流程，由于篇幅限制，对于启动 Linux 和 fastboot 的代码解析将会单独发各自的文章。

# 代码组织

高通平台的 ABL 源码可以在 [Code Aurora Forum](https://source.codeaurora.org/quic/la/abl/tianocore/edk2/) 处找到。

ABL 是基于 EDK II 构建的，整体的项目结构是标准的 EDK II 源码树。本文使用成文时的 `uefi.lnx.3.0.r1` 分支来分析，提交为 c4da6fcb959fa67cb2aa89007beebfab66226268。

在项目的 Makefile 中，最重要的两个构建目标是：

```makefile
ABL_FV_IMG := $(BUILD_ROOT)/FV/abl.fv
ABL_FV_ELF := $(BOOTLOADER_OUT)/../../unsigned_abl.elf
```

其中，`ABL_FV_IMG` 是最重要的构建目标，它是从 `QcomModulePkg` 构建的 firmware（fv，固件）：

```makefile
ABL_FV_IMG: EDK_TOOLS_BIN
	@. ./edksetup.sh BaseTools && \
	build -p $(WORKSPACE)/QcomModulePkg/QcomModulePkg.dsc

    cp $(BUILD_ROOT)/FV/FVMAIN_COMPACT.Fv $(ABL_FV_IMG)
```

而 `ABL_FV_ELF` 则只是调用 `QcomModulePkg/Tools/image_header.py` 来把 `abl.fv` 转换为一个 ELF 文件，可以刷写到设备的 EMMC 或闪存中的 abl 分区。

在 `QcomModulePkg` 中，固件的入口是 `FV.FVMAIN_COMPACT`，它包含了 `FV.FVMAIN`，在这个模块里，囊括了 EDK II 提供的基础 ARM 栈、MMU 等组件，并包含了 `QcomModulePkg/Application/LinuxLoader/LinuxLoader.inf` 这个 Linux 的加载器，用来在 ARM 平台上将这个固件启动并加载 Android 的 Linux 内核。

这个 LinuxLoader 是一个 UEFI 应用程序，它的程序入口点定义如下：

```
ENTRY_POINT                    = LinuxLoaderEntry
```

它包含了 EDK II 中的一些模块：

```
[Packages]
	ArmPkg/ArmPkg.dec
	MdePkg/MdePkg.dec
	EmbeddedPkg/EmbeddedPkg.dec
	ArmPlatformPkg/ArmPlatformPkg.dec
	MdeModulePkg/MdeModulePkg.dec
	QcomModulePkg/QcomModulePkg.dec
```

其中，在 `QcomModulePkg` 的 `Library` 中，有 `FastbootLib`、`BootLib`、`zlib` 等库，Fastboot 的实现就在 `FastbootLib` 中，而 `BootLib` 中包含了启动 Linux 内核的具体实现，至于 `zlib` 则是因为 Linux 内核有时是被压缩了的。

# 启动流程

在 `LinuxLoaderEntry` 入口点的函数中，程序首先调用一些基础的平台代码设置环境，然后通过 `DeviceInfoInit ()` 获取启动验证状态和设备状态，再使用 `EnumeratePartitions ()` 和 `UpdatePartitionEntries ()` 获取并更新分区信息。

如果存在多个启动 slot 的话（这里指有 A/B 分区的 Android 设备，其中 A 和 B 一般即为两个 slot），就寻找已激活的 slot 并记录。

紧接着获取按键状态，在 `SCAN_DOWN` 按下时设置启动至 fastboot 的标识，`SCAN_UP` 为启动至 recovery 的表示，而 `SCAN_ESC` 按下时则重启设备至 Emergency Download（EDL）模式。然后程序获取重启的原因并设置相应标识。

在不启动至 fastboot 时，加载并验证启动镜像，若加载并验证成功，则调用 `BootLinux (&Info)` 启动 Linux 内核。否则调用 `FastbootInitialize ()` 初始化并运行 fastboot。

# 构建

构建 EDK II 的基础工具需要主机指令集的 GCC 工具集，而 `QcomModulePkg` 需要 LLVM 和 CLANG，因此需要安装这两个工具。之后使用以下命令编译：

```bash
CLANG_PREFIX=aarch64-linux-gnu- PYTHON_COMMAND=python2 make
```

这里由于我的系统 python 指向的是 python3，而 EDK II 基础工具集需要 python2，因此我指定了使用 python2 为默认的解释器。

# 总结

本文分析了 ABL 的项目结构和整体启动流程。下篇文章中会讨论正常启动 Linux（也包含 recovery 的启动）的代码流程。
