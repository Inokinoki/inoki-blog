---
title: 关于 Apple 为 Linux 虚拟机提供的 Rosetta 2 你可能想知道的事
date: 2026-02-28 20:52:00
tags:
- Apple
- Rosetta
- ARM
- x86
- 虚拟化
- 逆向
- 中文
categories:
- [Linux]
---

Rosetta（罗赛塔）2 是苹果 Apple 在 2020 年推出 Apple Silicon Mac 时，为了方便迁移 Intel Mac 上的软件而推出的 x86-64 到 ARM64 的翻译层。后来， Apple 在 Virtualization.framework 中集成了一个专门为 Linux 虚拟机设计的 Rosetta 实现，使得在 Apple Silicon Mac 上运行 Linux 虚拟机时，也可以直接跑 x86-64 的 Linux 二进制程序。本篇文章将对这个给 Linux 使用的 Rosetta 2 翻译层的进行简要介绍，帮助你理解它是如何工作的，以及在使用过程中可能遇到的一些有趣现象。

# 动机：为什么我研究这个

最近我在为 libvirt 创建 Virtualization.framework 后端（正在进行的工作在[这里](https://github.com/Inokinoki/libvirt/pull/1)）。这个项目的明确目标是允许通过 libvirt **在 Apple Silicon Mac 上运行 x86-64 Linux 虚拟机**——因为 libvirt 已经有了 QEMU 后端，长久以来都使用 Apple 的 Hypervisor.framework 来实现虚拟化，但在 Apple Silicon 上，Hypervisor.framework 只能运行 ARM64 的客户机系统，否则就需要通过模拟而不是虚拟化来运行 x86-64 的 Linux，这会带来一定的性能损失。

而 Apple 的 Virtualization.framework 提供了更好的选择——通过给 Linux 虚拟机使用 Rosetta 2，我们可以在 ARM 硬件上以接近原生的性能运行 x86-64 Linux 二进制文件。

这篇文章记录了我在这个过程中的发现和思考，希望能帮助有类似需求的人理解这项技术的工作原理。

# 在 Linux 虚拟机中的 Rosetta 2

我经常使用的 OrbStack 和 Docker Desktop 都提供了在 Apple Silicon Mac 上运行 x86-64 容器/虚拟机的功能，他们正是利用了这项技术。当你拉取一个 amd64/x86-64 架构的容器镜像并在 Apple Silicon 上运行时：

1. OrbStack/Docker 创建一个轻量级 Linux VM
2. 虚拟机通过 Rosetta 透明地翻译 x86-64 指令
3. 容器内的 x86 二进制文件被无缝执行

这就是为什么你可以在 M 系列 Mac 上 `docker run --platform=linux/amd64` 而无需任何额外配置。

但这里有个有趣的现象，实际上这些虚拟机和容器的 Linux 内核**仍是 ARM64 架构**的，但是配了一套 x86-64 的用户态环境。对于 Docker 来说这很自然，因为它在 Mac 上总是需要跑一个虚拟机，并且 Docker 镜像本身是不包括内核的——当我们拉取一个 Docker 镜像的时候，实际上是拉取了一个用户态的文件系统层，而不是整个操作系统。而对于 OrbStack 来说，它的虚拟机本身也是启动了一个 ARM64 的 Linux 内核，但配合了一套 x86-64 的用户态文件系统，并且通过 Rosetta 2 来支持运行 x86-64 的用户态程序。一般情况下，这是通过将 Apple 为 Linux 虚拟机准备的 Rosetta 2 实现（相应的实现可以在安装 Rosetta 2 后在 Apple 宿主机的相应目录 `/Library/Apple/usr/libexec/oah/RosettaLinux` 中找到）挂载到虚拟机中来完成的——例如通过 `VZLinuxRosettaDirectoryShare`、并配置相应的 binfmts 来实现自动翻译。

```shell
% tree /Library/Apple/usr/libexec/oah/             
/Library/Apple/usr/libexec/oah/
├── debugserver -> /usr/libexec/rosetta/debugserver
├── libRosettaRuntime
├── RosettaLinux
│   ├── rosetta
│   └── rosettad
├── runtime -> /usr/libexec/rosetta/runtime
└── translate_tool -> /usr/libexec/rosetta/translate_tool
```

这就与我们平时运行的虚拟机有所不同——在传统的虚拟机中，我们是可以通过一个 ISO 镜像来安装一个完整的操作系统的，其中内核和用户态都是同一架构的。而在这种要使用 Rosetta 2 的 Linux 虚拟机中，内核是 ARM64 的，但用户态的文件系统却是 x86-64 的，这就是 Rosetta 2 在 Linux 虚拟机中的独特之处。



# 不要被你所看到的迷惑了

但是如果你在这个 Linux 虚拟机中执行 `uname` 或者 `cat /proc/cpuinfo` 时，你会发现一个有趣的现象：

```shell
alpine:/proc/self$ uname -a
Linux alpine 6.17.8-orbstack-00308-g8f9c941121b1 #1 SMP PREEMPT Thu Nov 20 09:34:02 UTC 2025 x86_64 Linux
alpine:/proc/self$ cat /proc/cpuinfo
processor    : 0
vendor_id    : VirtualApple
cpu family   : 6
model        : 142
model name   : VirtualApple @ 2.50GHz
stepping     : 10
cpu MHz      : 2502.057
cache size   : 6144 KB
flags        : fpu tsc de cx8 apic sep cmov pat pse36 clflush mmx fxsr sse sse2
               syscall nx lm rep_good nopl pni cpuid pclmulqdq ssse3 cx16 sse4_1
               popcnt sse4_2 aes lahf_lm movbe fma f16c rdrand bmi1 bmi2
...
```

注意到几个关键点：

- **vendor_id** 是 `VirtualApple` 而非 `GenuineIntel` 或 `AuthenticAMD`
- **model name** 显示 `VirtualApple @ 2.50GHz`
- **cpu family** 是 `6`，这是 Intel 架构的家族标识
- **flags** 中列出的都是 x86 指令集特性

这与“虚拟机在使用 ARM64 内核”的描述不符呀？实际上，这是因为 Rosetta 2 在虚拟机中**拦截了一些系统调用**和**文件读取操作**，并且**修改了返回给用户态的 CPU 信息**，让它看起来好像是在一个真正的 x86-64 硬件上运行一样。

# Rosetta 2 做了什么

Rosetta 2 的核心工作是**指令集翻译**，包括但不限于：

- **静态翻译**：在程序加载时，将 x86_64 二进制代码翻译成 ARM64 代码
- **动态翻译**：运行时处理无法静态翻译的代码路径
- **系统调用映射**：将 Linux x86_64 的系统调用转换为 Linux ARM64 内核的系统调用
- 等等...

我正在让 AI 全自动地在[Attesor 项目](https://github.com/Inokinoki/attesor)中分析 Rosetta 2 针对 Linux 虚拟机的实现，让我们来看 `/proc/cpuinfo` 的输出作为例子。

当你运行 `strings /Library/Apple/usr/libexec/oah/RosettaLinux/rosetta | grep "VirtualApple"` 的时候，你会发现它包含了一个字符串模版。实际上在代码中，它是类似于这样的操作：

```c
iVar7 = 0;
do {
    fprintf(stdout,
            "processor\t: %u\nvendor_id\t: VirtualApple\ncpu family\t: 6\nmodel\t\t: 142\nmodel name\t: VirtualApple @ 2.50GHz\nstepping\t: 10\ncpu MHz\t\t: 2502.057\ncache size\t: 6144 KB\nphysical id\t: 0\nsiblings\t: %u\ncore id\t\t: %u\ncpu cores\t: %u\napicid\t\t: %u\ninitial apicid\t: %u\nfpu\t\t: yes\nfpu_exception\t: no\ncpuid level\t: 22\nwp\t\t: yes\nflags\t\t: fpu tsc de cx8 apic sep cmov pat pse36 clflush mmx fxsr sse sse2 syscall nx lm rep_good nopl pni cpuid pclmulqdq ssse3 cx16 sse4_1 popcnt sse4_2 aes lahf_lm movbe fma avx f16c rdrand bmi1 avx2 bmi2\nbugs\t\t:\nbogomips\t: 5184.11\nclflush size\t: 64\ncache_alignment\t: 64\naddress sizes\t: 39 bits physical, 48 bits virtual\npower management:\n\n"
            ,iVar7,iVar6,iVar7,iVar6,iVar7,iVar7
    );
    iVar7 = iVar7 + 1;
} while (iVar6 != iVar7);
```

在一个循环中，Rosetta 2 会创建一个内存中的临时文件、方便输出一个预定义的 CPU 信息字符串，其中包含了 `VirtualApple` 的标识，并且根据实际的 CPU 核心数量来调整输出的 `processor` 和 `siblings` 等字段。当有针对 `/proc/cpuinfo` 这个正则化后的路径读取访问时，返回的就是这个字符串，因此我们看到的输出就是我们在上面 `cat /proc/cpuinfo` 中看到的内容。可以看到，比较有趣的还有 model name、cpu MHz、cache size 这些字段，他们都是硬编码的，并没有根据实际的 CPU 信息来动态生成。

针对于 Rosetta 2 拦截 `uname` 系统调用的操作（也可能我搞错了），需要更深入地去挖掘，但总之也是 Rosetta 2 负责将机器类型从实际的 ARM 改为我们上面看到的 `x86_64` 的。

如果你检查挂载了内核对象的 sysfs 中的设备树（Linux 社区为了简化碎片化的 ARM 设备描述而采用的方案），真相就会浮出水面：

```shell
alpine:/proc/self$ cat /sys/firmware/devicetree/base/cpus/cpu@0/compatible
arm,arm-v8
```

设备树诚实地告诉你：**这实际上是一个 ARM v8 兼容的处理器**，那么它启动的内核也就应当是 ARM64 架构的。

# 总结

在虚拟化中使用的 Apple Rosetta 2 是一项精妙的技术，它通过指令集翻译和系统调用映射，使得在 Apple Silicon Mac 上运行 x86-64 Linux 二进制程序成为可能。虽然虚拟机的内核实际上是 ARM64 架构的，但用户态环境被 Rosetta 2 翻译成了 x86-64 的样子，这就是为什么你会看到 `uname` 报告的架构是 `x86_64`，而设备树却显示为 ARM 的原因。

下一次你在 M 系列 Mac 上运行 `docker run --platform=linux/amd64` 时，不妨思考一下背后发生的一切。

---

**参考链接**：
- [Apple Developer Documentation: Running Intel Binaries in Linux VMs with Rosetta](https://developer.apple.com/documentation/virtualization/running-intel-binaries-in-linux-vms-with-rosetta)
