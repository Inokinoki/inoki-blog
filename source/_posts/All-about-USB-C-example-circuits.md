---
title: 【译】关于 USB-C 的一切：示例电路
date: 2023-09-14 23:42:00
tags:
- 硬件
- USB
- 中文
- 翻译
categories:
- [Translation, Chinese]
- USB
- 硬件
---

原文链接：[https://hackaday.com/2023/08/07/all-about-usb-c-example-circuits/](https://hackaday.com/2023/08/07/all-about-usb-c-example-circuits/)

在上一篇 USB-C 文章发表后的六个月里，我想了很多可以改进这些文章的方法。当然，有这种感觉是正常的，甚至是意料之中的。我现在认为，我可以弥补一些不足。例如，我没有提供足够的电路示例，而有时一张原理图比千言万语能表达的更多。

让我们来解决这个问题！我将为你提供你可能真的想制作的 USB-C 设备的原理图。我还将在本文中分享大量集成电路的零件编号，当然，我并没有详尽无遗地收集所有集成电路。

![USB 2 的 USB-C 电路图](https://hackaday.com/wp-content/uploads/2023/07/hadimg_usbc_reference_1b.png)

我们已经在第一篇文章中看到了第一个示例电路——支持 USB 2.0 和 5V 电源的设备侧（面向上游）USB-C 端口。您必须有 5.1KΩ 电阻器，每个引脚一个电阻器，并记住连接两个数据引脚，必要时使用通孔。如果您想确定可用电流的大小，也可以将 ADC 或比较器一起连接到 CC 引脚上，不过通常情况下，您的设备功耗很低，没有必要这么麻烦。

现在，如果您想制作带有 USB-C 插头的设备，接线方法也是一样的。唯一的区别是，您只需填充一个 CC 下拉引脚，并连接一对 D+/D- 引脚，而不是两对。在实际操作中，如果接上第二对 USB 2.0 引脚，也不会发生什么不好的事情，只是按照标准，这样做很不雅观；它曾经与某种端口和电缆（VirtualLink 电缆）相冲突，但现在已经不再出售了。

不过，如果在两个 CC 引脚上都接上 5.1KΩ 下拉电阻，就能意外地制作出一个黑客配件：调试模式适配器，它能帮助你从某些 USB-C 端口获得额外的信号。例如，在 Framework 笔记本电脑上，配备 USB-C 插头的电路板上的两个下拉引脚会将 USB-C 端口切换到调试模式，并暴露 SBU 引脚上的 Embedded Controller 的 UART 连接。除非您要制作这样的调试配件，否则您只需填充其中一个下拉电阻，并相应地为 USB 2.0 数据引脚布线即可。

# 另一方面也同样简单

如果您想制作一个主机端口呢？从一方面看，这更容易，因为您不一定需要进行任何 ADC 测量。相反，您可以添加上拉电阻，不同的值适用于不同的可用电流。并非所有设备都会检查上拉是否存在，但手机会，所以如果你制作一个临时的 USB-C 充电器，如果没有上拉电阻，手机或笔记本电脑可能无法将其识别为有效的充电方式。添加上拉电阻也不会花很多钱！

![USB 2 的 USB-C 的上拉电阻](https://hackaday.com/wp-content/uploads/2023/07/hadimg_usbc_reference_2.png)

更重要的是，您可能需要控制 VBUS，只有在检测到 CC 引脚之一出现下拉后才将其接通。如果不这样做，不一定会有问题，但它确实涵盖了一些重要的边缘情况，比如有人将 USB-A 转 USB-C 电缆插入你的端口！

我从未做过这种电路，但在我看来，使用两个场效应管就足够了，每个 CC 引脚一个，两个并联。这个电路可能有边缘情况，欢迎改进！另一方面，我曾多次将配备下拉功能的 USB-C 端口断路器用作主机端口，因此这绝对不是硬性要求，而且您也不一定需要动用您的 FET 收藏。

如果要构建主机端口，总共需要做两件事，而这两件事都不太需要。此外，如果你想在电路上做得更复杂一些，或者甚至想做一个双功能端口，也有一些集成电路可以帮助你完成 USB-C 的这一部分！

例如，WUSB3801。它既能检测源极，也能检测漏极，内部有所有需要的上拉和下拉功能，甚至还能实现双功能端口，让您可以构建任何类型的 5 V 电源端口。它可以通过几个 GPIO 输出端口状态，也可以通过 I2C 连接到微控制器，甚至还有一个 ID 引脚，这样就可以用 USB-C 端口完全取代 MicroUSB 端口！WUSB3801 体积小、可焊接，而且用途广泛。例如，在 Hackaday Discord 服务器上，有人制作了一个 WUSB3801 电路，它可以根据所连接的 USB-C 端口是否能提供 3 安培的电流来限制锂离子充电器的电流。

无论您想构建一个源端口、一个汇流端口，甚至是一个可以同时实现这两种功能的端口，WUSB301（或许多类似的集成电路，如 TUSB320）都将是您的理想解决方案。我对 WUSB3801 有一点不满，那就是它没有提供用于确定当前插入端口极性的 GPIO - 为此，您必须使用 I2C 接口。为什么需要知道端口极性呢？原因就在于高速接口，而 USB 3.0 接口无疑是 USB-C 的主流接口，这仅仅是因为它非常容易实现。

# 高速、但低价

使用 USB-C 插头制造 USB 3.0 设备与使用 USB-C 插头制造 USB 2.0 设备一样简单。USB 3.0 增加了两个高速差分对，而 USB-C 连接器则有四个差分对位置。有了这个插头，您就可以将 USB 3.0 SSRX 连接到 USB-C RX1，将 USB 3.0 SSTX 连接到 USB-C TX1，然后在 CC1 上插入一个下拉电阻，这样就大功告成了。除了 USB 3.0 链路可能需要的串联电容外，没有任何额外的元件，这些元件与普通的实现方式并无不同。

现在，这就是为什么你会看到很多 USB 闪存盘采用 USB-C 插头的原因——添加 USB-C 插头非常简单，你不需要弄清楚 CC 引脚，也不需要添加任何额外的元件。不过，如果要添加一个支持 USB 3.0 的 USB-C 插座，则需要添加额外的组件。想象一下，将 USB 3.0 USB-C 闪存盘插入 USB-C 插座，根据接口方向的方向，插针最终会位于两个位置中的一个。你不会想把插座的 TX/RX 引脚连接在一起，那样会有很大的信号完整性问题，所以如果你要添加一个支持 USB 3.0 的 USB-C 插座，你需要一个复用器来处理高速信号的接口方向。

![USB-C 的 USB3 电路图](https://hackaday.com/wp-content/uploads/2023/07/hadimg_usbc_reference_4b.png)

现在，这种 USB-C 芯片已经屡试不爽，至少有十几家不同的制造商生产这种芯片。有些多路复用器会有一个 POL 输入，用于将 USB 3.0 信号手动切换到两个可能的位置——这些多路复用器应与您自己的 PD 控制器（即处理 CC 引脚的芯片）一起使用。您会发现，许多多路复用器也包含 CC 逻辑，基本上可以为 5V 和支持 USB 3.0 的 USB-C 提供完整的解决方案。如果您正在构建主机的电路，可能只需要添加 VBUS 处理，而如果您正在构建带有 USB-C 插座的设备，则不需要其他任何东西！

笔记本电脑上的许多廉价 USB-C 端口都采用了这种多路复用器——它们只提供 USB 2.0，不提供其他任何功能，而且这种多路复用器非常容易实现，因此许多廉价笔记本电脑制造商都采用了这种多路复用器。此外，如果你有一个 USB 3.0 端口，你甚至可以省略多路复用器。我们在台式机主板上见过这种做法，有趣的是，[MNT Pocket Reform 的两个 USB-C 端口也是这样接线的](https://source.mnt.re/reform/pocket-reform/-/tree/main/pocket-reform-motherboard)！Pocket Reform 主板的板载 USB 3.0 集线器有四个空闲端口，但只有两个 USB-C 端口可以使用 USB 3.0。如果有人想使用这两个额外的 USB 3.0 端口，只需设计一个无源适配器即可！

Pocket Reform 上的这两个 USB-C 端口中有一个很特别，它不像第一个端口那样只将 5 V 电压轨连接到 VBUS。相反，它有一个电源开关 IC 与 VBUS 连接，还有一个 FUSB302B 与 CC 引脚连接。这就是 Pocket Reform 的充电器端口，事实上，这也是实现电源传输的方法之一。

# 获取电压和像素

我们讨论过的所有选项都已支持高达 15W 的功率，特别是 5V、3A 的电压。您只需要懂 PD 协议，或者让芯片为您协商。

![高电压设备端口](https://hackaday.com/wp-content/uploads/2023/07/hadimg_usbc_reference_5.png)

正如你可能猜到的那样，这些友好的芯片就是 PD 触发器集成电路。你将它们连接到 CC 引脚，它们就会代表你协商电源配置文件。它们有几个输入端让你设置所需的电压，如果电源供应器无法提供你所需的电压，还可以选择一个场效应管驱动器输出端来断开 VBUS，确保你不会在需要 20V 电压的电源轨上获得默认的 5V 电压。

关于触发器芯片，我们可以谈很多，[很多人都聊过了](https://hackaday.com/2022/07/02/dual-power-supply-in-a-pinch/)，我肯定也是。事实上，当人们需要从 USB-C 端口获得高电压时，绝大多数人都会选择触发芯片。它们非常适合大多数使用情况，而且很有可能，你会想要使用它。但是，请注意，它们的行为并不灵活：它们不会让你制造一个双功能端口，也不会让你区分 30W USB-C PSU 和 100W PSU，而这在你驱动电阻负载时是有帮助的。此外，由于没有方向输出，它们也不能与 USB 3.0 或 DisplayPort 结合使用，也不能发送自定义信息。

![DisplayPort 接口](https://hackaday.com/wp-content/uploads/2023/07/hadimg_usbc_reference_6.png)

一个 PD 控制器能让您做更多事情！无论您使用的是 FUSB302B 这样的外置 PD 控制器，还是内置在 MCU 中的 PD 控制器，它都能让您做出自己的 PD 通信决定。它提供了您可能需要的所有电阻器，而且无论您需要完成什么任务，都有可能找到示例代码。我们已经完成了用于电源和 DisplayPort sink 操作的自定义 PD 信息构建。到时候，我们甚至会用 FUSB302B 构建自己的 USB-C PSU，敬请期待！说到 MCU，有一些著名的 STM32 和 Cypress 的微控制器带有 PD 外设，最近，CH32X035 也加入了这一行列。

您自己的 PD 控制器还能让您发送 DisplayPort 信息——从任何兼容端口提取 DisplayPort 输出，或者自己提供 DisplayPort。使用 USB-C 插头就不需要多路复用器，或者使用插座并添加一个兼容 DisplayPort 的多路复用器，这样就能同时提取双通道 DisplayPort 和 USB 3.0，或四通道 DisplayPort，随你所需。或者，你也可以使用 DisplayPort 插座，省去多路复用器，让端口只在一个方向上工作——中国的 eDP 分线器销售商可以证实这一点！

在下一篇文章中，我们将介绍 USB-C PSU 的内部工作原理，然后将 20V PSU 转换为支持 20V 的 USB-C 电源；我们只需要 FUSB302、几个 FET 和一个备用 5V 稳压器。这不需要我们做太多，你就能将旧电源转换为 USB-C 笔记本电脑电源，还能了解 USB-C PSU 的工作原理！
