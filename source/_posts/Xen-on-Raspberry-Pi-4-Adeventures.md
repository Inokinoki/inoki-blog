---
title: 【译】Xen 的奇妙冒险 —— RPi4 篇
date: 2021-01-27 15:47:40
tags:
- 中文
- 翻译
categories:
- [Translation, Chinese]
- [Embedded System, Raspberry PI]
---

原文链接：[Xen on Raspberry Pi 4 adventures](https://www.linux.com/featured/xen-on-raspberry-pi-4-adventures/)

作者：Stefano Stabellini 和 Roman Shaposhnik

树莓派（RPi）由于价格低廉而应用广泛，多年来一直是 ARM 社区的关键设备。根据 RPi 基金会的数据，已经售出了超过 3500 万台，其中 44% 销往工业领域。我们一直渴望在其上运行 Xen 管理程序，但 RPi 与其他 ARM 平台之间的技术差异使其在很长一段时间内都不能成为现实。具体来说，就是因为其使用了一个没有虚拟化支持的非标准中断控制器。

然后，带有一个标准 GIC-400 中断控制器的 Raspberry Pi 4 出现了。这个中断控制器本来就被 Xen 平台支持。终于，我们可以在 RPi 设备上运行 Xen 了。很快，Project EVE 的 Roman Shaposhnik 和其他一些社区成员开始在 xen-devel 邮件列表中询问这个问题。"这应该很容易，"我们回答道。"它甚至可能不用任何额外工作就能工作，"我们在回复中写道。但我们完全没有意识到，我们即将在 Xen 内存分配器和 Linux 地址转换层的之间里展开一场宏大的冒险。

第一个障碍是低内存地址的可用性。RPi4 的设备只能访问前 1GB 的内存。对 Dom0 来说 1GB 以下的内存是不够的。Julien Grall 通过一个简单的单行修复解决了这个问题，增加了在 RPi4 上 Dom0 的 1GB 以下内存分配。该补丁现在已经出现在 Xen 4.14 中。

"这种低于1GB的限制虽然不常见的，但现在它被修复了，它应当可以工作了。"但我们又错了，Linux中的 Xen 子系统使用 `virt_to_phys` 将虚拟地址转换为物理地址，这对大多数虚拟地址都有效，但不是所有的虚拟地址。原来，RPi4 Linux 内核有时会使用无法通过 `virt_to_phys` 转化为物理地址的虚拟地址，这样做会导致严重错误。修正的方法是在适当的时候使用不同的地址翻译函数。现在该补丁已经存在于 Linux 的主分支中。

我们感到信心十足，终于到了终点。"内存分配--检查。内存翻译--检查。成了！"不，还没有。事实证明，最重要的问题还没有被发现。Linux 内核一直有物理地址和 DMA 地址的概念，其中 DMA 地址是用来给设备编程的，它可能和物理地址不同。但实际上，在 Xen 可以运行的 x86、ARM 和 ARM64 平台，DMA 地址与物理地址相同。Linux 中的 Xen 子系统就是利用 DMA 与物理地址的二元性来进行自己的地址转换。它利用它将客户机看到的物理地址转换为 Xen 看到的物理地址。

让我们感到惊讶和惊喜的是，Raspberry Pi 4 是第一个物理地址与 DMA 地址不同的平台，导致 Linux 中的 Xen 子系统崩溃。要缩小问题的范围并不容易。一旦我们了解了这个问题，通过十几个补丁，我们完全支持了在 Linux 中处理 DMA 与物理地址的转换。Linux 补丁已经在主分支中，将在 Linux 5.9 中提供。

解决了地址翻译问题，我们有趣的 Hack 冒险就结束了。应用 Xen 和 Linux 补丁后，Xen 和 Dom0 可以完美地工作。一旦 Linux 5.9 出来，我们就可以让 Xen 在 RPi4 上开箱即用。

我们将向您展示如何在 RPi4 上运行 Xen，真正的 Xen Hack 方式，并作为下游分发的一部分，以获得更简单的最终用户体验。

# 在树莓派 4 上玩转 Xen

如果你打算在 ARM 上对 Xen 进行 Hack，并希望使用 RPi4 来完成，这里是你需要做的，以使 Xen 使用 UBoot 和 TFTP 启动和运行。我喜欢使用 TFTP，因为它可以在开发过程中极快地更新任何二进制文件。请参阅[本教程](https://help.ubuntu.com/community/TFTP)，了解如何设置和配置  TFTP 服务器。你还需要一个 UART 连接来获得 Xen 和 Linux 的早期输出，请参考[这篇文章](https://lancesimms.com/RaspberryPi/HackingRaspberryPi4WithYocto_Part1.html)。

使用 rpi-imager 格式化 SD 卡与常规默认的 Raspberry Pi 操作系统。挂载第一个SD卡分区并编辑 config.txt。确保添加以下内容：

```
kernel=u-boot.bin

enable_uart=1

arm_64bit=1
```

从任何发行版中下载一个适合 RPi4 的 U Boot 二进制文件(`u-boot.bin`)，例如 [OpenSUSE](https://en.opensuse.org/HCL:Raspberry_Pi4)。下载 JeOS 镜像，然后打开它并保存 `u-boot.bin`。

```
xz -d openSUSE-Tumbleweed-ARM-JeOS-raspberrypi4.aarch64.raw.xz

kpartx -a ./openSUSE-Tumbleweed-ARM-JeOS-raspberrypi4.aarch64.raw

mount /dev/mapper/loop0p1 /mnt

cp /mnt/u-boot.bin /tmp
```

将 `u-boot.bin` 和 `config.txt` 一起放入第一个SD卡分区。下次系统启动时，你会得到一个 UBoot 提示，允许你从网络上的 TFTP 服务器加载 Xen、Dom0 的 Linux 内核、Dom0 rootfs 和设备树。我通过在 SD 卡上放置 UBoot `boot.scr` 脚本来自动完成加载步骤：

```
setenv serverip 192.168.0.1

setenv ipaddr 192.168.0.2

tftpb 0xC00000 boot2.scr

source 0xC00000
```

其中：

```
- serverip 是你的 TFTP 服务器的 IP
- ipaddr 是你的 RPi4 的 IP
```

使用 mkimage 生成 `boot.scr`，并将其放在 `config.txt` 和 `u-boot.bin` 一起：

```
mkimage -T script -A arm64 -C none -a 0x2400000 -e 0x2400000 -d boot.source boot.scr
```

其中：

```
- boot.source 是输入
- boot.scr 是输出
```

UBoot 會自动执行所提供的 boot.scr，它会设定网络，并从 TFTP 服务器取得第二个脚本 (`boot2.scr`)。`boot2.scr` 应当包含了所有载入 Xen 和其他所需二进制文件的指令。您可以使用 ImageBuilder 生成 `boot2.scr`。

确保使用 Xen 4.14 或更高版本。Linux 内核应该是主分支（或等到 5.9 出来后，5.4-rc4 也可以），Linux ARM64 默认配置可以作为内核配置。任何 64 位的 rootfs 都应该可以用于 Dom0。使用上游 Linux 自带的 RPi4 的设备树（arch/arm64/boot/dts/broadcom/bcm2711-rpi-4-b.dtb）。注意 RPi4 有两个 UART，默认是地址为 `0x7e215040` 的 `bcm2835-aux-uart`。它在设备树中被指定为 serial1，而不是 serial0。您可以通过在 Xen 命令行中指定让 Xen 使用 serial1：

```
console=dtuart dtuart=serial1 sync_console
```

Xen 命令行由 ImageBuilder 生成的 `boot2.scr` 脚本提供，名为 "xen,xen-bootargs"。编辑 `boot2.source` 后，你可以用 mkimage 重新生成 `boot2.scr`：

```
mkimage -A arm64 -T script -C none -a 0xC00000 -e 0xC00000 -d boot2.source boot2.scr
```

# 树莓派 4 上的 Xen：一个简单的操作

通过在 RPi 4 上从头开始构建和启动 Xen 这样的脏活，不仅可以让你深感满足，而且可以让你深入了解 ARM 上的一切是如何结合在一起的。然而，有时您只是想快速体验一下在这块板子上使用 Xen 的感觉。对于 Xen 来说，这通常不是问题，因为几乎每个 Linux 发行版都提供 Xen 包，只需调用 "apt" 或 "zypper" 就可以在系统上运行一个功能齐全的 Xen。然而，鉴于 Raspberry Pi 4 的支持只有几个月的时间，整合工作还没有完成。唯一一个在 Raspberry Pi 4 上完全集成和测试支持 Xen 的操作系统是 LF Edge 的 Project EVE。

Project EVE 是一个设计上安全的操作系统，支持在现场部署的计算设备上运行边缘容器。这些设备可以是物联网网关、工业 PC 或通用计算机。所有在 EVE 上运行的应用都被表示为边缘容器，并受制于由 k3s 驱动的容器协调策略。边缘容器本身可以封装虚拟机、容器或 Unikernels。

你可以在该项目网站 http://projecteve.dev 和其 [GitHub repo](https://github.com/lf-edge/eve/blob/master/docs/README.md) 找到更多关于 EVE 的信息。为 Raspberry Pi 4 创建可启动媒体的最新说明也可在以下网站获得。

[https://github.com/lf-edge/eve/blob/master/docs/README.md](https://github.com/lf-edge/eve/blob/master/docs/README.md)

因为 EVE 发布的是完全编译完成的可下载的二进制文件，使用它在 Raspberry Pi 4 上尝试 Xen 就很简单了：

```sh
$ docker pull lfedge/eve:5.9.0-rpi-xen-arm64 # you can pick a different 5.x.y release if you like

$ docker run lfedge/eve:5.9.0-rpi-xen-arm64 live > live.raw
```

随后使用你喜欢的工具将生成的 `live.raw` 二进制文件刷写到 SD 卡上。

一旦这些步骤完成，你就可以将卡插入到你的 Raspberry Pi 4 中，连接键盘和显示器，享受一个极简主义的 Linux 发行版（基于 Alpine Linux 和 Linuxkit），这就是在 Xen 下运行的 Dom0 项目 EVE。

就 Linux 发行版而言，EVE 呈现出了一种有些新颖的操作系统设计，但同时，它也深受 Qubes OS、ChromeOS、Core OS 和 Smart OS 的启发。如果你想让它超越简单的控制台任务，探索如何在上面运行用户域，我们建议前往 EVE 的姊妹项目 [Eden](https://github.com/lf-edge/eden#raspberry-pi-4-support)，按照那边的简短教程进行操作。

如果有任何问题，您可以在 LF Edge 的 Slack 频道中找到一个活跃的 EVE 和 Eden 用户社区，从 http://lfedge.slack.com/ 的 \#eve 开始--我们很乐意听到您的反馈。

Hack 愉快！
