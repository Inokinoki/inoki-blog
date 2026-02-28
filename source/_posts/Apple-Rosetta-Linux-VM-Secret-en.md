---
title: Things You Might Want to Know About Apple's Rosetta 2 for Linux VMs
date: 2026-02-28 20:54:00
tags:
- Apple
- Rosetta
- ARM
- x86
- Virtualization
- Reverse Engineering
- English
categories:
- [Linux]
---

Rosetta 2 is a translation layer from x86-64 to ARM64 that Apple launched in 2020 alongside Apple Silicon Macs, designed to facilitate the migration of software from Intel Macs. Later, Apple integrated a Rosetta implementation specifically designed for Linux VMs into the Virtualization.framework, enabling x86-64 Linux binaries to run directly when running Linux VMs on Apple Silicon Macs. This article provides a brief introduction to this Rosetta translation layer for Linux, helping you understand how it works and some interesting phenomena you might encounter during use.

# Motivation: Why I'm Researching This

Recently, I've been creating a Virtualization.framework backend for libvirt (the work in progress can be found [here](https://github.com/Inokinoki/libvirt/pull/1)). The explicit goal of this project is to allow running **x86-64 Linux VMs on Apple Silicon Macs** through libvirt — because libvirt already has a QEMU backend that has long used Apple's Hypervisor.framework for virtualization, but on Apple Silicon, Hypervisor.framework can only run ARM64 guest systems. Otherwise, running x86-64 Linux would require emulation rather than virtualization, which comes with certain performance penalties.

Apple's Virtualization.framework offers a better alternative — by using Rosetta 2 for Linux VMs, we can run x86-64 Linux binaries on ARM hardware with near-native performance.

This article documents my discoveries and thoughts during this process, hoping to help those with similar needs understand how this technology works.

# Rosetta 2 in Linux VMs

OrbStack and Docker Desktop, which I frequently use, both provide the ability to run x86-64 containers/VMs on Apple Silicon Macs, leveraging this very technology. When you pull an amd64/x86-64 architecture container image and run it on Apple Silicon:

1. OrbStack/Docker creates a lightweight Linux VM
2. The VM transparently translates x86-64 instructions through Rosetta
3. x86 binaries inside the container are executed seamlessly

This is why you can `docker run --platform=linux/amd64` on M-series Macs without any additional configuration.

But here's an interesting phenomenon: the Linux kernel in these VMs and containers is actually **still ARM64 architecture**, but paired with an x86-64 userspace environment. For Docker, this is natural because it always needs to run a VM on Macs, and Docker images themselves don't include a kernel — when we pull a Docker image, we're actually pulling a userspace filesystem layer, not an entire operating system. For OrbStack, its VM also boots an ARM64 Linux kernel, but paired with an x86-64 userspace filesystem, using Rosetta 2 to support running x86-64 userspace programs. Generally, this is accomplished by mounting Apple's Rosetta 2 implementation for Linux VMs (the corresponding implementation can be found in `/Library/Apple/usr/libexec/oah/RosettaLinux` on the Apple host after installing Rosetta 2) into the VM — for example, through `VZLinuxRosettaDirectoryShare`, and configuring corresponding binfmts to achieve automatic translation.

```shell
% tree /Library/Apple/usr/libexec/oah/
/Library/Apple/usr/libexec/oah/
├── debugserver -> /usr/libexec/rosetta/debugserver
├── libRosettaRuntime
├── RosettaLinux
│   ├── rosetta
│   └── rosettad
├── runtime -> /usr/libexec/rosetta/runtime
└── translate_tool -> /usr/libexec/rosetta/translate_tool
```

This differs from the VMs we normally run — in traditional VMs, we can install a complete operating system via an ISO image, where both kernel and userspace are of the same architecture. In Linux VMs that use Rosetta 2, the kernel is ARM64, but the userspace filesystem is x86-64, which is the unique characteristic of Rosetta 2 in Linux VMs.

# Don't Be Confused by What You See

But if you execute `uname` or `cat /proc/cpuinfo` in this Linux VM, you'll discover an interesting phenomenon:

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

Notice several key points:

- **vendor_id** is `VirtualApple` instead of `GenuineIntel` or `AuthenticAMD`
- **model name** shows `VirtualApple @ 2.50GHz`
- **cpu family** is `6`, which is the Intel architecture family identifier
- **flags** lists x86 instruction set features

This doesn't match the description that "the VM is using an ARM64 kernel," right? Actually, this is because Rosetta 2 **intercepts certain system calls** and **file read operations** in the VM, and **modifies the CPU information returned to userspace**, making it appear as if it's running on real x86-64 hardware.

# What Rosetta 2 Does

The core work of Rosetta 2 is **instruction set translation**, including but not limited to:

- **Static translation**: When a program loads, translating x86_64 binary code into ARM64 code
- **Dynamic translation**: Handling code paths that cannot be statically translated at runtime
- **System call mapping**: Converting Linux x86_64 system calls into Linux ARM64 kernel system calls
- And more...

I'm currently having AI automatically analyze Rosetta 2's implementation for Linux VMs in the [Attesor project](https://github.com/Inokinoki/attesor). Let's look at the `/proc/cpuinfo` output as an example.

When you run `strings /Library/Apple/usr/libexec/oah/RosettaLinux/rosetta | grep "VirtualApple"`, you'll discover it contains a string template. In the code, it operates something like this:

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

In a loop, Rosetta 2 creates a temporary file in memory to output a predefined CPU information string containing the `VirtualApple` identifier, adjusting fields like `processor` and `siblings` based on the actual number of CPU cores. When there's a read access to the normalized path `/proc/cpuinfo`, this string is returned, which is why we see the output shown in the `cat /proc/cpuinfo` example above. Interestingly, fields like model name, cpu MHz, and cache size are all hardcoded and not dynamically generated based on actual CPU information.

For Rosetta 2's interception of the `uname` system call (I might be wrong about this), deeper investigation is needed, but anyway, Rosetta 2 is responsible for changing the machine type from the actual ARM to the `x86_64` we see above.

If you examine the device tree in sysfs where kernel objects are mounted (a solution adopted by the Linux community to simplify fragmented ARM device descriptions), the truth comes to light:

```shell
alpine:/proc/self$ cat /sys/firmware/devicetree/base/cpus/cpu@0/compatible
arm,arm-v8
```

The device tree honestly tells you: **This is actually an ARM v8-compatible processor**, so the kernel it boots should be ARM64 architecture.

# Summary

Apple Rosetta 2 used in virtualization is an ingenious technology that makes running x86-64 Linux binaries on Apple Silicon Macs possible through instruction set translation and system call mapping. Although the VM's kernel is actually ARM64 architecture, the userspace environment is translated by Rosetta 2 to appear as x86-64, which is why you see `uname` reporting the architecture as `x86_64` while the device tree shows ARM.

Next time when you run `docker run --platform=linux/amd64` on an M-series Mac, you might want to think about everything happening behind the scenes.

---

**References**:
- [Apple Developer Documentation: Running Intel Binaries in Linux VMs with Rosetta](https://developer.apple.com/documentation/virtualization/running-intel-binaries-in-linux-vms-with-rosetta)
