---
title: Linux 内核的用户态驱动框架
date: 2021-12-14 15:49:00
tags:
- Linux
- 驱动
- 中文
categories:
- [Linux, Driver]
---

在 Linux 的驱动模型中，存在各种驱动子系统，如 PCI 子系统、网络子系统。在开发驱动的时候，我们可以使用相应的子系统来完成，比如有人想开发一个 PCI 网卡驱动，那就可以结合上述的两个子系统来完成。

但有时会有许多非标准的硬件并不能直接使用这些子系统，比如模拟或数字 I/O，自定义的 FPGA 硬件等。这时就需要进行更加艰难的内核开发，对于工业界的程序员来说，这不是一件简单的事。

# 传统的驱动开发模型

一般这种非标准的硬件可以用字符设备实现，放在 `/dev/xyz` 中，用户态的应用程序可以调用 read 和 write 方法来控制设备，在更复杂的情况下也可以使用 ioctl 来设置额外的功能。

{% asset_img conventional_driver.png %}

在实现这个字符设备的内核中的非标准硬件的驱动时，也要会使用许多不稳定的内核内部的 API。况且因为没有可用的子系统可用，驱动会变得很大，在之后的内核版本也更加难以维护。这时使用用户态的 I/O 框架就可以极大地简化驱动开发。 

# Userspace I/O 框架

Userspace I/O（UIO）就是这样一个用户态框架，在 Linux 2.6.23 中被引入。

## 架构

在用户态它允许使用 mmap 进行设备内存到用户态内存的映射，从而允许在用户态直接读写设备内存或寄存器，并通过 read 调用来获取设备中断（通常中断都是在内核中处理的，而 UIO 允许在中断发生时通过 read 调用返回到用户态）。

{% asset_img uio_driver.png %}

而在内核中开发者需要置入一个小模块，用来探测（probe）设备和注册 UIO，注册后设备会出现在 `/dev/uioX`、并在 sysfs 中导出设备名称、属性等信息。

注意：这里同样可以使用 select 系统调用、来在没有中断的时候防止任务空转。

## 源码

相关的声明和结构体位于 `include/linux/uio_driver.h` 中，其中最重要的结构为 `uio_info`：

```c
struct uio_info {
	struct uio_device	*uio_dev;
	const char		*name;
	const char		*version;
	struct uio_mem		mem[MAX_UIO_MAPS];
	struct uio_port		port[MAX_UIO_PORT_REGIONS];
	long			irq;
	unsigned long		irq_flags;
	void			*priv;
	irqreturn_t (*handler)(int irq, struct uio_info *dev_info);
	int (*mmap)(struct uio_info *info, struct vm_area_struct *vma);
	int (*open)(struct uio_info *info, struct inode *inode);
	int (*release)(struct uio_info *info, struct inode *inode);
	int (*irqcontrol)(struct uio_info *info, s32 irq_on);
};
```

在模块探测时创建一个新的结构体，设置 `name`, `version`, 中断号（IRQ）、中断处理回调（`handler`）等。并使用 `register_device(struct device *parent, struct uio_info *info)` 注册设备。这个函数会创建一个 `uio_dev` 填充到这个结构体内，它的声明如下：

```c
struct uio_device {
        struct module           *owner;
        struct device           *dev;
        int                     minor;
        atomic_t                event;
        struct fasync_struct    *async_queue;
        wait_queue_head_t       wait;
        struct uio_info         *info;
        struct kobject          *map_dir;
        struct kobject          *portio_dir;
};
```

对于需要映射的内存区域，则需要填充 `mem` 这个成员，最多可以映射 `MAX_UIO_MAPS` 个（在 4.3 版本的内核中是 5 个。UIO 内存区域的结构体如下：

```c
struct uio_mem {
	const char		*name;
	phys_addr_t		addr;
	resource_size_t		size;
	int			memtype;
	void __iomem		*internal_addr;
	struct uio_map		*map;
};
```

而使用这个函数可以生成一个 UIO 的中断事件：

```c
extern void uio_event_notify(struct uio_info *info);
```

其余的结构体和声明都可以在头文件中找到：

```c
struct uio_map;
struct uio_port;
struct uio_portio;
extern void uio_unregister_device(struct uio_info *info);
```

更多细节可以查看文档或源码。

## 性能

在使用内核态设备的时候，使用 ioctl 进行设备控制并不是直接的，这个系统调用会使用虚拟文件系统（VFS）分发用户传来的控制值到设备，如果有返回值，也会逐层传回。而 UIO 中这样的操作是通过 mmap 映射设备内存来实现的，因此读写寄存器来控制设备是直接写入设备的，代码实现就是访问一个普通的数组，这让 UIO 对应的用户态驱动更快、且更易读。

而中断方面，文章[1]测试了 `uio_event_notify` 被调用到读取 UIO 设备返回的时间在 16 到 32 毫秒左右，ARM11 设备上使用 90% 的 CPU 占用能够完成每秒 1000 次的中断，这在带有实时限制的嵌入式设备中也是可接受的。

## 总结

使用 UIO 框架写入的内核部分的驱动可以非常小和容易维护，因此想在主线内核中审阅和包含这个驱动不是很难的事情。而 UIO 会避免用户态去映射不属于这个设备的内存，因此也是相当安全的。

# VFIO

TBC

# 参考

1. Userspace I/O drivers in a realtime context, https://www.osadl.org/fileadmin/dam/rtlws/12/Koch.pdf
