---
title: Android bootloader analysis -- ABL(3)
date: 2024-04-20 13:48:00
tags:
- Android
- ABL
- Linux
- Bootloader
categories:
- [Linux, Android, Bootloader]
---

In my previous post ["Android Bootloader Analysis -- ABL(1)"](https://blog.inoki.cc/2021/10/18/android-bootloader-analysis-abl-1-en/), I analyzed the overall boot process of ABL on contemporary Qualcomm platforms, and in ["Android Bootloader Analysis -- ABL(2)"](https://blog.inoki.cc/2024/04/20/android-bootloader-analysis-abl-2-en/), I explains in detail how to boot into fastboot mode. In this post, we will analyze the code in ABL to boot into Linux kernel.

# Conditions for booting the Linux kernel

If you are not booting into fastboot mode and do not press a key combination during boot, ABL loads and verifies the kernel with `LoadImageAndAuth (&Info)` (if it is not unlocked) and calls `BootLinux (&Info)` to boot the loaded kernel, and fall-through to fastboot mode if it fails. to fastboot mode, where Info is a `BootInfo` type defined as follows:

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

The `ImageData` structure is the loaded boot image, defined as follows:

```
typedef struct {
  CHAR8 *Name;
  VOID *ImageBuffer;
  UINTN ImageSize;
} ImageData;
```

During the loading and verification of the Linux kernel, the image is loaded here first. Later, during the booting, one of the images here will be used.

# Linux kernel verification and loading

The implementation to verify and load, the function `LoadImageAndAuth (BootInfo *Info)` is located in `QcomModulePkg/Library/avb/VerifiedBoot.c`. The full name of `avb` here is "Android Verified Boot".

This function first tries to load the image from the `recovery` partition, checking to see if it was loaded successfully, and if there is a legitimate boot image version (version 3 or higher, for system-as-root) and kernel size:
 
 

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

If the `recovery` partition does not have a legal kernel, set the `RecoveryHasNoKernel` global identifier with `SetRecoveryHasNoKernel ()` for later use.

There are two cases then, which are used to handle the presence of an A/B partition and the presence of only a single partition.

In the case of a single partition, it is also possible to have a system-as-root, where recovery mode shares the kernel with normal booting, but mounts a different partition as the sysroot, so the following code sets the name of the partition used for booting to either `recovery` or `boot`:

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

The case of A/B partitions is a bit more complicated. First ABL looks for a bootable slot (i.e. a set of partitions) and stores it in a `CurrentSlot` structure, defined as follows:

```c
typedef struct {
  CHAR16 Suffix[MAX_SLOT_SUFFIX_SZ];
} Slot;
```

This structure defines the suffix of the partition. In fact, multiple slots are implemented by adding a suffix to the partition name, e.g. `boot_a` and `boot_b` are the boot partitions of two slots. This suffix is obtained by `FindBootableSlot`. The next step is similar to that for a single partition.

Once the bootable slots have been obtained, the verification of the bootable slots' images begins. The validation of the image is platform dependent, the version is obtained by calling `GetAVBVersion ()`, currently there are `NO_AVB`, `AVB_1`, `AVB_2` and `AVB_LE`, which use the corresponding function calls to load the image and validate it respectively.

Taking no AVB authentication as an example, it directly loads the image using `LoadImageNoAuth`, where `LoadImageHeader (Info->Pname, &ImageHdrBuffer, &ImageHdrSize)` is called to load the image into the buffer. During this time, the corresponding device tree and command line parameters are loaded and set.

Finally, the verification status is displayed on the screen `DisplayVerifiedBootScreen (Info)` and the image verification status is returned.

# Booting the Linux kernel

First, it loads the boot image:

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

It updates the command line parameters for booting the kernel, gets the base address for loading, and loads the memory disk.

After that, shut down the UEFI boot service to prepare the Linux kernel for booting, and uninitialize some devices in `PreparePlatformHardware`, such as disabling interrupts, disabling caching, disabling MMUs, disabling branch prediction, and so on:

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

Finally, it loads and calls the Linux kernel:

```c
LinuxKernel = (LINUX_KERNEL) (UINT64)BootParamlistPtr.KernelLoadAddr;
LinuxKernel ((UINT64)BootParamlistPtr.DeviceTreeLoadAddr, 0, 0, 0);
```

This is for the 32 bit kernel:

```c
LinuxKernel32 = (LINUX_KERNEL32) (UINT64)BootParamlistPtr.KernelLoadAddr;
LinuxKernel32 (0, 0, (UINTN)BootParamlistPtr.DeviceTreeLoadAddr);
```
 
However, it needs to switch to 32 bit boot mode before the 32 bit kernel boots:

```c
Status = SwitchTo32bitModeBooting (
      (UINT64)BootParamlistPtr.KernelLoadAddr,
      (UINT64)BootParamlistPtr.DeviceTreeLoadAddr);
```

This is accomplished by writing 0 to the X4 register in the EL1 environment:

```
HlosBootArgs.el1_x2 = DeviceTreeLoadAddr;
/* Write 0 into el1_x4 to switch to 32bit mode */
HlosBootArgs.el1_x4 = 0;
HlosBootArgs.el1_elr = KernelLoadAddr;
Status = pQcomScmModeSwitchProtocol->SwitchTo32bitMode (HlosBootArgs);
```

If startup fails, go to `CpuDeadLoop()`.

# Summary

This post analyzes and summarizes the code and flow of ABL when booting Linux normally.
