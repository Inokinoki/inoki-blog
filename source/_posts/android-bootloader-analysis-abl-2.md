---
title: Android 启动加载器分析 —— ABL(2)
date: 2021-10-22 13:48:00
tags:
- Android
- ABL
- Linux
- Bootloader
- 中文
categories:
- [Linux, Android, Bootloader]
---

我的前一篇文章[《Android 启动加载器分析 —— ABL(1)》](https://blog.inoki.cc/2021/10/18/android-bootloader-analysis-abl-1/)中分析了当代高通平台的 ABL 的整体启动流程，但并未对如何启动至 fastboot 模式和 Linux 内核进行详细的解释。本文将对 fastboot 模式的代码进行分析。

# 启动至 fastboot 模式的条件

在 ABL 中，当启动镜像验证失败、`BootLinux (&Info)` 函数启动失败或者接收到启动至 fastboot 的命令（比如使用 adb 重启至 bootloader、在启动时按下了相应的组合按键）时，以下代码会被执行来初始化并执行 fastboot 模式：

```c
fastboot:
  DEBUG ((EFI_D_INFO, "Launching fastboot\n"));
  Status = FastbootInitialize ();
```

# 初始化 fastboot 模式

初始化并执行 fastboot 模式的代码是 `FastbootInitialize ()` 这个函数，它被定义在 `QcomModulePkg/Library/FastbootLib/FastbootMain.c` 中。它首先调用 `FastbootUsbDeviceStart ()` 启动 USB 设备，这样就可以接收计算机传来的 fastboot 命令，然后调用 `DisplayFastbootMenu ()` 显示 fastboot 的菜单。

然后进入一个接收 USB 的死循环处理 USB 事件，直到 fastboot 停止。之后则关闭 fastboot 模式、停止监听按键并停止 USB 设备。

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

返回后就会退出 fastboot 这个 app，再次启动设备。

## 启动 USB 设备

启动之前需要配置 USB 控制器，fastboot 首先使用 `InitUsbControllerGuid` 这个 GUID、通过在全局的 `EFI_BOOT_SERVICES  *gBS` 实例来初始化一个 USB 控制器，代码如下：

```c
Status = gBS->CreateEventEx (EVT_NOTIFY_SIGNAL, TPL_CALLBACK, DummyNotify,
                             NULL, &InitUsbControllerGuid, &UsbConfigEvt);
```

然后通过 `UsbDeviceProtolGuid` 寻找 fastboot 要使用的协议，存入 `Fbd` 的 `UsbDeviceProtocol` 字段中：

```
Status = gBS->LocateProtocol (&UsbDeviceProtolGuid, NULL,
                              (VOID **)&Fbd.UsbDeviceProtocol);
```

这个字段是一个 `EFI_USB_DEVICE_PROTOCOL *UsbDeviceProtocol` 的指针，其定义在 `QcomModulePkg/Include/Protocol/EFIUsbDevice.h` 中。

在这之后，fastboot 的命令和变量会被初始化，为接收到的命令准备相应的回调函数。

此时 USB 设备还未被完全注册，因此接下来需要注册设备并启动 USB 设备，包括获取 USB 可用的最大速度、USB 设备规范（包括 vendor ID 和 device ID 等）和设备描述符等。其实现在 `QcomModulePkg/Library/FastbootLib/UsbDescriptor.c` 中。

注意这时有 `SS DevDescriptors/Descriptors` 和 `DevDescriptors/Descriptors` 两种，分别是 Super Speed USB（3.X）和 High Speed USB（2.0）两套描述符。各种 USB 相关的描述符都定义在 `MdePkg/Include/IndustryStandard/Usb.h` 中，这里最重要的 `USB_DEVICE_DESCRIPTOR` 定义如下：

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

配置好这些 descriptor 之后，调用前面创建的 USB protocol 来启动 USB 设备：

```c
/* Start the usb device */
Status = Fbd.UsbDeviceProtocol->StartEx (&DescSet);
```

最后，为发送和接收 USB transfer 数据创建缓冲。

## 注册 fastboot 命令

在启动 USB 设备之前，fastboot 内可用的命令和相关的变量由 `EFI_STATUS FastbootCmdsInit (VOID)` 来注册，这个函数在 `QcomModulePkg/Library/FastbootLib/FastbootCmds.c` 中。这个函数为 fastboot 相关命令创建缓冲区和多线程环境来调用回调，然后调用 `FastbootCommandSetup` 来创建可用的命令与变量：

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

这些基础的命令可以用来解锁、设置 A/B 分区的激活状态和刷写分区等。

```c
/*
 *CAUTION(CRITICAL): Enabling these commands will allow changes to bootimage.
 */
#ifdef ENABLE_DEVICE_CRITICAL_LOCK_UNLOCK_CMDS
      {"flashing unlock_critical", CmdFlashingUnLockCritical},
      {"flashing lock_critical", CmdFlashingLockCritical},
#endif
```

这两条命令是用来控制启动镜像区的刷写。

```c
/*
 *CAUTION(CRITICAL): Enabling this command will allow boot with different
 *bootimage.
 */
#ifdef ENABLE_BOOT_CMD
      {"boot", CmdBoot},
#endif
```

这里注册的 `fastboot boot <image>` 命令可以启动自定义镜像。

```c
      {"oem enable-charger-screen", CmdOemEnableChargerScreen},
      {"oem disable-charger-screen", CmdOemDisableChargerScreen},
      {"oem off-mode-charge", CmdOemOffModeCharger},
      {"oem select-display-panel", CmdOemSelectDisplayPanel},
      {"oem device-info", CmdOemDevinfo},
```

以上是 OEM 有关的设置和信息。

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

这是重启和启动相关的命令。

```c
      {"getvar:", CmdGetVar},
      {"download:", CmdDownload},
```

最后的 `getvar` 命令可以获取设备在 fastboot 模式中相关的变量，而变量的发布则使用 `FastbootPublishVar (key, value)`。

# 在 fastboot 模式中的事件循环

一般情况下，在 fastboot 中会有三个主要的事件循环：

- 接收按键事件更新 fastboot 菜单（在 `VOID DisplayFastbootMenu (VOID)` 中绘制并创建，在 `QcomModulePkg/Library/BootLib/FastbootMenu.c` 中定义 ）；
- 通过 USB 接收计算机的 fastboot 发来的命令（在注册 fastboot 时创建）；
- 主循环调用 `HandleUsbEvents ()` 监听 USB 设备的通知，包括设备连接等事件。

# 结论

本文分析总结了 ABL 在 fastboot 模式下的代码与流程。

