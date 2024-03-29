---
title: 【译】解锁摩托罗拉的引导程序
date: 2023-04-25 11:20:00
tags:
- Android
- ABL
- Linux
- Bootloader
- 中文
categories:
- [Linux, Android, Bootloader]
---

在[本篇博客](http://bits-please.blogspot.com/2016/02/unlocking-motorola-bootloader.html)中，我们将探讨最近高通骁龙设备上的摩托罗拉引导程序。我们的目标是使用上一篇博客中的 TrustZone 内核代码执行漏洞，解锁 Moto X（第二代）的引导程序。请注意，虽然我们将展示特定设备的完整解锁过程，但它应该足够通用，至少适用于大多数现代摩托罗拉设备。

# 为什么是摩托罗拉？

在向高通报告上一个 TrustZone 内核特权升级后，他们送了我一部全新的 Moto X。然而...有一个小问题-他们不小心把一个锁定的设备送给了我。这是一个完全诚实的错误，他们确实多次提供解锁设备的服务-但这有什么乐趣呢？因此，让我们深入摩托罗拉的引导程序，看看解锁它需要什么。

# 铺垫

在我们开始研究之前，让我们先简单介绍引导过程，从设备通电开始。

首先，执行 PBL（主引导程序），也称为“BootROM”。由于 PBL 存储在内部 ROM 中，因此无法修改或分配，因此它是设备的固有部分。因此，它只能实现让设备引导，并验证和加载引导链的下一部分的最小要求。

然后，加载两个次要引导程序，SBL1（次级引导程序），然后是 SBL2。它们的主要职责是启动 SoC 上的各种处理器并配置它们，使其准备好操作。

引导链的下一步是加载第三个也是最后一个次级引导程序，SBL3。这个引导程序除了其他任务外，还验证并加载 Android Bootloader-"aboot"。

现在这就是我们与解锁相关的部分了；Android Bootloader 是负责加载 Android 操作系统并触发其执行的软件部件。

这也是 OEM 的引导链部分，主要是因为在引导链的第一部分由 Qualcomm 编写并处理 SoC 特定内容的同时，Android bootloader 可用于配置加载 Android OS 的方式。

由 aboot 控制的功能之一是“引导加载程序锁定”-换句话说，aboot 是引导链中第一个可以选择打破信任链（每个引导程序阶段都验证下一个）并加载未签名操作系统的部件。

对于可解锁引导程序的设备，解锁过程通常通过将设备重新启动到特殊的（“引导程序”）模式，并发出相关的快速引导命令来执行。然而，正如我们将在后面看到的，此接口也由 aboot 处理。这意味着 aboot 不仅在常规引导过程中查询锁定状态，而且还拥有负责实际解锁过程的代码。

你可能知道，不同的 OEM 在这个问题上有不同的立场。简单来说，“Nexus”设备始终带有“可解锁”的引导加载程序。相比之下，三星不允许大多数设备的引导加载程序解锁。其他 OEM，包括摩托罗拉，会锁定他们的设备，但某些被视为“合格”的设备可以使用 OEM 提供的“魔法”（签名）令牌进行解锁（尽管这也会使大多数设备的保修失效）。

所以...这一切都非常复杂，但也不重要。因为我们将手动完成整个过程——如果 aboot 可以控制设备的锁定状态，那么这意味着我们应该也能够在提升了足够的特权级别后完成解锁过程。

现在，我们已经对涉及的组件和目标有了一个总体了解，下一步是分析实际的 aboot 代码。

# 起点

由于所有引导链各阶段的二进制文件都包含在出厂固件映像中，因此这自然是一个好的起点。有几个下载链接可用 - 这里是一些。如果您想跟随我进行操作，我将引用版本“ATT_XT1097_4.4.4_KXE21.187-38”中的符号。

下载固件映像后，我们面临着第一个挑战 - 所有映像都使用专有格式打包在名为“motoboot.img”的文件中。但是，在十六进制编辑器中打开文件会显示它具有一个我们可以推断出的相当简单的格式：

![](https://2.bp.blogspot.com/-_02hOx5UGLE/VqVugCVVtKI/AAAAAAAADNI/1yYZAgxIpPo/s640/Screenshot%2Bfrom%2B2016-01-25%2B02%253A38%253A06.png)

正如上面所述，所需的 aboot 映像存储在该文件中，该文件还包括 TrustZone 映像和各种启动链阶段。好的。

经过上面的结构分析，我编写了一个 Python 脚本，可以用于从给定的 Motorola 引导加载程序映像中解压缩所有映像，你可以在[这里](https://github.com/laginimaineb/unpack_motoboot/blob/master/unpack_motoboot.py)找到它。

# 无关紧要的事情

我们将从检查 aboot 映像开始。令人沮丧的是，它的大小为 1MB，所以完全检查它是浪费时间。然而，正如我们上面所提到的，当将设备引导到特殊的“引导加载程序”模式时，实际与用户交互的是 aboot 本身。这意味着我们可以从搜索开始执行解锁过程后显示的字符串-并从那里继续。

短暂地搜索“unlock…”字符串（在启动解锁过程后打印），将我们直接带到处理解锁逻辑的函数（@0xFF4B874）：

![](https://3.bp.blogspot.com/-iaif1sGbQro/Vrp2FKzHP9I/AAAAAAAADRE/cGZj_dy8Hiw/s1600/Screenshot%2Bfrom%2B2016-02-10%2B01%253A28%253A06.png)

正如你所看到的，打印完字符串到控制台之后，连续调用了三个函数，如果它们都成功，则认为设备已经解锁。

仔细研究后两个函数的作用，我们可以发现它们的目的是擦除用户数据分区（在解锁引导程序后总是会执行，以保护设备所有者的隐私）。不管怎样，这意味着它们与解锁过程本身无关，只是附带效果。

这让我们剩下一个单独的函数，调用它应该可以解锁引导程序。

那么这是否意味着我们已经完成了？我们可以直接调用这个函数来解锁设备吗？

实际上，还没有。尽管 TrustZone 漏洞允许我们在 TrustZone 内核中实现代码执行，但这只是在操作系统加载后完成的，此时直接执行引导程序代码可能会引起各种副作用（例如，代码可能假定没有操作系统/ MMU 可能被禁用等）。而且即使真的很简单，也可能通过完全理解锁定机制本身来学习一些有趣的东西。

无论如何，如果我们可以理解代码背后的逻辑，我们可以简单地模拟它，从我们的 TrustZone 漏洞中执行其有意义的部分。分析解锁函数揭示了一个令人惊讶的简单的高级逻辑：

![](https://4.bp.blogspot.com/-ZZ614Z86psk/Vrp4cXmFu8I/AAAAAAAADRU/jgZmj18XlQE/s1600/Screenshot%2Bfrom%2B2016-02-10%2B01%253A37%253A55.png)

很遗憾，这两个函数会在 IDA 中造成严重后果（它甚至无法为它们显示一个有意义的调用图）。

手动分析这些函数发现它们实际上非常相似。它们都没有太多的逻辑，而是准备参数并调用以下函数：

![](https://4.bp.blogspot.com/-J3MaZuCJ1NA/Vrs1WpGr6QI/AAAAAAAADTI/HrMWr9vqWq4/s1600/Screenshot%2Bfrom%2B2016-02-10%2B15%253A04%253A00.png)

这有点令人惊讶 - 这个函数并没有处理逻辑本身，而是通过 SMC（Supervisor Mode Call）来调用一个 TrustZone 系统调用，从而在 aboot 本身中调用它！（正如我们在先前的博客文章中讨论的那样）。在这种情况下，这两个函数都使用请求代码 0x3F801 发出 SMC。以下是每个函数的相关伪代码：

![](https://2.bp.blogspot.com/-zKRDB4xThs4/Vrs9hihpYgI/AAAAAAAADTc/WPXXIHK-mYU/s1600/Screenshot%2Bfrom%2B2016-02-10%2B15%253A39%253A04.png)

很好，我们现在已经从 aboot 中获取了所有需要的信息，现在让我们切换到 TrustZone 内核，找出这个 SMC 调用的作用。

# 请进 TrustZone

现在我们已经确认了使用命令代码 0x3F801 发出 SMC 调用，我们需要找到这个命令在 TrustZone 内核中的位置。

浏览TrustZone内核系统调用时，我们找到了以下入口：

![](https://1.bp.blogspot.com/-FxCt_WSmSy0/VrqBJ54cqVI/AAAAAAAADSA/BuD0JUp6DsE/s1600/Screenshot%2Bfrom%2B2016-02-10%2B02%253A15%253A25.png)

这是一个非常庞大的函数，根据提供的第一个参数执行各种不同的任务，我们从现在开始将其称为“命令代码”。

需要注意的是，还传递了一个附加标志到这个系统调用中，用于指示它是否从“安全”上下文中调用。这意味着如果我们尝试从 Android OS 本身调用它，将传递一个标记来标记我们的调用是不安全的，并且将阻止我们自己执行这些操作。当然，我们可以使用我们的 TrustZone 漏洞绕过此限制，但我们稍后再详细说明！

如上所述，使用命令代码＃1和＃2触发了这两次 SMC 调用（我已经注释了下面的函数以提高可读性）：

![](https://4.bp.blogspot.com/-BTcp6s9seYY/VrqCyxQh0zI/AAAAAAAADSM/b8kvtdhRSYo/s1600/Screenshot%2Bfrom%2B2016-02-10%2B02%253A22%253A02.png)

简单来说，我们可以看到这两个命令都用于读取和写入（分别）来自称为“QFuse”的内容。

# QFuses

就像现实中的保险丝一样，QFuse 是一种硬件组件，用于实现“一次可写”的内存。每个保险丝表示一个位；未受损的保险丝表示位零，“烧断”的保险丝表示位一。但是，正如其名称所示，此操作是不可逆的 - 一旦保险丝被“烧断”，它就无法“未烧断”。

每个 SoC 都有自己的 QFuse 布置，每个都具有自己独特的目的。某些保险丝在设备出货时已经烧断，但其他保险丝可能会根据用户的操作而被烧断，以更改特定设备功能的方式。

不幸的是，关于每个保险丝的作用的信息不是公开的，因此我们只能反向分析各种软件组件，以尝试推断它们的作用。

在我们的情况下，我们调用特定的函数来决定要读取和写入的保险丝：

![](https://3.bp.blogspot.com/-ycbi4Npm5_U/VrtY4u2HUeI/AAAAAAAADT0/Ql51VN30f-0/s1600/Screenshot%2Bfrom%2B2016-02-10%2B17%253A35%253A55.png)

既然我们使用第二个系统调用参数（在我们的情况下为“4”）来调用此函数，这意味着我们将操作地址为 0xFC4B86E8 的 QFuse。

# 把所有的东西放在一起

现在我们了解了 aboot 和 TrustZone 逻辑，我们可以将它们结合起来得到完整的流程：

- 首先，aboot 调用 SMC 0x3F801，并使用命令码＃1，这会导致 TrustZone 内核读取并返回地址 0xFC4B86E8 处的 QFuse。
- 然后，仅当 QFuse 中的第一个位被禁用时，aboot 再次调用 SMC 0x3F801，这次使用命令码＃2，这会导致 TrustZone 内核将值 1 写入上述 QFuse 的 LSB。

结果证明，一切都很简单 - 我们只需要设置单个 QFuse 中的一个位，引导加载程序就会被视为解锁。

但是如何编写 QFuses？

# DIY QFuses

幸运的是，TrustZone 内核暴露了一对系统调用，允许我们读取和写入受限制的一组 QFuse - 分别为 tzbsp_qfprom_read_row 和 tzbsp_qfprom_write_row。如果我们可以利用我们的 TrustZone 漏洞解除这些限制，我们应该能够使用此 API 来创造想要的 QFuse。

让我们看看 tzbsp_qfprom_write_row 系统调用中的这些限制：

![](https://2.bp.blogspot.com/-4Z9P8cCNz6A/VruECONo54I/AAAAAAAADUE/lJMu3ZJ1fug/s1600/Screenshot%2Bfrom%2B2016-02-10%2B20%253A38%253A55.png)

因此，首先必须将地址 0xFE823D5C 处的 DWORD 设置为 0，才能继续执行函数的逻辑。通常情况下，此标志实际上设置为 1，从而防止使用 QFuse 调用，但是我们可以使用 TrustZone 漏洞轻松地覆盖该标志。

然后，还有一个附加函数被调用，用于确保被写入的保险丝范围是“允许”的：

![](https://1.bp.blogspot.com/-dkMMgqwbsx8/VruFK6Qdg2I/AAAAAAAADUM/Yv6INnWKFYQ/s1600/Screenshot%2Bfrom%2B2016-02-10%2B20%253A44%253A52.png)

正如我们所看到的，这个函数遍历了一个静态列表，其中每个元素都表示允许的 QFuse 的起始地址和结束地址。这意味着为了通过这个检查，我们可以覆盖这个静态列表，将所有 QFuse 包括进去（将起始地址设置为零，将结束地址设置为最大的 QFuse 相对地址 - 0xFFFF）。

# 尝试一下

既然我们已经弄清楚了一切，现在是时候自己试试了！我写了一些代码，实现了以下功能：

- 在 TrustZone 中实现代码执行
- 禁用 QFuse 保护
- 在 QFuse 0xFC4B86E8 中写入 LSB QFuse

在这里查看代码：https://github.com/laginimaineb/Alohamora

![](https://4.bp.blogspot.com/-eBN8JdbJFX0/VruJuPiQMuI/AAAAAAAADUc/qQMZ3Z1lTc0/s400/motox_unlocked.png)

# 最后想法

在本博客文章中，我们介绍了由单个 QFuse 控制的流程。但是，您可能可以猜到，还有许多不同的有趣 QFuse 正在等待被发现。

一方面，烧断保险丝确实很“危险” - 一旦出现小错误，就会永久砖化设备。另一方面，一些保险丝可能会促进一组特殊功能，我们希望启用这些功能。

一个这样的例子是“工程”保险丝；此保险丝在整个 aboot 映像中都有提到，可以用于启用令人惊叹的功能，例如跳过安全启动、加载未签名的外围映像、拥有未签名的 GPT 等等。

![](https://3.bp.blogspot.com/-h9yEGl7JbT0/VruPJk8GcMI/AAAAAAAADUs/MG2C5E6Pycc/s1600/Screenshot%2Bfrom%2B2016-02-10%2B21%253A10%253A39.png)

然而，此保险丝在所有消费设备上都已经烧断，标记设备为“非工程师”设备，并禁用这些功能。但是谁知道，也许还有其他同样重要的保险丝尚未被发现...
