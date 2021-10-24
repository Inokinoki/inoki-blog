---
title: Android 启动加载器分析 —— ABL(3)
date: 2021-10-24 22:48:00
tags:
- Android
- ABL
- Linux
- Bootloader
- 中文
categories:
- [Linux, Android, Bootloader]
---

我的前一篇文章[《Android 启动加载器分析 —— ABL(1)》](https://blog.inoki.cc/2021/10/17/android-bootloader-analysis-aboot/)中分析了当代高通平台的 ABL 的整体启动流程，[《Android 启动加载器分析 —— ABL(2)》](https://blog.inoki.cc/2021/10/22/android-bootloader-analysis-abl-2/)对如何启动至 fastboot 模式进行详细的解释。本文将对 ABL 中启动至 Linux 内核的代码进行分析。

# 启动 Linux 内核的条件

若不是在启动至 fastboot 模式下、并且没有在启动时按下组合按键时，ABL 通过 `LoadImageAndAuth (&Info)` 加载并验证内核（如果未解锁），并调用 `BootLinux (&Info)` 来启动加载的内核，如果启动失败，则 fall-through 到 fastboot 模式。其中 Info 为一个 `BootInfo` 类型，定义如下：

```c
typedef struct BootInfo {
  BOOLEAN MultiSlotBoot;
  BOOLEAN BootIntoRecovery;
  BOOLEAN BootReasonAlarm;
  CHAR16 Pname[MAX_GPT_NAME_SIZE];
  CHAR16 BootableSlot[MAX_GPT_NAME_SIZE];
  ImageData Images[MAX_NUMBER_OF_LOADED_IMAGES];
  UINTN NumLoadedImages;
  QCOM_VERIFIEDBOOT_PROTOCOL *VbIntf;
  boot_state_t BootState;
  CHAR8 *VBCmdLine;
  UINT32 VBCmdLineLen;
  UINT32 VBCmdLineFilledLen;
  VOID *VBData;
  UINT32 HeaderVersion;
} BootInfo;
```

其中 `ImageData` 结构为加载进来的启动镜像，定义如下：

```
typedef struct {
  CHAR8 *Name;
  VOID *ImageBuffer;
  UINTN ImageSize;
} ImageData;
```

在加载和验证 Linux 内核时，镜像会先被加载到这里，之后在启动时，也是使用这里的镜像之一。

# Linux 内核的验证与加载

验证与加载的函数 `LoadImageAndAuth (BootInfo *Info)` 的实现位于 `QcomModulePkg/Library/avb/VerifiedBoot.c` 中。这里 `avb` 的全称即为 Android Verified Boot。

这个函数首先尝试从 `recovery` 分区加载镜像，检测是否加载成功、以及是否有一个合法的启动镜像版本（要求第三版以上，为 system-as-root 所用的）和 kernel 大小：

```c
/* check early if recovery exists and has a kernel size */
Status = LoadPartitionImageHeader (Info, (CHAR16 *)L"recovery", &RecoveryHdr,
                                    &RecoveryHdrSz);
if (Status != EFI_SUCCESS) {
DEBUG ((EFI_D_VERBOSE,
      "Recovery partition doesn't exist; continue normal boot\n"));
} else if (((boot_img_hdr *)(RecoveryHdr))->header_version >=
            BOOT_HEADER_VERSION_THREE &&
            !((boot_img_hdr *)(RecoveryHdr))->kernel_size) {
DEBUG ((EFI_D_VERBOSE, "Recovery partition has no kernel\n"));
SetRecoveryHasNoKernel ();
}
```

若 `recovery` 分区没有一个合法的 kernel，则通过 `SetRecoveryHasNoKernel ()` 设置 `RecoveryHasNoKernel` 全局标识以供之后使用。

接下来有两种情况，分别用来处理 A/B 分区存在与只存在单一分区的情况。

在单一分区情况下，也可能存在 system-as-root 的情况，即 recovery 模式和正常启动共用内核、但挂载不同的分区作为 sysroot。因此，以下代码设置启动用分区名称为 `recovery` 或 `boot`：

```c
if (Info->BootIntoRecovery &&
      !IsRecoveryHasNoKernel ()) {
      DEBUG ((EFI_D_INFO, "Booting Into Recovery Mode\n"));
      StrnCpyS (Info->Pname, ARRAY_SIZE (Info->Pname), L"recovery",
            StrLen (L"recovery"));
} else {
      if (Info->BootIntoRecovery &&
            IsRecoveryHasNoKernel ()) {
            DEBUG ((EFI_D_INFO, "Booting into Recovery Mode via Boot\n"));
      } else {
            DEBUG ((EFI_D_INFO, "Booting Into Mission Mode\n"));
      }
      StrnCpyS (Info->Pname, ARRAY_SIZE (Info->Pname), L"boot",
                  StrLen (L"boot"));
}
```

而 A/B 分区情况稍微复杂一些。首先 ABL 会寻找可启动的 slot（即为一套分区），将其存入 `CurrentSlot` 结构体中，定义如下：

```c
typedef struct {
  CHAR16 Suffix[MAX_SLOT_SUFFIX_SZ];
} Slot;
```

这个结构体定义了分区的后缀。实际上，多个 slot 的实现正是通过分区名称加上一个后缀实现的，比如 `boot_a` 和 `boot_b` 为两个 slot 的启动分区。这个后缀由 `FindBootableSlot` 来获取。接下来的流程就和单一分区的类似。

获取到要使用的启动分区之后，就要开始对该分区的镜像的验证。镜像的验证是平台相关的，通过调用 `GetAVBVersion ()` 取得版本，目前存在 `NO_AVB`、`AVB_1`、`AVB_2` 和 `AVB_LE`，分别用对应的函数调用来加载镜像和验证。

以无 AVB 验证为例，它直接使用 `LoadImageNoAuth` 加载镜像，在这个函数里 `LoadImageHeader (Info->Pname, &ImageHdrBuffer, &ImageHdrSize)` 被调用来把镜像加载到 buffer 中。在此期间，相应的 device tree 和命令行参数也被加载和设置。

最后就在屏幕上显示验证状态 `DisplayVerifiedBootScreen (Info)` 并返回镜像验证状态。

# 启动 Linux 内核

首先加载启动镜像：

```c
Status = GetImage (Info,
      &BootParamlistPtr.ImageBuffer,
      (UINTN *)&BootParamlistPtr.ImageSize,
      ((!Info->MultiSlotBoot ||
      IsDynamicPartitionSupport ()) &&
      (Recovery &&
      !IsBuildUseRecoveryAsBoot () &&
      !IsRecoveryHasNoKernel ()))?
      "recovery" : "boot");
```

更新启动内核用的命令行参数，获取加载的基址、加载内存盘。

之后关闭 UEFI 启动服务为启动 Linux 内核做准备，并在 `PreparePlatformHardware` 中取消一些设备的之前完成的初始化和配置，比如禁用中断、禁用缓存、禁用 MMU、禁用分支预测等：

```c
ArmDisableBranchPrediction ();

ArmDisableInterrupts ();
ArmDisableAsynchronousAbort ();

WriteBackInvalidateDataCacheRange (KernelLoadAddr, KernelSizeActual);
WriteBackInvalidateDataCacheRange (RamdiskLoadAddr, RamdiskSizeActual);
WriteBackInvalidateDataCacheRange (DeviceTreeLoadAddr, DeviceTreeSizeActual);
WriteBackInvalidateDataCacheRange ((void *)StackCurrent,
            (UINTN)StackBase - (UINTN)StackCurrent);
WriteBackInvalidateDataCacheRange (CallerStackCurrent,
            CallerStackBase - (UINTN)CallerStackCurrent);

ArmCleanDataCache ();
ArmInvalidateInstructionCache ();

ArmDisableDataCache ();
ArmDisableInstructionCache ();
ArmDisableMmu ();
ArmInvalidateTlb ();
```

最后，加载并调用 Linux 内核：

```c
LinuxKernel = (LINUX_KERNEL) (UINT64)BootParamlistPtr.KernelLoadAddr;
LinuxKernel ((UINT64)BootParamlistPtr.DeviceTreeLoadAddr, 0, 0, 0);
```

对 32 位内核，则为：

```c
LinuxKernel32 = (LINUX_KERNEL32) (UINT64)BootParamlistPtr.KernelLoadAddr;
LinuxKernel32 (0, 0, (UINTN)BootParamlistPtr.DeviceTreeLoadAddr);
```

但在 32 位内核启动前，需要切换到 32 bit 的启动模式：

```c
Status = SwitchTo32bitModeBooting (
      (UINT64)BootParamlistPtr.KernelLoadAddr,
      (UINT64)BootParamlistPtr.DeviceTreeLoadAddr);
```

具体实现为写入 0 到 EL1 环境下的 X4 寄存器：

```
HlosBootArgs.el1_x2 = DeviceTreeLoadAddr;
/* Write 0 into el1_x4 to switch to 32bit mode */
HlosBootArgs.el1_x4 = 0;
HlosBootArgs.el1_elr = KernelLoadAddr;
Status = pQcomScmModeSwitchProtocol->SwitchTo32bitMode (HlosBootArgs);
```

如果启动失败，则进入 `CpuDeadLoop()`。

# 总结

本文分析总结了 ABL 正常启动 Linux 时的代码与流程。
