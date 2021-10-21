---
title: Android bootloader analysis -- Aboot
date: 2021-10-17 10:48:00
tags:
- Android
- Aboot
- Linux
- Bootloader
categories:
- [Linux, Android, Bootloader]
---

There are already many articles that explain the boot process of Android on Qualcomm platform. From my translation of [[Translation] Qualcomm Android device boot chain of trust](https://blog.inoki.cc/2021/10/17/android-qcom-chain-of-trust/), it can be summarized as follows.

- Aboot: Before MSM8994 (Snapdragon 810), the device first loads Qualcomm's bootrom (PBL) and SBL to initialise some hardware, and immediately hands over to Aboot, an application built on top of the LittleKernel system, which contains fastboot and enables When using the `adb reboot bootloader`, this is where it boots and stays in in fastboot.

- XBL/ABL: After the MSM8996 (Snapdragon 820), PBL loads the new XBL, followed by a chain load of ABL, which is a bootloader built on EDK II to replace Aboot (in fact, on the MSM8996 platform, Aboot is still used because XBL and ABL are not mature enough, with XBL It can choose to boot into Android using fastboot, the system kernel and ramdisk in the system directory, or the recovery ramdisk, depending on the keystroke combination.

For both boot modes, the source code for Aboot and ABL can be found on Google or at the Code Aurora Forum: CAF Aboot: [ramdisk

- CAF Aboot: [https://source.codeaurora.org/quic/la/kernel/lk/](https://source.codeaurora.org/quic/la/kernel/lk/)
- CAF ABL: [https://source.codeaurora.org/quic/la/abl/tianocore/edk2/](https://source.codeaurora.org/quic/la/abl/tianocore/edk2/)

As you can see, the source tree of Aboot is named lk, short for LittleKernel, which is a small symmetric multiprocessing (SMP) operating system kernel, and Aboot is a device-related application built on top of this operating system. This article will briefly analyze the source code of Aboot as an application (excluding encryption and image verification), and cover some of the device-related code.

# Code Organization

The CAF Aboot commit d37db810993015ea77cc5231a95250b250f4eb07 (the master branch commit at the time of writing) is used here for reference.

As an application, the source code of Aboot is in `app/aboot/`, and the core files are `aboot.c` and `fastboot.c`, in addition to some auxiliary code that shows hardware-related information. Depending on the SoC, hardware-related code and definitions are located in `platform/` and `target/`, and most of the device drivers are located in `dev/`. And `arch` is the architecture related code and `kernel` is the actual lk kernel code.

# Overview

During the boot process, lk is loaded, and after the architecture and platform-related initialization, the Aboot application is started. In the `aboot.c` code, the following code registers Aboot as an application and uses `aboot_init` as the entry point.

```c
APP_START(aboot)
	.init = aboot_init,
APP_END
```

In this function, the device's storage device type is detected as EMMC or flash, and two global variables `page_size` and `page_mask` are set according to the corresponding page size, which are later used to determine the size of the kernel, ramdisk, and other components loaded from the storage device.

The device base information and oem unlock information is then read and stored in the following structs.

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

Then initialize the screen (if any), read the device serial number according to the device definition.

Immediately afterwards, the boot mode is determined.

- If it is force reset (usually a long press of the power button to reboot), it goes directly to normal system boot, otherwise it goes to detect the key.
- If the volume up and down keys are pressed simultaneously (i.e. `keys_get_state(KEY_VOLUMEUP) && keys_get_state(KEY_VOLUMEDOWN)`), the device is rebooted and enters Qualcomm's dload mode.
- If the Volume Up key or Home key is pressed, mark it as entering recovery mode.
- If the Volume Down key or Back key is pressed, the device is marked as entering fastboot mode.
- If there is a pre-set reboot mode (e.g., set by `adb reboot`), boot into the appropriate mode.
- Finally, check if any fastboot boot mode flag is set, if not, set the partition where the image used for booting is located according to the recovery flag and boot to Linux from EMMC or flash memory (call function `boot_linux_from_xxxx()`), otherwise leave it in Aboot, register the commands available for fastboot and initialize fastboot.

# Boot Linux normally (including Recovery)

In both normal boot and boot-to-Recovery modes, Aboot loads the kernel and ramdisk from the partition used for booting (typically the boot partition for normal boot and the recovery partition for Recovery mode).

A normal boot image consists of a header that stores meta information, and the rest of the image is used to store the kernel, ramdisk, and other components. When the image is flushed, the start of the partition should be read into the following structure.

```c
struct boot_img_hdr
{
    unsigned char magic[BOOT_MAGIC_SIZE];

    unsigned kernel_size; /* size in bytes */
    unsigned kernel_addr; /* physical load addr */

    unsigned ramdisk_size; /* size in bytes */
    unsigned ramdisk_addr; /* physical load addr */

    unsigned second_size; /* size in bytes */
    unsigned second_addr; /* physical load addr */

    unsigned tags_addr; /* physical addr for kernel tags */
    unsigned page_size; /* flash page size we assume */
    unsigned dt_size; /* device_tree in bytes */
    unsigned unused; /* future expansion: should be 0 */

    unsigned char name[BOOT_NAME_SIZE]; /* asciiz product name */
    
    unsigned char cmdline[BOOT_ARGS_SIZE];

    unsigned id[8]; /* timestamp / checksum / sha1 / etc */
};
```

where `kernel_size` and `ramdisk_size` are the size of the kernel and ramdisk to be loaded, and the corresponding `xxx_addr` is the physical address of the memory to be loaded into (depending on the configuration and device).

Before going through the loading of the kernel, ramdisk (and possibly device tree and secondary bootloader, which are ignored here for now), if the device is not unlocked, the kernel needs to be verified and loaded if it passes the verification, for devices that are already unlocked, Aboot will load them directly.

Then call the `boot_linux` function with the read and prepared arguments to prepare the kernel for booting.

```c
boot_linux((void *)hdr->kernel_addr, (void *)hdr->tags_addr,
		   (const char *)hdr->cmdline, board_machtype(),
		   (void *)hdr->ramdisk_addr, hdr->ramdisk_size);
```

In this function, Aboot first updates the kernel's command line parameters based on the device, such as the type of device to add to the baseband, the type of storage device, and so on. Then the device tree (if it exists) is updated according to the parameters.

The hardware needs to be managed by the kernel, so lk will first turn off some hardware: `target_display

- Shutting down the display with `target_display_shutdown()`.
- call `target_uninit()` to cancel the hardware initialization performed in lk.
- call `enter_critical_section()` to disable device interrupts.
- initialize Watchdog to monitor for early kernel crashes `msm_wdog_init()`.
- call `platform_uninit()` to clean up platform initialization performed by previous lk.
- Explicitly invalidate the cache `arch_disable_cache(UCACHE)` and turn off the memory management unit (MMU) `arch_disable_mmu()`.

Finally, check if the Magic Number of the kernel is 64-bit, so that you can enter the kernel via `scm_elexec_call`, otherwise you can enter the 32-bit kernel directly in 32-bit mode.

# Entering fastboot mode

If you boot into fastboot, you will first call `aboot_fastboot_register_commands()` to register the available fastboot commands, and then use `fastboot_init` to initialize and enter fastboot mode. Note that we will still be in Aboot here, and fastboot is part of Aboot, so to speak.

# Entering fastboot mode

If you boot into fastboot, you will first call `aboot_fastboot_register_commands()` to register the available fastboot commands, and then use `fastboot_init` to initialize and enter fastboot mode. Note that we will still be in Aboot here, and fastboot is part of Aboot, so to speak.

## Registering the fastboot command

When registering commands, `fastboot_register` is a very important function that accepts commands and callback functions as arguments. In this version, the available commands are.

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
{"oem enable-charger-screen", cmd_oem_enable_charger_screen}, {"oem enable-charger-screen", cmd_oem_enable_charger_screen},
{"oem disable-charger-screen", cmd_oem_disable_charger_screen}, {"oem disable-charger-screen", cmd_oem_disable_charger_screen},
{"oem select-display-panel", cmd_oem_select_display_panel},
```

In addition, `fastboot_publish` can add some variables that can be considered as fastboot's environment variables.

## Initialize and enter fastboot

The `fastboot_init` function that is called is defined in `fastboot.c`.

```c
int fastboot_init(void *base, unsigned size);
```

It first calls `target_fastboot_init()` to initialize the hardware of a particular device, more importantly the USB interface. This is a device-specific function, for example for the MSM8974 device, it is implemented as follows.

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

Located in `target/msm8974/init.c`.

After this, the USB hardware should be set up, and Aboot then configures and initializes a USB UDC device on the USB interface to receive and send fastboot-related USB packets.

Finally, create a lk thread to handle fastboot-related events and initialize the USB interface to receive fastboot commands.

# Conclusion

This article briefly describes and analyzes the implementation of the Aboot boot loader for Android based on the lk kernel prior to 2016, but does not go too far into how lk is built and set up for a particular platform or architecture. We hope you find this helpful.

## Additions

- Note that both ARM32 and AArch64 devices run lk and its application Aboot in 32-bit mode, and it is only when the kernel is loaded that the kernel is determined to be 32-bit or 64-bit, and then the kernel is booted in the appropriate boot mode.

- At load time, Aboot uses the VA() macro to map the physical address to the virtual address read by lk and loads the kernel to that address, as the MMU may exist.
