---
title: 【译】在任何上下文中进行 TrustZone 内核中的任意代码执行
date: 2023-04-29 11:20:00
tags:
- Android
- ABL
- Linux
- Bootloader
- 中文
categories:
- [Linux, Android]
---

在[本篇博客](http://bits-please.blogspot.com/2015/03/getting-arbitrary-code-execution-in.html)中，我们的目标是使用 TrustZone 内核代码执行漏洞超越 Android。

这将是一系列博客文章，详细介绍我发现的一系列漏洞，使我们能够从任何用户提升特权，直到最高特权——在 TrustZone 中执行我们的代码。

由于我只有一台个人 Android 设备，一台由 Snapdragon 800 SoC 驱动的 Nexus 5，因此我将重点关注我的设备上存在的 TrustZone 平台—— Qualcomm 的 TrustZone 实现。

应该注意到，Qualcomm 的 TrustZone 平台存在于由 Qualcomm SoC 驱动的所有设备上，但是他们也允许 OEM 对该平台进行修改和添加，我将在以后的博客文章中详细介绍。

此外，我相信客观地说，Qualcomm 的 TrustZone 实现是一个很好的目标，因为 Snapdragon SoC 非常普遍，可以在非常广泛的设备中找到（这并不奇怪，考虑到 Qualcomm 在智能手机芯片组市场上有非常大的市场份额）。

# Android 和安全性

多年来，Android 已经增加了许多安全机制，并改进了现有机制。

尽管基础安全体系结构没有改变，但在现代设备上，现有的防御措施已经变得非常强大，以至于获得高特权可能成为一项相当困难的任务，往往需要多个漏洞。

如果您还没有阅读过 Google 的“Android 安全概述”，我建议您阅读一下，其中解释了安全架构并列出了目前使用的大多数安全机制。

（对于本系列博客文章，我将假定您至少对 Android 的安全架构有一定的了解）。

# 什么是 TrustZone？

![](http://3.bp.blogspot.com/-GOr5G0o8HKI/VErVJgcR7gI/AAAAAAAABnQ/qXtM2cmQ6t0/s1600/TrustZone.jpg)

TrustZone 是一种系统范围的安全性解决方案，适用于手持设备、平板电脑、可穿戴设备和企业系统等多种计算平台。该技术的应用范围非常广泛，包括支付保护技术、数字版权管理、BYOD 以及许多安全企业解决方案。

简而言之，TrustZone 是一个旨在实现目标设备上的“安全执行”的系统。

为了执行安全的 TrustZone 代码，需要指定一个特定的处理器。该处理器可以执行非安全代码（在“Normal World”中）和安全代码（在“Secure World”中）。其他所有处理器仅能运行在“Normal World”。

在 Android 设备上，TrustZone 用于各种不同的目的，例如：

- 验证内核完整性（TIMA）
- 使用硬件凭证存储（被“keystore”、“dm-verity”使用）
- 移动支付的安全元素仿真
- 实现和管理安全启动
- DRM（例如 PlayReady）
- 访问平台硬件功能（例如硬件熵）

为了保护整个系统而不仅仅是应用程序处理器，当进入“Secure World”时，在系统总线上设置特定位，返回“Normal World”时取消设置这些位。外围设备可以访问这些位的状态，从而可以推断出我们当前是否正在安全世界中运行。

# TrustZone 的安全模型是如何工作的

ARM 还提供了一个简短的 [TrustZone 安全模型技术概述](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0333h/Chdfjdgi.html)，值得一读。

要实现安全执行，需要定义 TrustZone 与非 TrustZone 代码之间的边界。这可以通过定义两个“世界” -“Secure World”（TrustZone）和“Normal World”（在我们的情况下为 Android）来实现。

如您所知，在“Normal World”中，运行在“User-mode”和运行在“Supervisor-mode”（Kernel-mode）中的代码之间存在一个安全边界。

不同模式之间的区别由当前程序状态寄存器（CPSR）管理：

在 TrustZone 中，一个特定的处理器执行安全代码，并且系统总线上特定位的状态决定我们当前是否正在安全世界中运行。

![](http://3.bp.blogspot.com/-WRjkrw2MYg0/VErcugSd38I/AAAAAAAABng/Hs8y4qeUUhE/s1600/cpsr.png)

以上图像中标记为"M"的五个模式位（mode bits）控制当前的执行模式。在 Linux 内核的情况下，用户模式（User Mode，b10000）用于普通用户代码，而 Supervisor 者模式（Supervisor Mode，b10011）用于内核代码。

然而，这里缺少了一些东西 - 没有一个位来指示当前活动的“世界”。这是因为有一个单独的寄存器用于这个目的 - 安全配置寄存器（Secure Configuration Register，SCR）：

![](http://2.bp.blogspot.com/-9Xq2n4c_Emk/VErpbuunTdI/AAAAAAAABnw/SnAN8vGhCQA/s1600/scr.png)

这个寄存器是一个协处理器寄存器，位于 CP15 c1，这意味着可以使用 MRC / MCR 操作码来访问它。

与 CPSR 寄存器一样，“Normal World”不能直接修改 SCR 寄存器。然而，它可以执行 SMC 操作码，这相当于普通 Supervisor 模式调用的 SWI。SMC 是 Supervisor Mode Call 的缩写，是可用于直接向 TrustZone 内核发出请求的操作码。

此外，需要注意的是，SMC 操作码只能从 Supervisor 上下文中调用，这意味着常规用户代码无法使用 SMC 操作码。

为了实际调用 TrustZone 相关功能，Supervisor 的代码，即我们的 Linux 内核，必须注册某种服务，以便在需要时调用相关的 SMC 调用。
在 Qualcomm 的情况下，这是通过一个名为 qseecom 的设备驱动程序来实现，该缩写代表 Qualcomm 安全执行环境通信。稍后的博客文章中我们会更详细地谈论这个驱动程序，敬请关注。

# 综合起来

因此，要从没有权限的用户模式 Android 应用程序中获得 TrustZone 代码执行，我们需要以下特权升级漏洞：

- 从没有权限的 Android 应用程序升级到拥有特权的 Android 用户。
- 从特权的 Android 用户升级到 Linux 内核中的代码执行。
- 从 Linux 内核升级到 TrustZone 内核中的代码执行。

因此，如果您对此感兴趣，请继续阅读！

在下一篇博客文章中，我将介绍更多关于 Qualcomm 的 TrustZone 实现的细节，以及我在其内核中发现和利用的漏洞。
