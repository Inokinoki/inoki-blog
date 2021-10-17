---
title: 【译】高通 Android 设备的启动信任链
date: 2021-10-17
tags:
- Android
- Aboot
- Linux
categories:
- [Linux, Android, Aboot]
---

原文链接：[https://lineageos.org/engineering/Qualcomm-Firmware/](https://lineageos.org/engineering/Qualcomm-Firmware/)

高通公司的信任链是一个复杂的，但又简单易懂的程序集。你们中的许多人可能听说过“启动引导程序”这个术语，但不知道它实际上是什么，或做什么。在今天的文章中，我们将介绍与高通公司芯片组有关的上述内容。

# 术语

- 引导器：引导链中的一个环节的总称，它有一个特定的工作，在每次冷启动时运行。
- 冷启动：从断电状态重新启动。
- QFUSE：集成在 SoC 中的微观硬件保险丝 - 一旦物理上被熔断，就无法重置或更换。
- SoC：片上系统（你的手机的“主板”的一种）。
- EFUSE: 基于软件的保险丝，其数据存储在 QFPROM 中。
- QFPROM：高通公司的熔断器区域。
- TrustZone：高通公司 ARM 芯片组的“安全域”实现。
- QSEECOM：一个 Linux 内核驱动，让我们与 TrustZone 进行通信，并向 TrustZone 发出一个 SCM 调用，以完成保险丝熔断等操作。它只允许经过签名的小程序和经过批准的调用。
- SCM：安全通道管理器（注：与 Linux 的 SMC 调用无关）。
- DTB：设备树 Blob 二进制。其目的是为 Linux 提供“一种描述不可发现的硬件的方法”，[阅读更多内容](https://elinux.org/Device_Tree_Reference)。
- 安卓验证启动（AVB）：在 aboot/ABL 层面实施的一套严格的检查，以验证操作系统各部分的完整性，请[点击这里](https://source.android.com/security/verifiedboot/)阅读更多内容。
- DM-Verity:安卓验证启动的一个组件，它检查分区，看它们之前是否被安装过读/写，请[点击这里](https://source.android.com/security/verifiedboot/dm-verity)阅读更多信息。
- system_as_root: 一个新的安卓挂载设置逻辑，将系统分区挂载为"/"，而不是"/system"。这意味着系统文件现在位于"/system/system"。这是高通公司检查"/"是否曾在验证启动下被重新挂载读写的一种方式。它还引入了新的标准，即安卓 ramdisk 要存储在系统分区上，而不是存储在启动镜像中。

# 什么是高通公司的信任链/启动序列？

高通公司设备的信任链、引导程序序列和安全世界。

## 详细信息

根据定义，引导程序是一个加载操作系统的程序，或在设备开启时链式加载另一个引导程序。

高通公司的设备都使用基于熔断器的逻辑来决定永久功能配置/加密密钥集。如上所述，其物理版本被称为 QFUSE，并以行为单位存储在 SoC 上称为 QFPROM 的区域中。

如果标记为高通安全启动的 QFUSE 保险丝熔断（在非中国/OnePlus 的设备上就是这样），PBL（高通的主要启动程序）被验证并从 BootROM 加载到内存中，这是 SoC 上一个不可写的存储空间。

然后，PBL 被执行，并启动一系列硬件，然后验证链中下一个引导装载程序的签名，加载并执行它。

链中的下一个引导程序是 SBL*/XBL（高通公司的二级/可扩展引导程序）。这些早期的引导程序启动了核心硬件，如 CPU 内核、MMU 等。它们还负责启动与安卓系统同时进行的核心进程，如被称为 TrustZone 的高通 ARM 芯片组的安全世界。SBL*/XBL 的最后一个目的是验证签名、加载和执行 Aboot/ABL。

Aboot 就是你们大多数人所说的 “bootloader 模式”，因为它是诸如 fastboot 或 OEM 固件刷写工具等服务的所在地。Aboot 将大部分剩余的核心硬件唤醒，然后依次验证启动镜像的签名，通过 dm-verity 将验证状态报告给 Android 验证启动，然后等待前两个步骤的成功，将内核/ramdisk/DTB 加载到内存。在许多设备上，Aboot/ABL 可以被配置为跳过密码学签名检查，允许启动任何内核/启动镜像。在 Aboot 将所有东西加载到内存中后，内核（在我们的例子中是 Linux）然后从启动镜像中解压，或者在 system_as_root 配置中，系统分区被验证并挂载到"/"，然后从那里提取出 ramdisk。在这之后不久，init 被执行，它带来了我们所知的 Android。

在 aboot/ABL 中禁用加密检查的配置选项通常被称为“Bootloader Lock Status”。当一个设备被锁定时，这意味着 aboot 目前正在通过 aboot/ABL 对该设备的启动镜像执行数字签名完整性检查，在较新的设备上，执行“绿色”的 Android 验证启动状态。这些被“锁定”的设备不允许用户刷写分区，也不能启动自定义的无签名内核。如果被锁定的设备被认为是安全的，安卓验证启动通常会报告“绿色”，并允许设备继续启动，如果它被认为是不安全的，它将报告“红色”状态，并阻止设备启动。在“解锁”的设备上，aboot/ABL 允许设备刷写，一些 OEM 厂商允许从内存中启动未签名的启动镜像（fastboot 启动），在这种情况下，验证启动会报告“橙色”或“红色”，这取决于镜像是否有签名，但无论如何都允许设备继续启动。

# 信任链的成熟

在过去十年中，高通公司的信任链在安全性方面有了巨大的增长。

以下是描述信任链成熟过程的图示：

## 至 2013 时代

在 MSM8960（Snapdragon S4 plus）及之前：

{% asset_img content_qualcomm_firmware_0.png 第一代 %}

## 2013-2016 时代

在 MSM8974（Snapdragon 800）到 MSM8994（Snapdragon 810）之间：

{% asset_img content_qualcomm_firmware_1.png 第二代 %}

## 现代化 (2016-2018) 时代

在 MSM8996（Snapdragon 820）之后：

{% asset_img content_qualcomm_firmware_2.png 第三代 %}

正如你所看到的，引导链已经有了很大的发展。2015 年，可能的攻击区域被缩小了，二级引导程序（SBL）链被合并成一个统一的 SBL。随着进一步发展，我们看到 SBL 完全被高通公司的新的专有解决方案--可扩展引导程序（XBL）所取代，它缓解了 SBL 带来的许多安全问题。

Aboot 也已经从 LittleKernel（一个开源的引导程序）发展到了完全独立的解决方案，现在被称为专有的 Android 引导程序（ABL）。这个新的引导程序允许使用 UEFI，以及其他许多针对开发者/OEM 的安全和生活质量的改进。

而 system_as_root 配置也大大改善了安全性，以及总体架构。它将 Android ramdisk 从存储在启动镜像中转移到了系统分区中，正如其名称所暗示的，系统分区被挂载为"/"。这样做的部分原因是为了让它能够被 dm-verity/Android 验证启动所验证。

注意：新的无缝更新系统被称为“A/B”，它与 system_as_root 是独立概念的，尽管它们通常是并列的。OEM 可以选择实现一个而不是另一个。

# OEM 附加功能

许多 OEM 在他们的 bootloader 设置中实施了额外的加密检查，以试图进一步提高安全性，或是为了一种功能（如允许终端用户解锁 bootloader）。

几个普遍的例子：

- 三星使用 eMMC CID/a 对应的哈希 CID 的 aboot 镜像来决定开发者（解锁）状态。
- 三星的“KNOX QFUSE”在任何入侵时都会被吹响，如果被触发，可以被配置为擦除设备。
- 摩托罗拉使用单一的 QFUSE，必须熔断才能解锁设备，从而使保修期永久失效。
- 索尼使用了一个加密 blob 和他们的“TA”分区上的一个位来允许解锁。

原始设备制造商也经常实施他们自己的专有模式，这有多种用途。一些例子包括：

- 三星的专有下载模式，用于固件刷写。
- LG专有的 LAF（下载）模式用于固件刷写。
- 谷歌的 OSS Fastboot 模式用于固件刷写。

与一般的解决方案相比，OEM 的特定功能/模式往往有很大的优势，比如摩托罗拉是第一批扩展 fastboot 协议以允许刷写稀疏分块的系统镜像的 OEM 之一。然而，这些解决方案也很有可能存在不可预见的安全漏洞，比如 LG 经常出现的 LAF 模式漏洞，或者利用三星的 CID 方法解锁其他不可解锁设备的 SamDunk 漏洞。

同样重要的是要注意，虽然 OEM 厂商可以定制aboot/ABL，以及有价格的 SBL*/XBL，但 PBL 是由高通公司自己在 SoC 上构建和发布。PBL 很少出现公开的漏洞，因为大多数漏洞通过高通公司的 Bug Bounty Program 获得了大量的赏金，尽管 PBL 以前也出现过一些公开的漏洞，例如 Aleph Security 的 EDL（高通下载模式）漏洞，你可以在[这里](https://alephsecurity.com/2018/01/22/qualcomm-edl-1/)阅读相关信息。
