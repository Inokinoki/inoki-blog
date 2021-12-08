---
title: 【译】Linux 内核的用户态 I/O
date: 2021-12-08 19:34:00
tags:
- Linux
- 翻译
- 中文
categories:
- [Linux]
---

原文链接：[The Userspace I/O HOWTO](https://www.kernel.org/doc/html/latest/driver-api/uio-howto.html)


# 关于 UIO

如果你使用 UIO 作为你的设备卡的驱动程序，你可以获得：

- 只有一个小的内核模块需要编写和维护。
- 在用户空间开发你的驱动程序的主要部分，使用你习惯的所有工具和库。
- 驱动程序中的错误不会使内核崩溃。
- 你的驱动程序的更新可以在不重新编译内核的情况下进行。

## UIO 是如何工作的

每个 IO 设备都是通过一个设备文件和几个 sysfs 属性文件访问的。第一个设备的设备文件将被称为 `/dev/uio0`，随后的设备将被称为 `/dev/uio1`，`/dev/uio2`，以此类推。

`/dev/uioX` 是用来访问设备卡的地址空间。只需使用 `mmap()` 来访问你的设备卡的寄存器或 RAM 位置。

中断是通过从 `/dev/uioX` 读取来处理的。从 `/dev/uioX` 读取的阻塞式 `read()` 将在中断发生后立即返回。你也可以在 `/dev/uioX` 上使用 `select()` 来等待一个中断。从 `/dev/uioX` 中读出的整数值代表总的中断数。你可以用这个数字来计算你是否错过了一些中断。

对于一些内部有多个中断源，但没有独立的 IRQ 屏蔽和状态寄存器的硬件，可能会出现这样的情况：如果内核处理程序通过写入芯片的 IRQ 寄存器来禁用它们，用户空间无法确定中断源是什么。在这种情况下，内核必须完全禁用 IRQ，以使芯片的寄存器不被改变。现在，用户空间部分可以确定中断的原因，但它不能重新启用中断。另一种情况是，重新启用中断的芯片是对综合的 IRQ 状态/确认寄存器的读-修改-写操作。如果一个新的中断同时发生，这将是很荒谬的。

为了解决这些问题，UIO 还实现了一个 `write()` 函数。对于只有一个中断源或者有独立的IRQ屏蔽和状态寄存器的硬件，通常不使用、可以忽略它。然而，如果你需要它，对 `/dev/uioX` 的写入将调用驱动实现的 `irqcontrol()` 函数。你必须写一个 32 位的值，通常是 0 或 1，以禁用或启用中断。如果一个驱动程序没有实现 `irqcontrol()`，`write()` 将返回 `-ENOSYS`。

为了正确处理中断，你的自定义内核模块可以提供自己的中断处理程序。它将自动被内置的处理程序调用。

对于那些不产生中断但需要轮询的卡，可以设置一个定时器，在可配置的时间间隔内触发中断处理程序。这种中断模拟是通过从定时器的事件处理程序调用 `uio_event_notify()` 来完成的。

每个驱动程序都提供了用于读取或写入变量的属性。这些属性可以通过 sysfs 文件访问。一个自定义的内核驱动模块可以将自己的属性添加到 uio 驱动所拥有的设备上，但目前还没有添加到 uio 设备本身。如果发现有用的话，这在将来可能会发生改变。


UIO框架提供了以下标准属性：

- name: 你的设备的名称。建议使用你的内核模块的名称。
- version：一个由你的驱动程序定义的版本字符串。这使得你的驱动程序的用户空间部分能够处理不同版本的内核模块。
- event：自上次读取设备节点以来，驱动程序处理的中断总数。

这些属性出现在 `/sys/class/uio/uioX` 目录下。请注意，这个目录可能是一个符号链接，而不是一个真正的目录。任何访问它的用户空间代码必须能够处理这个问题。

每个 UIO 设备都可以为**内存映射提供一个或多个内存区域**。这是必要的，因为一些工业 I/O 卡需要在一个驱动程序中访问一个以上的 PCI 内存区域。

每个映射在 sysfs 中有自己的目录，第一个映射显示为 `/sys/class/uio/uioX/maps/map0/`。 后续的映射创建目录 map1/，map2/，等等。这些目录只有在映射的大小不为 0 时才会出现。

每个 mapX/ 目录包含四个只读文件，显示内存的属性：

- name: 这个映射的一个字符串标识符。这是可选的，这个字符串可以是空的。驱动程序可以设置它，使用户空间更容易找到正确的映射。
- addr: 可以被映射的内存的地址。
- size：addr 所指向的内存的大小，以字节为单位。
- offset：在 `mmap()` 返回的指针上必须加上的偏移量，以获得实际的设备内存。如果设备的内存不是页对齐的，这就很重要。记住，由 `mmap()` 返回的指针总是页对齐的，所以总是加上这个偏移量是好的风格。

在用户空间，不同的映射是通过调整 `mmap()` 调用的偏移量参数来区分的。为了映射 N 的内存，你必须使用 N 倍的页面大小作为你的偏移：

```
offset = N * getpagesize();
```

Sometimes there is hardware with memory-like regions that can not be mapped with the technique described here, but there are still ways to access them from userspace. The most common example are x86 ioports. On x86 systems, userspace can access these ioports using ioperm(), iopl(), inb(), outb(), and similar functions.

Since these ioport regions can not be mapped, they will not appear under /sys/class/uio/uioX/maps/ like the normal memory described above. Without information about the port regions a hardware has to offer, it becomes difficult for the userspace part of the driver to find out which ports belong to which UIO device.

To address this situation, the new directory /sys/class/uio/uioX/portio/ was added. It only exists if the driver wants to pass information about one or more port regions to userspace. If that is the case, subdirectories named port0, port1, and so on, will appear underneath /sys/class/uio/uioX/portio/.

有时，有些硬件的类似内存的区域不能用这里描述的技术进行映射，但仍有办法从用户空间访问它们。最常见的例子是 x86 的 ioports。在X86系统中，用户空间可以使用 `ioperm()`、`iopl()`、`inb()`、`outb()` 和类似的函数访问这些 ioports。

由于这些 ioport 区域不能被映射，它们不会像上面描述的普通内存一样出现在 `/sys/class/uio/uioX/maps/` 下。如果没有硬件所提供的端口区域的信息，驱动程序的用户空间部分就很难找出哪些端口属于哪个 IO 设备。

为了解决这种情况，增加了新的目录 `/sys/class/uio/uioX/portio/`。它只在驱动想把一个或多个端口区域的信息传递给用户空间时存在。如果是这种情况，名为 port0、port1 等的子目录将出现在 `/sys/class/uio/uioX/portio/` 下面。

每个 portX/ 目录包含四个只读文件，它们显示端口区域的名称、开始、大小和类型：

- name：这个端口区域的一个字符串标识符。这个字符串是可选的，可以为空。驱动程序可以设置它，使用户空间更容易找到某个端口区域。
- start：该区域的第一个端口。
- size：这个区域中的端口数量。
- porttype：一个描述端口类型的字符串。

# 编写你自己的内核模块

请看一下 `uio_cif.c` 作为一个例子。下面的段落解释了这个文件的不同部分。

## struct uio_info

这个结构告诉框架你的驱动程序的细节，有些成员是必须的，有些是可选的。

- `const char *name`: 需要。你的驱动程序的名称，它将出现在 sysfs 中。我建议使用你的模块的名称。
- `const char *version`: 必须，这个字符串会显示在 `/sys/class/uio/uioX/version`。
- `struct uio_mem mem[ MAX_UIO_MAPS ]`: 如果你有可以用 `mmap()` 映射的内存，则需要。对于每个映射，你需要填充一个 `uio_mem` 结构。详情见下面的描述。
- `struct uio_port port[ MAX_UIO_PORTS_REGIONS ]`: 如果你想把 ioports 的信息传递给用户空间，就必须这样做。对于每个端口区域，你需要填充一个 `uio_port` 结构。详情见下面的描述。
- `long irq`: 需要。如果你的硬件产生了一个中断，你的模块的任务就是在初始化过程中确定 irq 的编号。如果你没有硬件产生的中断，但想以其他方式触发中断处理程序，请将 irq 设置为  `UIO_IRQ_CUSTOM`。如果你根本就没有中断，你可以把 irq 设置为 `UIO_IRQ_NONE`，尽管这很少有意义。
- `unsigned long irq_flags`: 如果你将 irq 设置为硬件中断号，则需要。这里给出的标志将在调用 `require_irq()` 时使用。
- `int (*mmap)(struct uio_info *info, struct vm_area_struct *vma)`: 可选的。如果你需要一个特殊的`mmap()`函数，你可以在这里设置它。如果这个指针不是 NULL，你的 `mmap()` 将被调用，而不是内置的那个。
- `int (*open)(struct uio_info *info, struct inode *inode)`: 可选的。你可能希望有自己的`open()`，例如，只有当你的设备被实际使用时才启用中断。
- `int (*release)(struct uio_info *info, struct inode *inode)`: 可选的。如果你定义了自己的`open()`，你可能也需要一个自定义的 `release()` 函数。
- `int (*irqcontrol)(struct uio_info *info, s32 irq_on)`: 可选的。如果你需要通过写到 `/dev/uioX` 来启用或禁用用户空间的中断，你可以实现这个函数。参数 `irq_on` 为 0 表示禁用中断，1 表示启用中断。

通常，你的设备会有一个或多个内存区域可以被映射到用户空间。对于每个区域，你必须在 `mem[]` 数组中设置一个 `struct uio_mem`。下面是对 `struct uio_mem` 字段的描述。

- `const char *name`: 可选的。设置它以帮助识别内存区域，它将显示在相应的 sysfs 节点中。
- `int memtype`: 如果使用映射，则需要。如果你的卡上有要映射的物理内存，将其设置为  `UIO_MEM_PHYS`。如果是逻辑内存(例如用 `__get_free_pages()` 分配，而不是 `kmalloc()`)，则使用 `UIO_MEM_LOGICAL`。还有 `UIO_MEM_VIRTUAL` 用于虚拟内存。
- `phys_addr_t addr`: 如果使用映射则需要。填入你的内存块的地址。这个地址会出现在 sysfs 中。
- `resource_size_t size`: 填写 addr 指向的内存块的大小。如果 size 为 0，则认为该映射未被使用。注意你必须为所有未使用的映射初始化 size 为 0。
- `void *internal_addr`: 如果你必须从你的内核模块中访问这个内存区域，你将希望通过使用类似 `ioremap()` 的方法来进行内部映射。这个函数返回的地址不能被映射到用户空间，所以你不能把它存储在 addr 中。使用 `internal_addr` 来记住这样一个地址。

请不要碰 `uio_mem` 结构的 map 元素!它是由 UIO 框架用来为这个映射设置 sysfs 文件的。不要管它。

有时，你的设备可能有一个或多个端口区域不能被映射到用户空间。但如果用户空间有其他的可能性来访问这些端口，那么在 sysfs 中提供这些端口的信息是有意义的。对于每个区域，你必须在 `port[]` 数组中设置一个 `struct uio_port`。下面是对 `struct uio_port` 的字段的描述。

- `char *porttype`：需要。将其设置为预定义的常数之一。使用 `UIO_PORT_X86` 来表示 x86 架构中的 ioports。
- `unsigned long start`: 如果使用端口区域，则需要。填写这个区域的第一个端口的编号。
- `unsigned long size`: 填入该区域的端口数。如果 size 为 0，该区域将被视为未使用。注意，你必须为所有未使用的区域初始化 size 为 0。

请不要碰 `uio_port` 结构的 `portio` 元素! 它是由 UIO 框架内部使用的，用于为这个区域设置 sysfs 文件。请不要管它。

## 添加一个中断处理程序

你需要在中断处理程序中做什么取决于你的硬件和你想如何处理它。你应该尽量减少内核中断处理程序中的代码量。如果你的硬件不需要在每次中断后执行任何操作，那么你的处理程序可以是空的。

另一方面，如果你的硬件需要在每次中断后执行一些动作，那么你必须在你的内核模块中完成这些动作。注意，你不能依赖你的驱动程序的用户空间部分。你的用户空间程序可以在任何时候终止，可能会让你的硬件处于仍然需要正确处理中断的状态。

也可能有这样的应用，你想在每次中断时从硬件中读取数据，并将其缓冲在你为此目的分配的一块内核内存中。通过这种技术，你可以避免在用户空间程序错过中断时的数据丢失。

关于共享中断的说明：只要有可能，你的驱动程序应该支持中断共享。只有当你的驱动程序能够检测到你的硬件是否触发了中断时，它才有可能。这通常是通过查看一个中断状态寄存器来实现的。如果你的驱动程序看到 IRQ 位确实被设置了，它将执行其动作，处理程序返回 `IRQ_HANDLED`。如果驱动程序检测到不是你的硬件引起的中断，它将什么也不做，并返回 `IRQ_NONE`，允许内核调用下一个可能的中断处理程序。

如果你决定不支持共享中断，你的卡就不能在没有空闲中断的计算机中工作。由于这种情况经常发生在 PC 平台上，你可以通过支持中断共享来为自己省去很多麻烦。

## 为平台设备使用 `uio_pdrv`

在许多情况下，平台设备的 IO 驱动可以用一种通用的方式来处理。在你定义 `platform_device` 结构的同一个地方，你也可以简单地实现你的中断处理程序并填充你的 `uio_info` 结构。然后，这个结构 `uio_info` 的指针被用作你的平台设备的 `platform_data`。

你还需要设置一个包含内存映射地址和大小的结构资源数组。这些信息使用 `struct platform_device` 的 `.resource` 和 `.num_resources` 元素传递给驱动。

你现在必须将 `struct platform_device` 的 `.name` 元素设置为 "uio_pdrv "以使用通用的 IO 平台设备驱动程序。这个驱动程序将根据给定的资源填充 `mem[]` 数组，并注册该设备。

这种方法的优点是，你只需要编辑一个你无论如何都需要编辑的文件。你不需要创建一个额外的驱动程序。

## 为平台设备使用 `uio_pdrv_genirq`

特别是在嵌入式设备中，你经常会发现一些芯片的 irq 引脚被绑在自己的专用中断线上。在这种情况下，你可以非常确定中断不是共享的，我们可以进一步利用 `uio_pdrv` 的概念，使用一个通用的中断处理器。这就是 `uio_pdrv_genirq` 的作用。

这个驱动程序的设置与上面描述的 `uio_pdrv` 相同，只是你没有实现一个中断处理程序。 `uio_info` 结构中的 `.handler` 元素必须保持为空。`.irq_flags` 元素必须不包含 `IRQF_SHARED`。

你将把 `struct platform_device` 的 `.name` 元素设置为 "uio_pdrv_genirq" 来使用这个驱动程序。

`uio_pdrv_genirq` 的通用中断处理程序将简单地使用 `disable_irq_nosync()` 禁用中断线。在完成它的工作后，用户空间可以通过向 IO 设备文件写入 `0x00000001` 来重新启用中断。驱动程序已经实现了一个 `irq_control()` 来实现这个功能，你必须不实现自己的。

使用 `uio_pdrv_genirq` 不仅可以节省几行中断处理程序的代码。你也不需要知道任何关于芯片内部寄存器的信息来创建驱动的内核部分。你只需要知道芯片所连接的引脚的IRQ号码。

当在一个启用了设备树的系统中使用时，需要用 "of_id "模块参数来探测驱动程序应该处理的节点的"兼容"字符串。默认情况下，节点的名称（不包括单元地址）被暴露为用户空间中的 IO 设备的名称。要设置一个自定义的名称，可以在 `DT` 节点中指定一个名为 "linux,uio-name" 的属性。

## 为平台设备使用 `uio_dmem_genirq`

除了静态分配的内存范围之外，他们也可能希望在用户空间驱动中使用动态分配的区域。特别是，能够访问通过 `dma-mapping` API 提供的内存，可能特别有用。`uio_dmem_genirq` 驱动提供了一种方法来实现这一目标。

在中断配置和处理方面，该驱动的使用方式与 "uio_pdrv_genirq" 驱动类似。

将 `struct platform_device` 的 `.name` 元素设置为 "uio_dmem_genirq "来使用这个驱动。

当使用这个驱动时，填写 `struct platform_device` 的 `.platform_data` 元素，它的类型是 `struct uio_dmem_genirq_pdata`，它包含以下元素：

- `struct uio_info uioinfo`：与 `uio_pdrv_genirq` 平台数据使用的结构相同
- `unsigned int *dynamic_region_sizes`:指向将被映射到用户空间的动态内存区域大小列表的指针。
- `unsigned int num_dynamic_regions`:`dynamic_region_sizes` 数组中的元素数量。

在平台数据中定义的动态区域将被附加到平台设备资源之后的 "mem[]" 数组中，这意味着静态和动态内存区域的总数不能超过 `MAX_UIO_MAPS`。

动态内存区域将在打开 UIO 设备文件 `/dev/uioX` 时被分配。类似于静态内存资源，动态区域的内存区域信息然后通过 sysfs 在 `/sys/class/uio/uioX/maps/mapY/*` 处可见。当 IO 设备文件被关闭时，动态内存区域将被释放。当没有进程保持设备文件开放时，返回给用户空间的地址是 ~0。

# 在用户态编写一个驱动

一旦你有一个适用于你的硬件的内核模块，你就可以编写你的驱动程序的用户空间部分。你不需要任何特殊的库，你的驱动程序可以用任何合理的语言编写，你可以使用浮点数字等等。简而言之，你可以使用所有你通常用于编写用户空间应用程序的工具和库。

## 获取有关你的 UIO 设备的信息

所有 IO 设备的信息都可以在 sysfs 中找到。你应该在你的驱动程序中做的第一件事是检查名称和版本，以确保你与正确的设备对话，并且其内核驱动程序具有你期望的版本。

你还应该确保你需要的内存映射存在，并且有你期望的大小。

有一个叫 `lsuio` 的工具，可以列出 IO 设备和它们的属性。它可以在这里找到。

http://www.osadl.org/projects/downloads/UIO/user/

用 `lsuio` 你可以快速检查你的内核模块是否被加载，以及它输出了哪些属性。详情请看 `manpage`。

`lsuio` 的源代码可以作为一个例子，用来获取一个 IO 设备的信息。`uio_helper.c` 文件包含了很多函数，你可以在你的用户空间驱动代码中使用。

## `mmap()` 设备内存

在你确定你已经得到了正确的设备和你需要的内存映射之后，你要做的就是调用 `mmap()` 将设备的内存映射到用户空间。

`mmap()` 调用的参数 offset 对于 IO 设备有特殊意义。它被用来选择你要映射的设备的映射。要映射N个映射的内存，你必须使用 N 倍的页面大小作为你的偏移量。

```
offset = N * getpagesize()。
```

N 从 0 开始，所以如果你只有一个内存范围要映射，就设置 `offset = 0`。这种技术的缺点是，内存总是从它的起始地址开始映射。

## 等待中断

在你成功地映射了你的设备内存后，你可以像普通的数组一样访问它。通常情况下，你会进行一些初始化。之后，你的硬件开始工作，一旦完成，有一些数据可用，或者因为发生错误而需要你的注意，就会产生一个中断。

`/dev/uioX` 是一个只读文件。`read()` 将总是阻塞，直到中断发生。`read()` 的 count 参数只有一个合法的值，那就是一个有符号的32位整数的大小(4)。任何其他的 count 值都会导致 `read()` 失败。读取的有符号的 32 位整数是你设备的中断计数。如果这个值比你上次读到的值多一个，则一切正常。如果差值大于 1，你就错过了中断。

你也可以在 `/dev/uioX` 上使用 `select()`。

# 通用的 PCI UIO 驱动

通用驱动程序是一个名为 `uio_pci_generic` 的内核模块。它可以与任何符合 PCI 2.3（2002 年左右）的设备和任何符合 PCI Express 的设备一起工作。使用它，你只需要编写用户空间驱动程序，而不需要编写特定硬件的内核模块。

## 让驱动识别设备

由于驱动程序没有声明任何设备 ID，它不会被自动加载，也不会自动与任何设备绑定，你必须自己加载它并分配 ID 给驱动程序。比如说：

```
modprobe uio_pci_generic
echo "8086 10f5" > /sys/bus/pci/drivers/uio_pci_generic/new_id
```

如果你的设备已经有一个特定硬件的内核驱动，通用驱动仍然不会与之绑定，在这种情况下，如果你想使用通用驱动（为什么要这样做？），你必须手动解除与特定硬件驱动的绑定，然后绑定通用驱动，像这样。

```
echo -n 0000:00:19.0 > /sys/bus/pci/drivers/e1000e/unbind
echo -n 0000:00:19.0 > /sys/bus/pci/drivers/uio_pci_generic/bind
```

你可以通过在 sysfs 中寻找设备来验证它是否已经被绑定到了驱动程序上，例如:

```
ls -l /sys/bus/pci/devices/0000:00:19.0/driver
```

如果成功的话，应该可以打印出来：

```
.../0000:00:19.0/driver -> ../../../bus/pci/drivers/uio_pci_generic
```

注意，通用驱动程序不会绑定到旧的PCI 2.2设备。如果绑定设备失败，运行下面的命令：

```
dmesg
```

并在输出中寻找失败的原因。

## 关于 `uio_pci_generic` 需要知道的事情

中断是使用 PCI 命令寄存器中的中断禁用位和 PCI 状态寄存器中的中断状态位来处理的。所有符合PCI 2.3（2002 年左右）的设备和所有符合 PCI Express 的设备都应该支持这些位。 `uio_pci_generic` 会检测这种支持，并且不会绑定不支持命令寄存器中中断禁用位的设备。

在每个中断中，`uio_pci_generic` 设置中断禁用位。这将阻止设备产生进一步的中断，直到该位被清除。用户空间驱动程序应该在阻塞和等待更多的中断之前清除这个位。

## 使用 `uio_pci_generic` 编写用户空间驱动程序

用户空间驱动程序可以使用 PCI 的 sysfs 接口，或者包装它的 libpci 库，来与设备对话，并通过向命令寄存器写信来重新启用中断。

## 使用 `uio_pci_generic` 的示例代码

下面是一些使用uio_pci_generic的用户空间驱动代码示例：

```c
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>

int main()
{
    int uiofd;
    int configfd;
    int err;
    int i;
    unsigned icount;
    unsigned char command_high;

    uiofd = open("/dev/uio0", O_RDONLY);
    if (uiofd < 0) {
        perror("uio open:");
        return errno;
    }
    configfd = open("/sys/class/uio/uio0/device/config", O_RDWR);
    if (configfd < 0) {
        perror("config open:");
        return errno;
    }

    /* Read and cache command value */
    err = pread(configfd, &command_high, 1, 5);
    if (err != 1) {
        perror("command config read:");
        return errno;
    }
    command_high &= ~0x4;

    for(i = 0;; ++i) {
        /* Print out a message, for debugging. */
        if (i == 0)
            fprintf(stderr, "Started uio test driver.\n");
        else
            fprintf(stderr, "Interrupts: %d\n", icount);

        /****************************************/
        /* Here we got an interrupt from the
           device. Do something to it. */
        /****************************************/

        /* Re-enable interrupts. */
        err = pwrite(configfd, &command_high, 1, 5);
        if (err != 1) {
            perror("config write:");
            break;
        }

        /* Wait for next interrupt. */
        err = read(uiofd, &icount, 4);
        if (err != 4) {
            perror("uio read:");
            break;
        }

    }
    return errno;
}
```

# 通用的 Hyper-V UIO 驱动

这个通用驱动程序是一个名为 `uio_hv_generic` 的内核模块。它支持 Hyper-V VMBus 上的设备，与 PCI 总线上的 `uio_pci_generic` 类似。

## 让驱动识别设备

由于该驱动没有声明任何设备的 GUID，它不会被自动加载，也不会自动绑定任何设备，你必须自己加载它并分配 ID 给该驱动。例如，使用网络设备类 GUID：

```
modprobe uio_hv_generic
echo "f8615163-df3e-46c5-913f-f2d2f965ed0e" > /sys/bus/vmbus/drivers/uio_hv_generic/new_id
```

如果该设备已经有一个特定硬件的内核驱动，通用驱动仍然不会与之绑定，在这种情况下，如果你想在用户空间库中使用通用驱动，你必须手动解除对特定硬件驱动的绑定，并绑定通用驱动，像这样使用特定设备的 GUID：

```
echo -n ed963694-e847-4b2a-85af-bc9cfc11d6f3 > /sys/bus/vmbus/drivers/hv_netvsc/unbind
echo -n ed963694-e847-4b2a-85af-bc9cfc11d6f3 > /sys/bus/vmbus/drivers/uio_hv_generic/bind
```

你可以通过在sysfs中寻找设备来验证它是否已经被绑定到了驱动程序上，例如，如下所示：

```
ls -l /sys/bus/vmbus/devices/ed963694-e847-4b2a-85af-bc9cfc11d6f3/driver
```

如果成功的话，应该打印出来以下内容：

```
.../ed963694-e847-4b2a-85af-bc9cfc11d6f3/driver -> ../../../bus/vmbus/drivers/uio_hv_generic
```

## 关于 `uio_hv_generic` 需要知道的事

在每个中断中，`uio_hv_generic` 设置中断禁用位。这将阻止设备产生进一步的中断，直到该位被清除。用户空间驱动程序应该在阻塞和等待更多的中断之前清除这个位。

当主机撤销一个设备时，中断文件描述符被标记下来，任何对中断文件描述符的读取将返回 `-EIO`。类似于一个关闭的套接字或断开的串行设备。

**vmbus 设备区域被映射为 uio 设备资源**：

- 通道环形缓冲区：客户机到主机和主机到客户机
- 访客到主机的中断信号页
- 访客到主机的监控页
- 网络接收缓冲区
- 网络发送缓冲区

如果一个子通道是由对主机的请求创建的，那么 `uio_hv_generic` 设备驱动将为每个通道环形缓冲区创建一个 sysfs 二进制文件。比如说

```
/sys/bus/vmbus/devices/3811fe4d-0fa0-4b62-981a-74fc1084c757/channels/21/ring
```

