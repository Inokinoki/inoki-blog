---
title: 【译】ARM 的历史——第一部分：打造第一块芯片
date: 2023-08-20 20:34:00
tags:
- Hardware
- ARM
- 翻译
- 中文
categories:
- [Hardware]
---

原博客共分为三篇，原文链接如下：

1. https://arstechnica.com/gadgets/2022/09/a-history-of-arm-part-1-building-the-first-chip/
2. https://arstechnica.com/gadgets/2022/11/a-history-of-arm-part-2-everything-starts-to-come-together/
3. https://arstechnica.com/gadgets/2023/01/a-history-of-arm-part-3-coming-full-circle/


    1983 年，Acorn Computer 公司需要一个 CPU。于是，10 个人制造了一个。

1983 年，Acorn Computers 正处于世界之巅。不幸的是，麻烦就在不远处。

这家英国小公司因为赢得了英国广播公司为全国电视节目生产电脑的合同而[声名鹊起](https://arstechnica.com/features/2020/12/how-an-obscure-british-pc-maker-invented-arm-and-changed-the-world/)。当时，BBC Micro 的销量急剧上升，有望突破 120 万台。

但是，个人电脑的世界正在发生变化。家长们[为了辅导孩子做作业](https://www.youtube.com/watch?v=Ts96J7HhO28)而购买的廉价 8 位微型机市场逐渐饱和。而来自大洋彼岸的新机器，如 IBM PC 和即将问世的苹果 Macintosh，则承诺提供更强大、更易用的功能。Acorn 需要一种竞争方式，但它没有太多资金用于研发。

# 创意的种子

BBC Micro 的设计者之一索菲-威尔逊（Sophie Wilson）早就预料到了这个问题。她增加了一个名为 "Tube" 的插槽，可以连接功能更强大的中央处理器。插槽式中央处理器可以接管计算机，让原来的 6502 芯片腾出时间执行其他任务。

![80286、32016 和 68000 CPU 的大致大小比例](https://cdn.arstechnica.net/wp-content/uploads/2022/09/cpu-286-32016-68000-1280x320.jpg)

威尔逊后来在接受计算机历史博物馆[采访](https://archive.computerhistory.org/resources/access/text/2012/06/102746190-05-01-acc.pdf)时解释说："我们可以看到所有这些处理器能做什么，不能做什么。因此，它们没有做到的第一件事就是没有充分利用内存系统。其次，它们的速度不快，不好用。我们习惯于用机器码对 6502 进行编程，我们更希望我们能达到这样的能力水平，即如果你用更高级别的语言编写，你也能达到同样的结果。

但另一种选择是什么呢？让小小的 Acorn 公司从头开始制造自己的 CPU 是否可行？为了弄清这个问题，威尔逊和福伯前往国家半导体位于以色列的工厂。他们看到了数百名工程师和大量昂贵的设备。这证实了他们的猜测，即他们可能无法完成这样的任务。

随后，他们参观了位于亚利桑那州梅萨的西部设计中心。这家公司正在制造深受人们喜爱的 6502，并在设计 16 位的后续产品 65C618。威尔逊和福伯发现，这里只有一间 "郊区的平房"，几名工程师和几名学生正在用老式的苹果 II 电脑和粘胶带制作图表。

但她应该选择什么样的处理器呢？威尔逊和联合设计师史蒂夫-福伯考虑了各种 16 位的选择，如英特尔的 80286、国家半导体的 32016 和摩托罗拉的 68000。但没有一个是完全令人满意的。

突然间，自制 CPU 似乎成为可能。威尔逊和福伯的小团队以前也制作过定制芯片，如 BBC Micro 的图形和输入/输出芯片。但与中央处理器相比，这些设计更简单，元件更少。

尽管困难重重，Acorn 的上层管理者还是支持他们的努力。事实上，他们不仅仅是支持。Acorn 联合创始人赫尔曼-豪瑟（Hermann Hauser）拥有物理学博士学位，他给团队提供了 [IBM 研究论文](https://www.ibm.com/ibm/history/ibm100/us/en/icons/risc/)的副本，其中描述了一种新型、功能更强大的 CPU。它被称为 RISC，意思是 "精简指令集计算"。

# 采用 RISC

这究竟意味着什么？要回答这个问题，我们先来上一堂超级简化的 CPU 工作原理速成课。首先是晶体管，一种由硅与不同化学物质混合而成的三明治状微小器件。晶体管有三个接头。当栅极输入端有电压时，电流可以从源极输入端自由流向漏极输出端。当栅极上没有电压时，电流就会停止流动。因此，晶体管是一种可控开关。

![简化的晶体管动画。](https://cdn.arstechnica.net/wp-content/uploads/2022/09/ars-transistor-animated.gif)

您可以将晶体管组合起来形成逻辑门。例如，两个串联的开关组成一个 "AND "门，两个并联的开关组成一个 "OR "门。这些门可以让计算机通过比较数字做出选择。

![使用晶体管的简化 AND 和 OR 门。](https://cdn.arstechnica.net/wp-content/uploads/2022/09/and-or-gate-anim.gif)

但如何表示数字呢？计算机使用二进制或 Base 2，将一个小的正电压等同于数字 1，无电压等同于 0。由于二进制运算非常简单，因此很容易制造出二进制加法器，可以将 0 或 1 加到 0 或 1，并存储总和和一个可选的进位。大于 1 的数字可以通过添加更多同时工作的加法器来表示。可同时访问的二进制位数是衡量芯片 "比特度 "的一个标准。像 6502 这样的 8 位 CPU 以 8 位为单位处理数字。

![由 AND 和 OR 门组成的全加法器电路。](https://cdn.arstechnica.net/wp-content/uploads/2022/09/full-adder-1.png)

算术和逻辑是 CPU 的主要功能。但人类需要一种方法来告诉它该做什么。因此，每个中央处理器都有一个指令集，它列出了中央处理器可以将数据移入和移出内存、进行数学计算、比较数字以及跳转到程序不同部分的所有方法。

RISC 的理念是大幅减少指令数量，从而简化 CPU 的内部设计。如何大幅减少？英特尔 80286 是一款 16 位芯片，总共有 357 条独特的指令。而索菲-威尔逊创建的新 RISC 指令集只有 45 条。

![英特尔 80286 指令集与 ARM V1 指令集的比较。每个指令变体都有一个单独的数字代码。(电子表格由原作者编制）。](https://cdn.arstechnica.net/wp-content/uploads/2022/09/arm-versus-intel-instructions-1280x1789.png)

为了实现这种简化，威尔逊使用了 "加载和存储" 架构。传统（复杂）CPU 有不同的指令，用于将两个内部 "寄存器"（芯片内部的小块存储器）中的数字相加，或将外部存储器中两个地址中的数字相加，或将每种指令的组合相加。相比之下，RISC 芯片指令只能在寄存器上运行。然后，单独的指令会将答案从寄存器移至外部存储器。

![通用 CISC CPU 与通用 RISC CPU 汇编语言的比较。RISC 处理器必须先将内存数值加载到寄存器中，然后才能对其进行操作。](https://cdn.arstechnica.net/wp-content/uploads/2022/09/risc-vs-cisc.png)

这意味着 RISC CPU 的程序通常需要更多的指令才能产生相同的结果。那么，它们如何才能更快？答案之一是，更简单的设计可以以更高的时钟速度运行。但另一个原因是，芯片执行更复杂的指令需要更长的时间。如果保持简单，就可以在一个时钟周期内执行每一条指令。这样就更容易使用[流水线](https://go.skimresources.com/?id=100098X1555750&isjs=1&jv=15.4.2-stackpath&sref=https%3A%2F%2Farstechnica.com%2Fgadgets%2F2022%2F09%2Fa-history-of-arm-part-1-building-the-first-chip%2F&url=https%3A%2F%2Fen.wikipedia.org%2Fwiki%2FInstruction_pipelining&xs=1&xtz=-120&xuuid=a43280cca373b687c30330c743d19b0b&abp=1&xjsf=other_click__auxclick%20%5B2%5D)技术。

通常，CPU 必须分阶段处理指令。它需要从内存中获取指令，解码指令，然后执行指令。Acorn 正在设计的 RISC CPU 将采用三级流水线。当芯片的一部分执行当前指令时，另一部分正在获取下一条指令，如此循环。

![ARM V1 流水线。每个阶段都需要相同的时间来完成。](https://cdn.arstechnica.net/wp-content/uploads/2022/09/unnamed.png)

RISC 设计的一个缺点是，由于程序需要更多的指令，因此需要占用更多的内存空间。在 20 世纪 70 年代末设计第一代 CPU 时，1 兆字节的内存大约需要 5,000 美元。因此，任何能减少程序内存大小的方法（拥有复杂的指令集将有助于实现这一目标）都是非常有价值的。这就是英特尔 8080、8088 和 80286 等芯片拥有如此多指令的原因。

但内存价格却在迅速下降。因此，RISC CPU 所需的额外内存在未来将不再是问题。

为了进一步保证新的 Acorn CPU 的未来发展，团队决定跳过 16 位，直接采用 32 位设计。这实际上简化了芯片的内部结构，因为你不必经常拆分大数字，而且可以直接访问所有内存地址。(事实上，第一款芯片只暴露了 32 个地址线中的 26 个引脚，因为 2 的 26 次方，即 64MB 在当时是一个非常大的内存容量）。

现在，团队需要的只是为新 CPU 取一个名字。团队考虑了各种方案，最终将其命名为 Acorn RISC Machine，或 ARM。

# 成为 ARM

第一款 ARM 芯片的开发历时 18 个月。为了节省开支，团队花了大量时间对设计进行测试，然后才将其投入到硅片中。Furber 在 BBC Micro 上用解释型 BASIC 为 ARM CPU 写了一个模拟器。当然，这个过程慢得令人难以置信，但它有助于证明概念，并验证威尔逊的指令集是否能按设计运行。

威尔逊认为，开发过程虽然雄心勃勃，但却简单明了。

"她说："我们以为自己疯了。"我们认为我们做不到。但我们不断发现，实际上并没有什么地方可以让我们停下脚步。这只是一个工作问题。

Furber 主要负责芯片本身的布局和设计，而 Wilson 则专注于指令集。但实际上，这两项工作是紧密交织在一起的。为每条指令选择代码并不是随心所欲的。选择每个数字的目的是，当它被转换成二进制数字时，指令总线上的适当导线就会激活正确的解码和路由电路。

测试过程逐渐成熟，威尔逊领导的团队编写了更先进的仿真器。"她解释说："有了纯指令模拟器，我们就可以在 6502 秒处理器上以每秒数十万条 ARM 指令的速度运行。"我们还可以编写大量的软件，将 BBC BASIC 移植到 ARM 和其他一切，包括第二处理器和操作系统。这让我们越来越有信心。尽管我们是在解释 ARM 机器代码，但其中一些东西比我们见过的任何其他东西都要好用。ARM 机器代码本身的性能非常高，解释 ARM 机器代码的结果往往比同一平台上的编译代码更好。

这些惊人的结果促使这个小团队完成了工作。第一个 ARM CPU 的设计被送到美国半导体制造公司 VLSI Technology Inc. 1985 年 4 月 26 日，第一版芯片回到橡果公司。威尔逊将它插入 BBC Micro 的 Tube 插槽，加载了移植到 ARM 版本的 BBC BASIC，并用特殊的 PRINT 命令进行了测试。芯片回答说："[世界你好，我是 ARM。](https://go.skimresources.com/?id=100098X1555750&isjs=1&jv=15.4.2-stackpath&sref=https%3A%2F%2Farstechnica.com%2Fgadgets%2F2022%2F09%2Fa-history-of-arm-part-1-building-the-first-chip%2F&url=http%3A%2F%2Fwww.computinghistory.org.uk%2Fdet%2F5440%2FFirst-ARM-Processor-Powered-Up%2F&xs=1&xtz=-120&xuuid=a43280cca373b687c30330c743d19b0b&abp=1&xjsf=other_click__auxclick%20%5B2%5D)"于是，团队开了一瓶香槟。

![最早的 ARM 芯片之一。](https://cdn.arstechnica.net/wp-content/uploads/2022/09/arm-first-chip.jpg)

让我们回过头来思考一下，这是一项多么了不起的成就。整个 ARM 设计团队包括索菲-威尔逊（Sophie Wilson）、史蒂夫-福伯（Steve Furber）、另外几位芯片设计师，以及一个编写测试和验证软件的四人团队。这个基于先进 RISC 设计的新型 32 位 CPU 是由不到 10 个人完成的，而且第一次就能正确运行。相比之下，美国国家半导体公司的 32016 已经进行了第 10 次修订，但仍在不断发现错误。

Acorn 团队是如何做到这一点的呢？他们将 ARM 设计得尽可能简单。V1 芯片只有 27,000 个晶体管（80286 有 134,000 个晶体管！），采用 3 微米工艺制造，也就是 3,000 纳米，颗粒度比现在的 CPU 小一千倍。

![ARM V1 芯片及其框图。](https://cdn.arstechnica.net/wp-content/uploads/2022/09/arm-diagram-1280x577.jpg)

在这种详细程度上，你几乎可以看清单个晶体管。以寄存器文件为例，将其与随机存取存储器工作原理的交互式框图进行比较。您可以看到指令总线将数据从输入引脚传送到解码器和寄存器控件。

虽然第一个 ARM CPU 给人留下了深刻印象，但指出它所缺少的东西也很重要。它没有板载高速缓冲存储器。它没有乘法或除法电路。此外，它还缺少浮点运算单元，因此对非整数的运算速度较慢。不过，使用一个简单的桶形移位器有助于浮点数的运算。芯片的运行频率仅为 6 MHz。

那么，这个小巧玲珑的 ARM V1 性能如何呢？在基准测试中，它比相同时钟速度的英特尔 80286 芯片快 10 倍左右，相当于运行频率为 17 MHz 的 32 位摩托罗拉 68020 芯片。

ARM 芯片还被设计成以非常低的功耗运行。威尔逊解释说，这完全是一项节约成本的措施--研究小组希望使用塑料外壳代替陶瓷外壳，因此他们设定了 1 瓦的最大功耗目标。

但是，他们用于估算功率的工具非常原始。为了确保不超标，不融化塑料，他们对每个设计细节都非常保守。由于设计简单、时钟频率低，实际功耗最终只有 0.1 瓦。

事实上，团队最先将 ARM 插入的一块测试板的连接断开了，根本没有连接到任何电源。当他们发现故障时非常惊讶，因为 CPU 一直都在工作。它只是在支持芯片漏电的情况下打开的。

威尔逊认为，ARM 芯片的低功耗是一个 "完全的意外"，但这在以后会变得非常重要。

# 使用 ARM 的新计算机

Acorn 公司拥有了这项领先竞争对手多年的惊人技术。财务上的成功肯定很快就会到来，对吗？如果你关注[计算机发展史](https://arstechnica.com/series/history-of-the-amiga/)，也许就能猜到答案。

到 1985 年，BBC Micro 的销售开始枯竭，一边是廉价的 Sinclair Spectrum，另一边是 IBM PC 克隆机。Acorn 将公司的控股权卖给了 Olivetti，因为之前曾与 Olivetti 合作为 BBC Micro 生产打印机。一般来说，如果把计算机公司卖给打字机公司，那可不是什么好兆头。

Acorn 向研究人员和业余爱好者出售带有 ARM 芯片的开发板，但这仅限于现有的 BBC Micro 用户市场。该公司需要的是一台全新的计算机，以真正展示这种新型 CPU 的强大功能。

在此之前，公司需要对最初的 ARM 稍作升级。ARM V2 于 1986 年问世，它增加了对协处理器（如浮点协处理器，这是当时计算机上流行的附加功能）和内置硬件乘法电路的支持。它采用 2 微米工艺制造，这意味着 Acorn 可以将时钟频率提高到 8 MHz，而无需消耗更多电力。

但是，仅有 CPU 还不足以构成一台完整的计算机。于是，团队又开发了图形控制器芯片、输入/输出控制器和内存控制器。到 1987 年，包括 ARM V2 在内的所有四种芯片都已准备就绪，同时还制作了一台原型计算机来安装这些芯片。为了反映其先进的思维能力，公司将其命名为 Acorn Archimedes。

![最早的 Acorn Archimedes 的型号之一](https://cdn.arstechnica.net/wp-content/uploads/2022/09/AcornArchimedes-Wiki-1280x1038.jpg)

考虑到当时是 1987 年，人们对个人电脑的要求已不仅仅是提示输入 BASIC 指令。用户需要像 Amiga、Atari ST 和 Macintosh 那样漂亮的图形用户界面。

Acorn 在施乐 PARC 所在的加利福尼亚州帕洛阿尔托成立了一个远程软件开发团队，为阿基米德设计下一代操作系统。它被称为 ARX，并承诺提供抢占式多任务处理和多用户支持。ARX 速度很慢，但更大的问题是它迟到了。非常晚。

当时，Acorn 阿基米德正准备发货，而公司还没有操作系统。这是一个危机四伏的局面。于是，橡果公司的管理层去找保罗-费洛斯（Paul Fellows）谈话，他是 Acorn 软件团队的负责人，曾为 BBC Micro 编写了大量语言。他们问他："你和你的团队能在五个月内为阿基米德写出一个操作系统吗？"

[费洛斯说](https://go.skimresources.com/?id=100098X1555750&isjs=1&jv=15.4.2-stackpath&sref=https%3A%2F%2Farstechnica.com%2Fgadgets%2F2022%2F09%2Fa-history-of-arm-part-1-building-the-first-chip%2F&url=http%3A%2F%2Fwww.rougol.jellybaby.net%2Fmeetings%2F2012%2FPaulFellows%2Findex.html&xs=1&xtz=-120&xuuid=a43280cca373b687c30330c743d19b0b&abp=1&xjsf=other_click__auxclick%20%5B2%5D)："我就是那个傻子，我说可以，我们能做到。"

五个月的时间对于从零开始制作操作系统来说并不算长。这个速成操作系统被称为 "亚瑟计划"，可能是以英国著名计算机科学家亚瑟-诺曼（Arthur Norman）的名字命名的，也可能是 "ARm by THURSday！"的缩写。它最初是 BBC BASIC 的扩展。理查德-曼比（Richard Manby）用 BASIC 编写了一个名为 "亚瑟桌面"（Arthur Desktop）的程序，仅仅是为了演示如何使用团队开发的窗口管理器。但他们已经没有时间了，所以演示程序被刻录到了第一批计算机的只读存储器（ROM）中。

![亚瑟系统截图](https://cdn.arstechnica.net/wp-content/uploads/2022/09/arthur-riscos12-640x512.png)

首批 Archimedes 机型于 1987 年 6 月发货，其中一些机型仍带有 BBC 商标。这些计算机的运算速度绝对很快，而且性价比很高--入门价格为 800 英镑，在当时约合 1300 美元。这与 1987 年售价 5500 美元、计算能力类似的 Macintosh II 相比毫不逊色。

但 Macintosh 拥有 PageMaker、Microsoft Word 和 Excel 以及大量其他实用软件。Archimedes 是一个全新的计算机平台，在发布之初，可用的软件并不多。计算机世界迅速向IBM PC兼容机和Macintoshes（还有几年的Amigas）靠拢，其他人都发现自己被挤出了市场。Archimedes 电脑在英国媒体上获得了良好的评价，并赢得了一批狂热的粉丝，但在最初的几年里，Archimedes 电脑的销量还不到10万台。

# 种子成长

Acorn 迅速修复了亚瑟中的错误，并开发出具有更多现代功能的替代操作系统 RISC OS。RISC OS 于 1989 年推出，随后不久，ARM CPU 的新版本 V3 也随之推出。

V3 芯片采用 1.5 微米工艺制造，将 ARM2 内核的尺寸缩小到约四分之一的可用芯片空间。这就为包含 4 千字节的快速一级高速缓冲存储器留出了空间。时钟速度也提高到 25 MHz。

虽然这些改进给人留下了深刻印象，但索菲-威尔逊等工程师相信，ARM 芯片还能更进一步。但是，在 Acorn 资源迅速减少的情况下，能做的事情是有限的。为了实现这些梦想，ARM 团队需要寻找外部投资者。

这时，另一家以一种流行水果命名的计算机公司的代表走了进来。。。