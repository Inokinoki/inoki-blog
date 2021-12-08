---
title: 【译】Linux 内核的 VFIO - “Virtual Function I/O”
date: 2021-12-08 20:34:00
tags:
- Linux
- 翻译
- 中文
categories:
- [Linux]
---

原文链接：[VFIO - “Virtual Function I/O”](https://www.kernel.org/doc/html/latest/driver-api/vfio.html)

许多现代系统现在提供 DMA 和中断重映射设施，以帮助确保 I/O 设备在它们被分配的边界内行事。这包括带有 AMD-Vi 和 Intel VT-d 的 x86 硬件，带有可分区终端（PE）的 POWER 系统和嵌入式 PowerPC 系统，如 Freescale PAMU。VFIO 驱动是一个 IOMMU/设备无关的框架，在一个安全的、受 IOMMU 保护的环境中，将设备访问直接暴露给用户空间。换句话说，这允许安全的[2]、非特权的用户空间驱动程序。

我们为什么要这样做？当配置为最高的 I/O 性能时，虚拟机经常利用直接设备访问（"设备分配"）。从设备和主机的角度来看，这只是把虚拟机变成了一个用户空间驱动程序，其好处是大大降低了延迟，提高了带宽，并直接使用裸机设备驱动程序[3]。

一些应用，特别是在高性能计算领域，也从用户空间的低开销、直接设备访问中受益。例如，网络适配器（通常是基于非 TCP/IP）和计算加速器。在 VFIO 之前，这些驱动必须经过完整的开发周期才能成为合适的上游驱动，或者在代码树外进行维护，或者使用 UIO 框架，它没有 IOMMU 保护的概念，中断支持有限，并且需要 root 权限来访问 PCI 配置空间等东西。

VFIO 驱动框架打算将这些统一起来，取代 KVM 的 PCI 特定设备分配代码，并提供一个比 UIO 更安全、更有特色的用户空间驱动环境。

# 组、设备和 IOMMU

设备是任何 I/O 驱动的主要目标。设备通常创建一个由 I/O 访问、中断和 DMA 组成的编程接口。在不深入了解这些细节的情况下，DMA 是迄今为止维护安全环境的最关键的方面，因为允许设备对系统内存进行读写访问会给整个系统的完整性带来最大的风险。

为了帮助减轻这种风险，许多现代的 IOMMU 现在将隔离属性纳入了一个在许多情况下只用于转换的接口（即解决具有有限地址空间的设备的寻址问题）。有了这个，设备现在可以相互隔离，并与任意的内存访问隔离，从而允许像安全地直接将设备分配到虚拟机中。

不过，这种隔离并不总是在单个设备的颗粒度上。即使 IOMMU 能够做到这一点，设备、互连和 IOMMU 的拓扑结构的属性也会减少这种隔离。例如，一个单独的设备可能是一个更大的多功能包装的一部分。虽然 IOMMU 可能能够区分包装内部的设备，但包装可能不要求设备之间的事件到达 IOMMU。这方面的例子可能是任何东西，从一个多功能的 PCI 设备，在功能之间有后门，到一个非PCI-ACS（访问控制服务）能力的桥梁，允许重定向而不到达 IOMMU。在隐藏设备方面，拓扑结构也可以起到一定的作用。一个 PCI-to-PCI 网桥掩盖了它后面的设备，使事件看起来像是来自网桥本身。显然，IOMMU 的设计也是一个主要因素。

因此，虽然在大多数情况下，IOMMU 可能有设备级别的颗粒度，但任何系统都容易受到颗粒度降低的影响。因此，IOMMU API 支持 IOMMU 组的概念。一个组是一组设备，可与系统中所有其他设备隔离。因此，组是 VFIO 使用的所有权单位。

虽然组是为确保用户安全访问而必须使用的最小粒度，但它不一定是首选粒度。在使用页表的 IOMMU 中，有可能在不同的组之间共享一组页表，从而减少对平台（减少 TLB 激动，减少重复的页表）和用户（只编程一组翻译）的开销。出于这个原因，VFIO使用了一个容器类，它可以容纳一个或多个组。通过简单地打开 `/dev/vfio/vfio` 字符设备来创建一个容器。

就其本身而言，容器提供的功能很少，除了几个版本和扩展查询接口外，其他的都被锁定了。用户需要在容器中添加一个组，以获得下一级的功能。要做到这一点，用户首先需要确定与所需设备相关的组。这可以通过下面的例子中描述的 sysfs 链接来完成。通过将设备从主机驱动上解除绑定并将其绑定到 VFIO 驱动上，一个新的 VFIO 组将以 `/dev/vfio/$GROUP` 的形式出现，其中 `$GROUP` 是设备所属的 IOMMU 组号。如果 IOMMU 组包含多个设备，在允许对 VFIO 组进行操作之前，每个设备都需要被绑定到一个 VFIO 驱动上（如果 VFIO 驱动不可用，只将设备从主机驱动上解除绑定也是足够的；这将使组可用，但不是那个特定设备）。TBD - 用于禁用驱动程序探测/锁定设备的接口。

一旦组准备好了，可以通过打开 VFIO 组字符设备（`/dev/vfio/$GROUP`）并使用 `VFIO_GROUP_SET_CONTAINER` 的  ioctl，传递先前打开的容器文件的文件描述符，将其加入到容器中。如果需要，并且 IOMMU 驱动支持在组之间共享 IOMMU 上下文，多个组可以被设置到同一个容器中。如果一个组不能被设置到有现有组的容器中，就需要使用一个新的空容器来代替。

当一个组（或多个组）连接到一个容器时，其余的 ioctls 变得可用，从而能够访问 VFIO IOMMU 接口。此外，现在可以使用 VFIO 组文件描述符上的 ioctl 获得组内每个设备的文件描述符。

VFIO 设备 API 包括用于描述设备、I/O 区域和它们在设备描述符上的读/写/映射偏移的 ioctls，以及用于描述和注册中断通知的机制。

# VFIO使用实例

假设用户想访问PCI设备0000:06:0d.0：

```
$ readlink /sys/bus/pci/devices/0000:06:0d.0/iommu_group
../../../../kernel/iommu_groups/26
```

因此，这个设备属于 IOMMU 第 26 组。该设备在 pci 总线上，因此用户将使用 vfio-pci 来管理该组：

```
# modprobe vfio-pci
```

将这个设备绑定到 vfio-pci 驱动上，为这个组创建 VFIO 组的字符设备：

```
$ lspci -n -s 0000:06:0d.0
06:0d.0 0401: 1102:0002 (rev 08)
# echo 0000:06:0d.0 > /sys/bus/pci/devices/0000:06:0d.0/driver/unbind
# echo 1102 0002 > /sys/bus/pci/drivers/vfio-pci/new_id
```

现在我们需要看看组中还有哪些设备，以释放它供 VFIO 使用:

```
$ ls -l /sys/bus/pci/devices/0000:06:0d.0/iommu_group/devices
total 0
lrwxrwxrwx. 1 root root 0 Apr 23 16:13 0000:00:1e.0 ->
        ../../../../devices/pci0000:00/0000:00:1e.0
lrwxrwxrwx. 1 root root 0 Apr 23 16:13 0000:06:0d.0 ->
        ../../../../devices/pci0000:00/0000:00:1e.0/0000:06:0d.0
lrwxrwxrwx. 1 root root 0 Apr 23 16:13 0000:06:0d.1 ->
        ../../../../devices/pci0000:00/0000:00:1e.0/0000:06:0d.1
```

这个设备在一个 PCI-to-PCI 桥[4]后面，因此我们还需要按照上面的程序将设备 `0000:06:0d.1` 添加到组中。设备 `0000:00:1e.0` 是一个目前没有主机驱动的桥，因此不需要将这个设备绑定到 vfio-pci 驱动上（vfio-pci 目前不支持 PCI 桥）。

最后一步是，如果需要非特权操作，则为用户提供对该组的访问权（注意，`/dev/vfio/vfio` 本身不提供任何能力，因此预计系统会将其设置为模式 0666）。

```
# chown user:user /dev/vfio/26
```

用户现在可以完全访问这个组的所有设备和 iommu，并可以按以下方式访问它们：

```c
int container, group, device, i;
struct vfio_group_status group_status =
                                { .argsz = sizeof(group_status) };
struct vfio_iommu_type1_info iommu_info = { .argsz = sizeof(iommu_info) };
struct vfio_iommu_type1_dma_map dma_map = { .argsz = sizeof(dma_map) };
struct vfio_device_info device_info = { .argsz = sizeof(device_info) };

/* Create a new container */
container = open("/dev/vfio/vfio", O_RDWR);

if (ioctl(container, VFIO_GET_API_VERSION) != VFIO_API_VERSION)
        /* Unknown API version */

if (!ioctl(container, VFIO_CHECK_EXTENSION, VFIO_TYPE1_IOMMU))
        /* Doesn't support the IOMMU driver we want. */

/* Open the group */
group = open("/dev/vfio/26", O_RDWR);

/* Test the group is viable and available */
ioctl(group, VFIO_GROUP_GET_STATUS, &group_status);

if (!(group_status.flags & VFIO_GROUP_FLAGS_VIABLE))
        /* Group is not viable (ie, not all devices bound for vfio) */

/* Add the group to the container */
ioctl(group, VFIO_GROUP_SET_CONTAINER, &container);

/* Enable the IOMMU model we want */
ioctl(container, VFIO_SET_IOMMU, VFIO_TYPE1_IOMMU);

/* Get addition IOMMU info */
ioctl(container, VFIO_IOMMU_GET_INFO, &iommu_info);

/* Allocate some space and setup a DMA mapping */
dma_map.vaddr = mmap(0, 1024 * 1024, PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS, 0, 0);
dma_map.size = 1024 * 1024;
dma_map.iova = 0; /* 1MB starting at 0x0 from device view */
dma_map.flags = VFIO_DMA_MAP_FLAG_READ | VFIO_DMA_MAP_FLAG_WRITE;

ioctl(container, VFIO_IOMMU_MAP_DMA, &dma_map);

/* Get a file descriptor for the device */
device = ioctl(group, VFIO_GROUP_GET_DEVICE_FD, "0000:06:0d.0");

/* Test and setup the device */
ioctl(device, VFIO_DEVICE_GET_INFO, &device_info);

for (i = 0; i < device_info.num_regions; i++) {
        struct vfio_region_info reg = { .argsz = sizeof(reg) };

        reg.index = i;

        ioctl(device, VFIO_DEVICE_GET_REGION_INFO, &reg);

        /* Setup mappings... read/write offsets, mmaps
         * For PCI devices, config space is a region */
}

for (i = 0; i < device_info.num_irqs; i++) {
        struct vfio_irq_info irq = { .argsz = sizeof(irq) };

        irq.index = i;

        ioctl(device, VFIO_DEVICE_GET_IRQ_INFO, &irq);

        /* Setup IRQs... eventfds, VFIO_DEVICE_SET_IRQS */
}

/* Gratuitous device reset and go... */
ioctl(device, VFIO_DEVICE_RESET);
```

# VFIO User API

完整的 API 参考请查看 `include/linux/vfio.h`。

## VFIO 总线驱动 API

VFIO 总线驱动，比如 vfio-pci，只使用了 VFIO 核心的几个接口。当设备被绑定和解绑到驱动上时，驱动应该分别调用 `vfio_register_group_dev()` 和 `vfio_unregister_group_dev()`：

```c
void vfio_init_group_dev(struct vfio_device *device,
                        struct device *dev,
                        const struct vfio_device_ops *ops);
void vfio_uninit_group_dev(struct vfio_device *device);
int vfio_register_group_dev(struct vfio_device *device);
void vfio_unregister_group_dev(struct vfio_device *device);
```

驱动程序应该将 vfio_device 嵌入到它自己的结构中，并在进行注册前调用 `vfio_init_group_dev()` 进行预配置，在完成取消注册后调用 `vfio_uninit_group_dev()`。 `vfio_register_group_dev()` 指示内核开始跟踪指定 dev 的 `iommu_group`，并将该 dev 注册为 VFIO 总线驱动程序拥有。一旦 `vfio_register_group_dev()` 返回，用户空间就有可能开始访问驱动，因此驱动应该在调用它之前确保它完全准备好。驱动程序为回调提供了一个类似于文件操作结构的 OP 结构：

```c
struct vfio_device_ops {
        int     (*open)(struct vfio_device *vdev);
        void    (*release)(struct vfio_device *vdev);
        ssize_t (*read)(struct vfio_device *vdev, char __user *buf,
                        size_t count, loff_t *ppos);
        ssize_t (*write)(struct vfio_device *vdev,
                         const char __user *buf,
                         size_t size, loff_t *ppos);
        long    (*ioctl)(struct vfio_device *vdev, unsigned int cmd,
                         unsigned long arg);
        int     (*mmap)(struct vfio_device *vdev,
                        struct vm_area_struct *vma);
};
```

每个函数都被传递给最初在上面的 `vfio_register_group_dev()` 调用中注册的 vdev。这允许总线驱动器使用 `container_of()` 获得其私有数据。当为一个设备创建一个新的文件描述符时（通过 `VFIO_GROUP_GET_DEVICE_FD`），会发出 open/release 回调。ioctl 接口为 `VFIO_DEVICE_*` ioctls提供了一个直接的通道。读/写/mmap 接口实现了设备区域的访问，这些访问是由设备自己的 `VFIO_DEVICE_GET_REGION_INFO` ioctl定义的。

1. VFIO 最初是"虚拟功能I/O"的首字母缩写，由汤姆-里昂在担任思科公司时实现。我们后来已经不再使用这个缩写了，但它很好听。
2. "安全"也取决于设备的 "行为良好"。多功能设备有可能在功能之间有后门，甚至单功能设备也有可能通过 MMIO 寄存器对 PCI 配置空间等进行替代访问。为了防止前者，我们可以在 IOMMU 驱动中加入额外的预防措施，将多功能 PCI 设备分组（iommu=group_mf）。后者我们无法防止，但 IOMMU 仍应提供隔离。对于 PCI 来说，SR-IOV 虚拟功能是 "行为良好 "的最佳指标，因为这些是为虚拟化使用模式设计的。
3. 像往常一样，虚拟机设备分配有一些权衡，超出了VFIO的范围。预计未来的 IOMMU 技术将减少一些，但也许不是全部，这些折衷。
4. 在这种情况下，设备在 PCI 桥下面，所以来自设备的任何功能的事件对 iommu 来说都是无法区分的。
```
    -[0000:00]-+-1e.0-[06]--+-0d.0
                            \-0d.1
00:1e.0 PCI bridge: Intel Corporation 82801 PCI Bridge (rev 90)
```
