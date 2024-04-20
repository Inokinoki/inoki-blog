---
title: Android bootloader analysis -- ABL(2)
date: 2024-04-20 13:48:00
tags:
- Android
- ABL
- Linux
- Bootloader
categories:
- [Linux, Android, Bootloader]
---

In my previous post ["Android bootloader analysis -- ABL(1)"](https://blog.inoki.cc/2021/10/18/android-bootloader-analysis-abl-1-en/), I analyzed the overall boot process of ABL for contemporary Qualcomm platforms, but did not explain in detail how to boot into fastboot mode and the Linux kernel. In this paper, we will analyze the code of fastboot mode.

# Conditions for booting into fastboot mode

In ABL, the following code is executed to initialize and execute fastboot mode when boot image validation fails, the `BootLinux (&Info)` function fails to start, or a command to boot into fastboot is received (e.g., rebooting to bootloader using adb, pressing the appropriate key combination during boot):

```c
fastboot:
  DEBUG ((EFI_D_INFO, "Launching fastboot\n"));
  Status = FastbootInitialize ();
```

# Initialize fastboot mode

The code that initializes and executes fastboot mode is the `FastbootInitialize ()` function, which is defined in `QcomModulePkg/Library/FastbootLib/FastbootMain.c`. It first calls `FastbootUsbDeviceStart ()` to start the USB device so that it can receive fastboot commands from the computer. It first calls `FastbootUsbDeviceStart ()` to start the USB device so that it can receive fastboot commands from the computer, and then calls `DisplayFastbootMenu ()` to display the fastboot menu.

It then enters a dead loop receiving USB events until fastboot stops. After that, it turns off fastboot mode, stops listening for keystrokes, and stops the USB device. 

```c
/* Close the fastboot app and stop USB device */
Status = FastbootCmdsUnInit ();
if (Status != EFI_SUCCESS) {
DEBUG ((EFI_D_ERROR, "couldnt uninit fastboot\n"));
return Status;
}

ExitMenuKeysDetection ();

Status = FastbootUsbDeviceStop ();
```

After returning, it will exit the fastboot app and boot the device again.

## Booting a USB device

Before booting, you need to configure a USB controller. fastboot first uses the `InitUsbControllerGuid` GUID, and initializes a USB controller by using the `EFI_BOOT_SERVICES *gBS` instance globally, with the following code:

```c
Status = gBS->CreateEventEx (EVT_NOTIFY_SIGNAL, TPL_CALLBACK, DummyNotify,
                             NULL, &InitUsbControllerGuid, &UsbConfigEvt);
```

Then it finds the protocol to be used by fastboot via `UsbDeviceProtolGuid` and store it in the `UsbDeviceProtocol` field of `Fbd`:

```
Status = gBS->LocateProtocol (&UsbDeviceProtolGuid, NULL,
                              (VOID **)&Fbd.UsbDeviceProtocol);
```

This field is a pointer to a `EFI_USB_DEVICE_PROTOCOL *UsbDeviceProtocol`, which is defined in `QcomModulePkg/Include/Protocol/EFIUsbDevice.h`.

Then, the fastboot commands and variables are initialized and the corresponding callback functions are prepared for the received commands.

At this point the USB device is not fully registered, so the next step is to register the device and boot the USB device, including getting the maximum speed available for USB, the USB device specification (including vendor ID and device ID, etc.) and the device descriptor. This is actually in `QcomModulePkg/Library/FastbootLib/UsbDescriptor.c`.

Note that there are `SS DevDescriptors/Descriptors` and `DevDescriptors/Descriptors`, which are the Super Speed USB (3.X) and High Speed USB (2.0) descriptors. Various USB related descriptors are defined in `MdePkg/Include/IndustryStandard/Usb.h`, where the most important `USB_DEVICE_DESCRIPTOR` is defined as follows:

```c
///
/// Standard Device Descriptor
/// USB 2.0 spec, Section 9.6.1
///
typedef struct {
  UINT8           Length;
  UINT8           DescriptorType;
  UINT16          BcdUSB;
  UINT8           DeviceClass;
  UINT8           DeviceSubClass;
  UINT8           DeviceProtocol;
  UINT8           MaxPacketSize0;
  UINT16          IdVendor;
  UINT16          IdProduct;
  UINT16          BcdDevice;
  UINT8           StrManufacturer;
  UINT8           StrProduct;
  UINT8           StrSerialNumber;
  UINT8           NumConfigurations;
} USB_DEVICE_DESCRIPTOR;
```

After configuring these descriptors, the USB protocol created earlier is called to start the USB device:

```c
/* Start the usb device */
Status = Fbd.UsbDeviceProtocol->StartEx (&DescSet);
```

Finally, it creates buffers for sending and receiving USB transfer data.

## Registering fastboot commands

Before booting the USB device, the commands and associated variables available within fastboot are registered by `EFI_STATUS FastbootCmdsInit (VOID)`, a function in `QcomModulePkg/Library/FastbootLib/FastbootCmds.c`. This function creates a buffer and multithreaded environment for fastboot related commands to invoke callbacks, and then calls `FastbootCommandSetup` to create available commands and variables:

```c
/* By Default enable list is empty */
      {"", NULL},
/*CAUTION(High): Enabling these commands will allow changing the partitions
 *like system,userdata,cachec etc...
 */
#ifdef ENABLE_UPDATE_PARTITIONS_CMDS
      {"flash:", CmdFlash},
      {"erase:", CmdErase},
      {"set_active", CmdSetActive},
      {"flashing get_unlock_ability", CmdFlashingGetUnlockAbility},
      {"flashing unlock", CmdFlashingUnlock},
      {"flashing lock", CmdFlashingLock},
#endif
```

These basic commands can be used to unlock, set the activation status of A/B partitions, and swipe partitions, among other things.

```c
/*
 *CAUTION(CRITICAL): Enabling these commands will allow changes to bootimage.
 */
#ifdef ENABLE_DEVICE_CRITICAL_LOCK_UNLOCK_CMDS
      {"flashing unlock_critical", CmdFlashingUnLockCritical},
      {"flashing lock_critical", CmdFlashingLockCritical},
#endif
```

These two commands are used to control the flushing of the boot image area.

```c
/*
 *CAUTION(CRITICAL): Enabling this command will allow boot with different
 *bootimage.
 */
#ifdef ENABLE_BOOT_CMD
      {"boot", CmdBoot},
#endif
```

The `fastboot boot <image>` command registered here can boot a customized image.

```c
      {"oem enable-charger-screen", CmdOemEnableChargerScreen},
      {"oem disable-charger-screen", CmdOemDisableChargerScreen},
      {"oem off-mode-charge", CmdOemOffModeCharger},
      {"oem select-display-panel", CmdOemSelectDisplayPanel},
      {"oem device-info", CmdOemDevinfo},
```

The above commands are about OEM-related settings and information.

```c
      {"continue", CmdContinue},
      {"reboot", CmdReboot},
#ifdef DYNAMIC_PARTITION_SUPPORT
      {"reboot-recovery", CmdRebootRecovery},
      {"reboot-fastboot", CmdRebootFastboot},
#ifdef VIRTUAL_AB_OTA
      {"snapshot-update", CmdUpdateSnapshot},
#endif
#endif
      {"reboot-bootloader", CmdRebootBootloader},
```

These are reboot and startup related commands.

```c
      {"getvar:", CmdGetVar},
      {"download:", CmdDownload},
```

The last `getvar` command gets the variables associated with the device in fastboot mode, which are published using `FastbootPublishVar (key, value)`.

# Event loop in fastboot mode

In general, there are three main event loops in fastboot:

- One loop receives key events to update the fastboot menu (drawn and created in `VOID DisplayFastbootMenu (VOID)`, defined in `QcomModulePkg/Library/BootLib/FastbootMenu.c`);
- Another loop receives commands from the computer's fastboot via USB (created when registering fastboot);
- The main loop calls `HandleUsbEvents ()` to listen for USB device notifications, including events such as device connections.

# Conclusion

This article summarizes the code and flow of ABL in fastboot mode.
