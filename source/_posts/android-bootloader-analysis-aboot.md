---
title: Android 启动加载器分析 —— Aboot
date: 2021-10-17 10:48:00
tags:
- Android
- Aboot
- Linux
- Bootloader
- 中文
categories:
- [Linux, Android, Bootloader]
---

已经有很多文章解析过 Android 在高通平台的启动流程了。从我翻译的[【译】高通 Android 设备的启动信任链](https://blog.inoki.cc/2021/10/17/android-qcom-chain-of-trust/)中，可以总结为下：

- Aboot：在 MSM8994（Snapdragon 810）之前，设备首先加载高通的 bootrom（PBL）和 SBL 来初始化一些硬件，紧接着交给 Aboot，这个程序是在 LittleKernel 系统的基础上构建的一个应用程序，它包含了 fastboot，可以实现正常启动 boot 分区的镜像（包含 Linux Kernel 和 ramdisk）、或是根据特定按键组合启动 recovery 中的镜像（一般为 recovery）或留在 Aboot 中的 Fastboot。当使用 `adb reboot bootloader` 时，就是启动到这里并停留在 fastboot 中；

- XBL/ABL：在 MSM8996（Snapdragon 820）之后，PBL 加载全新的 XBL，紧接着链式加载 ABL，这个程序是基于 EDK II 构建的用来替换 Aboot 的启动加载器（实际上在 MSM8996 平台，由于 XBL 和 ABL 不够成熟，仍使用 Aboot，由 XBL 来对其进行加载），它可以根据按键组合选择留在 fastboot、使用系统 kernel 和在系统目录的 ramdisk 启动到 Android 系统、或是使用 recovery 的 ramdisk 启动到 Recovery。

这两种启动模式中，Aboot 和 ABL 的源码都可以在 Google 或是 Code Aurora Forum 处找到：

- CAF Aboot：[https://source.codeaurora.org/quic/la/kernel/lk/](https://source.codeaurora.org/quic/la/kernel/lk/)
- CAF ABL：[https://source.codeaurora.org/quic/la/abl/tianocore/edk2/](https://source.codeaurora.org/quic/la/abl/tianocore/edk2/)

可以看到，Aboot 的源码树名为 lk，即 LittleKernel 的简称，它是一个对称多处理（SMP）的小型操作系统内核，而 Aboot 是在这个操作系统的基础上构建的一个设备相关的应用程序。本文将对 Aboot 作为应用程序部分的源码进行简要分析（不包括加密与镜像验证），并涉及一部分设备相关代码。

# 代码组织

这里使用 CAF Aboot 中 commit d37db810993015ea77cc5231a95250b250f4eb07（在成文时的 master 分支提交）为参考。

作为一个应用程序，Aboot 的源码在 `app/aboot/` 中，核心文件为 `aboot.c` 和 `fastboot.c`，除此之外其中还有一些显示硬件相关的辅助代码。根据 SoC 不同，硬件相关的代码和定义分布在 `platform/` 和 `target/` 中，大部分设备驱动都位于 `dev/` 中。而 `arch` 为架构相关代码，`kernel` 为实际的 lk 内核代码。

# 整体流程

启动过程中，lk 被加载，完成架构和平台相关的初始化之后，启动 Aboot 这个应用程序。在 `aboot.c` 代码中，以下代码注册 Aboot 为一个应用程序，并将 `aboot_init` 作为入口：

```c
APP_START(aboot)
	.init = aboot_init,
APP_END
```

在这个函数中，会检测设备的储存设备类型为 EMMC 还是闪存，并根据相应的 page 大小设置 `page_size` 和 `page_mask` 两个全局变量，这两个变量在之后用于确定从储存设备中加载的内核、ramdisk 等组件的大小。

然后读取设备的基础信息和 oem 解锁信息，储存到以下结构体中：

```c
struct device_info
{
	unsigned char magic[DEVICE_MAGIC_SIZE];
	bool is_unlocked;
	bool is_tampered;
	bool is_verified;
	bool charger_screen_enabled;
	char display_panel[MAX_PANEL_ID_LEN];
	char bootloader_version[MAX_VERSION_LEN];
	char radio_version[MAX_VERSION_LEN];
};
```

然后根据设备定义初始化屏幕（如果有的话）、读取设备序列号。

紧接着就进入启动模式的确定：

- 如果是 force reset（一般为长按电源键重启），则直接进入正常系统启动，否则会去检测按键；
- 如果是音量上下键同时按下（即 `keys_get_state(KEY_VOLUMEUP) && keys_get_state(KEY_VOLUMEDOWN)`），则重启设备并进入高通的 dload 模式；
- 如果音量上键或者 Home 键被按下，标记为进入 recovery 模式；
- 如果音量下键或者 Back 键被按下，标记为进入 fastboot 模式；
- 如果有预先设置的 reboot 模式（比如 `adb reboot` 设置的），则启动到相应的模式；
- 最后，检测是否有 fastboot 启动模式的标记被设置了，如果没有，则根据 recovery 的标记设置启动所用的镜像所在分区，并从 EMMC 或闪存启动到 Linux（调用函数 `boot_linux_from_xxxx()`），否则就留在 Aboot 中，注册 fastboot 可用的命令并初始化 fastboot。

# 正常启动 Linux（包括 Recovery）

在正常启动和启动至 Recovery 两种模式下，Aboot 都会从启动所用分区（对正常启动来说一般为 boot 分区，而 Recovery 模式为 recovery 分区）加载内核和 ramdisk。

一个正常的启动镜像由 header 储存元信息，剩下的部分用来存放内核、ramdisk 等组件。当刷入镜像时，分区的开始应当可以被读取到以下结构中：

```c
struct boot_img_hdr
{
    unsigned char magic[BOOT_MAGIC_SIZE];

    unsigned kernel_size;  /* size in bytes */
    unsigned kernel_addr;  /* physical load addr */

    unsigned ramdisk_size; /* size in bytes */
    unsigned ramdisk_addr; /* physical load addr */

    unsigned second_size;  /* size in bytes */
    unsigned second_addr;  /* physical load addr */

    unsigned tags_addr;    /* physical addr for kernel tags */
    unsigned page_size;    /* flash page size we assume */
    unsigned dt_size;      /* device_tree in bytes */
    unsigned unused;    /* future expansion: should be 0 */

    unsigned char name[BOOT_NAME_SIZE]; /* asciiz product name */
    
    unsigned char cmdline[BOOT_ARGS_SIZE];

    unsigned id[8]; /* timestamp / checksum / sha1 / etc */
};
```

其中 `kernel_size` 和 `ramdisk_size` 是要加载的内核和 ramdisk 的大小，对应的 `xxx_addr` 是需要加载到的内存的物理地址（取决于配置和设备）。

在经过内核、ramdisk（也可能有 device tree 和 secondary bootloader，这里暂时忽略）的加载前，若设备未解锁，则需要验证内核并在验证通过的情况加载，对于已经解锁的设备，Aboot 会直接加载。

然后使用读取的和准备好的参数调用 `boot_linux` 函数准备启动内核。

```c
boot_linux((void *)hdr->kernel_addr, (void *)hdr->tags_addr,
		   (const char *)hdr->cmdline, board_machtype(),
		   (void *)hdr->ramdisk_addr, hdr->ramdisk_size);
```

在这个函数中，Aboot 会先根据设备更新内核的命令行参数，比如加入基带的设备类型、储存设备类型等。然后根据参数更新 device tree（如果存在）。

之后就要准备启动内核了，硬件需要由内核管理，因此 lk 会先将一些硬件关闭：

- 使用 `target_display_shutdown()` 关闭显示；
- 调用 `target_uninit()` 取消 lk 中进行的硬件初始化；
- 调用 `enter_critical_section()` 禁用设备中断；
- 初始化 Watchdog 来监控早期的内核崩溃 `msm_wdog_init()`；
- 调用 `platform_uninit()` 清理之前 lk 进行的的平台初始化；
- 显式让缓存失效 `arch_disable_cache(UCACHE)` 并关闭内存管理单元（MMU）`arch_disable_mmu()`。

最后，检测内核的 Magic Number 是否为 64 位，从而通过 `scm_elexec_call` 进入内核，否则直接以 32 位模式进入 32 位内核。

# 进入 fastboot 模式

如果启动至 fastboot，会先调用 `aboot_fastboot_register_commands()` 注册可用的 fastboot 命令，然后使用 `fastboot_init` 初始化并进入 fastboot 模式。注意，这里我们仍会在 Aboot 中，可以说 fastboot 是 Aboot 的一部分。

## 注册 fastboot 命令

在注册命令时，`fastboot_register` 是一个很重要的函数，它接受命令和回调函数作为参数。在这个版本中，可用的命令有：

```c
{"flash:", cmd_flash},
{"erase:", cmd_erase},
{"boot", cmd_boot},
{"continue", cmd_continue},
{"reboot", cmd_reboot},
{"reboot-bootloader", cmd_reboot_bootloader},
{"oem unlock", cmd_oem_unlock},
{"oem unlock-go", cmd_oem_unlock_go},
{"oem lock", cmd_oem_lock},
{"oem verified", cmd_oem_verified},
{"oem device-info", cmd_oem_devinfo},
{"preflash", cmd_preflash},
{"oem enable-charger-screen", cmd_oem_enable_charger_screen},
{"oem disable-charger-screen", cmd_oem_disable_charger_screen},
{"oem select-display-panel", cmd_oem_select_display_panel},
```

除此之外，`fastboot_publish` 可以添加一些变量，可以说是 fastboot 的环境变量。

## 初始化并进入 fastboot

调用的 `fastboot_init` 函数定义在 `fastboot.c` 中：

```c
int fastboot_init(void *base, unsigned size);
```

其首先调用 `target_fastboot_init()` 初始化特定设备的硬件，比较重要的是 USB 接口。这是一个设备特定的函数，比如对于 MSM8974 设备，它的实现如下：

```c
void target_fastboot_init(void)
{
	/* Set the BOOT_DONE flag in PM8921 */
	pm8x41_set_boot_done();

#ifdef SSD_ENABLE
	clock_ce_enable(SSD_CE_INSTANCE_1);
	ssd_load_keystore_from_emmc();
#endif
}
```

位于 `target/msm8974/init.c` 中。

在这之后，USB 硬件应当已经设置好了，Aboot 就在 USB 接口上配置并初始化一个 USB UDC 设备，用来接收和发送 fastboot 相关的 USB 包。

最后，创建一个 lk 的线程来处理 fastboot 相关事件，并初始化 USB 的接口来接收 fastboot 命令。

# 结论

这篇文章简要描述和分析了 2016 年之前、基于 lk 内核的 Android 使用的 Aboot 启动加载器的实现，但并没有太过深入 lk 针对某一平台或者某一架构进行构建和设置的内容。希望对您有所帮助。

## 补充

- 请注意，无论 ARM32 还是 AArch64 的设备，都会在 32 位模式下运行 lk 和其中的应用程序 Aboot，在加载内核时才会确定使用的内核为 32 位或是 64 位，进而通过相应的启动模式启动内核。

- 在加载的时候，由于 MMU 可能存在，Aboot 通过 VA() 宏将物理地址映射到 lk 读取到的虚拟地址上，并把内核加载到该地址。
