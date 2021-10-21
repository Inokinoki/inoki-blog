---
title: 通过 Linux sysfs 玩转硬件
date: 2021-10-20 19:34:00
tags:
- Linux
- Linux Driver
- sysfs
- 中文
categories:
- [Linux, sysfs]
---

对于一些非嵌入式、离硬件比较远的程序员，与硬件有关的事情可能完全是一个黑匣子：我只需要插上 USB 线缆、插上 HDMI 线缆，就可以把硬件连接到计算机；我只需要按一个按键，就可以调节屏幕的亮度。作为一个程序员或者计算机爱好者，我有没有可能自己写一些代码 snippets 来完成一些自定义的事情呢？

本文就将介绍如何通过 Linux 系统的 sysfs 模块、用一些简单的代码/shell 操作硬件。

# 硬件、Linux 系统与 sysfs 模块

操作系统是计算机硬件和用户之间的接口，它可以处理计算机硬件资源并为计算机程序提供基本服务，驱动硬件是它所拥有的一个很重要的功能。下图显示了操作系统内核所在的位置：它作为硬件和 shell、应用程序之间的一层，提供接口。

![Linux 系统架构——图源 javatpoint.com](https://static.javatpoint.com/linux/images/architecture-of-linux.png)

根据 Linux 的手册，sysfs 文件系统是一个伪文件系统，它提供了一个内核数据结构的接口。这个文件系统的文件并不是真实存在在硬盘上的文件，它提供有关设备、内核模块、文件系统和其他内核组件的信息，对这里的文件的读写就是对内核中对象的操作。

硬件驱动是 Linux 内核的一部分，过去是被静态编译到内核中，而在当代的 Linux 系统中大部分驱动程序都可以被编译成内核模块（kernel module）、动态加载到内核中。当设备插入时，内核会创建一个内核对象，并为对对象的操作设置对应驱动中的回调函数。这个对象也会被映射到 sysfs 中。

# sysfs 的结构

在 Linux 中，sysfs 一般会被自动挂载到 `/sys` 目录下。我的计算机在该目录下有以下子目录：

```
block  bus  class  dev  devices  firmware  fs  hypervisor  kernel  module  power
```

有块设备、按总线分类、按设备类别分类、文件系统、内核模块等。

我个人比较常用的是 `class`，在这个目录下，设备按照所属的类别分类：

{% asset_img sysfs_class.png 类别 %}

可以看到，有 `backlight` 背光设备、`bluetooth` 蓝牙设备、`input` 输入设备、`leds` 灯、`tty` 等。

它们的子目录是一些具体的设备对应的目录（如果有相应设备被内核驱动起来的话），在这些目录里往往有一些可以读写的文件，这些文件对应着设备在内核中的状态。

# 写 sysfs 的文件对象调节显示器亮度

如果你拥有一台带有 Intel 集成显卡的笔记本，且安装了一个带 GUI 的 Linux 发行版，那大概率使用的是 i915 或者 i965 驱动。在 `/sys/class/backlight/intel_backlight` 下就会有以下文件：

{% asset_img intel_backlight.png Intel 显示驱动在 sysfs 中的文件 %}

其中 `brightness` 为一个 root 可读可写的文件，通过它可以设置屏幕亮度；`max_brightness` 为一个 root 可读的文件，它储存了可以设置的最大屏幕亮度。因此，我们可以用一个简单的 shell 脚本读取期望亮度百分比、允许的最大亮度，并将计算结果写入 `brightness` 来设置屏幕亮度百分比：

```bash
#!/bin/bash

echo "请输入您想要的亮度百分比:"
read expected_brightness
echo $expected_brightness

max_brightness=$(cat /sys/class/backlight/intel_backlight/max_brightness)

echo $(expr $expected_brightness \* $max_brightness \/ 100) > /sys/class/backlight/intel_backlight/brightness
```

之后，使用 sudo 运行这个脚本（写入 `brightness` 文件需要 root 用户身份）并输入你期望的百分比（注意：为了保持简短，这个脚本没有对输入值进行任何判断，take your own risk），效果如下：

{% asset_img set_backlight.png 设置背光 %}

这时我的屏幕背光亮度就被设置为了 15%。

当然，你也可以用 C 语言、Python 或者任何你喜欢的语言，通过读写 sysfs 下的文件控制一些硬件。这都取决于你的想法和创意了！

注：如果你使用的是其他显卡、或者外接显示器，能否有效果就取决于具体的硬件了。

# 结论

本文粗略介绍了 Linux 系统的 sysfs 模块的概念和用法，并提供了一个简单的脚本来设置显示屏的背光。
