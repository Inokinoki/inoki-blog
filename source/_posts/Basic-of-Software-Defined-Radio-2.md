---
title: 【译】软件定义无线电的基础 —— 2.接收机
date: 2020-07-03 20:08:00
tags:
- SDR
- 中文
- 翻译
categories:
- [Translation, Chinese]
- SDR
---

原文链接：[https://www.eetimes.com/sdr-basics-part-2-receivers/](https://www.eetimes.com/sdr-basics-part-2-receivers/)

# 架构

理想情况下，SDR 的设计人员希望将数据转换器直接放在天线上。但是，这不是实际情况中的解决方案。实际上，一些模拟前端必须在接收路径中的 ADC 之前和发送路径中的数模转换器之后才能使用，来执行适当的频率转换。这些体系结构中最常见的是超外差（super-heterodyne）架构。尽管这种架构已经有数十年的历史了，但全新的半导体技术和更高的集成度使该体系结构仍然充满活力，并在发送和接收信号路径中都得到了广泛使用[\[5，6\]](#参考)。

其他体系结构（例如用于发送和接收的直接转换）在要求不高的应用程序中受到欢迎。当前，直接转换（Tx和Rx）在用户终端中被发现用于蜂窝通信、以及在基站侧的 Tx，随着未来的发展，也存在于接收端实现直接转换的可能性。在此之前，超外差架构将继续以一种或另一种形式使用。

# 接收器

高性能 SDR 接收器通常由超外差架构的某些变体构造而成。超外差接收器可在很大的频率范围内提供稳定的性能，同时保持良好的灵敏度和选择性[\[7，8\]](#参考)。尽管设计并非易事，但结合使用宽带模拟技术和多个前端的可能性将允许在不同的 RF 频段上进行操作。对于多载波应用，必要时也可以同时进行。

## 多载波

取决于应用程序，我们可能需要一个或多个接收通道。传统应用可能只需要一个 RF 通道。但是，需要高容量或互操作性的应用程序可能需要多载波设计。由于 SDR 采用具有足够可用带宽的高度过采样 ADC ，因此非常适合多载波应用。

过采样 ADC 是一种采样率超出了满足奈奎斯特抽样准则[\[18\]](#参考)要求的采样率的 ADC ，该准则规定转换器的采样率必须是信息带宽的两倍。由于 SDR 可能不清楚将用于接收信号的带宽，因此采样率必须足够高才能对所有预期的带宽进行采样。

当前的 ADC 技术允许将高达 100 MHz 的高动态范围带宽数字化。有了这么多的带宽，也就可以处理多个通道。图 18.5 给出了一个典型的多载波接收机示例，图 18.6 给出了其频谱显示。

{% asset_img multicarrier-cdma-example.gif 多载波 CDMA 示例 %}

18.5. 多载波 CDMA 示例

{% asset_img multimode-spectrum.gif 使用 IS-95 的多模式频谱和窄带载波 %}

18.6. 使用 IS-95 的多模式频谱和窄带载波

在此示例中， ADC 的采样率设置为 61.44 兆采样/秒（MSPS），这提供了 30.72 MHz 的奈奎斯特带宽。如果每个RF通道的宽度为 1.25 MHz，则奈奎斯特表示潜在频道的数量约为 24.5。实际上，通过在抗混叠滤波器上允许合理的过渡带，典型的可用带宽是采样率的三分之一，而不是奈奎斯特的一半。因此，这个示例的可用带宽为 20.48 MHz，在 1.25 MHz 带宽时仅允许 16 个频道。

由于可以改变信道特性，因此很容易将 CDMA 示例更改为 GSM 示例。在这种情况下，通过将数字通道滤波器从 GSM 更改为 CDMA 并将新的处理代码加载到 DSP 中，分别重新配置了数字预处理和通用 DSP。由于 GSM 信道的宽度为 200 kHz，因此可以轻松地将该示例重新配置为 102 信道的 GSM 接收器。

虽然这两个示例都提供了很多实用性，但也许更有趣的示例是：配置接收器，以使部分信道可以是 CDMA，而其他信道可以配置为 GSM！

此外，如果其中一种配置已满负荷使用，而另一种配置未得到充分利用，则可以将 CDMA 信道转换为多个 GSM 信道，反之亦然，从而可以根据需要灵活地动态重新分配系统资源（软件定义无线电的主要目标）。

## 单载波

并非所有 SDR 应用程序都需要一个以上的信道。低容量系统可能只需要一个载波。在这些应用中，仍然需要一个高的过采样率。如果这个信道是可重新编程的，则可能会窄到几个 kHz 或 5-10 MHz。为了适应此带宽范围，采样率应适合最高的潜在带宽，在这种情况下为 10 MHz。从多载波示例中，我们通常将采样至少三倍的带宽。在此示例中，30.72 MSPS 或更高的采样率将允许处理从几 kHz 到最高 10 MHz 的信号带宽。除了只处理一个信道之外，单载波接收机也具有多载波接收机的全部容量，也可以根据需要重新配置。

## SDR 接收器的元素

参考图 18.7 中的单载波框图，同时要记住这也适用于多载波示例，一个完全开发的 SDR 将具有所有可编程的信号元素。

{% asset_img single-carrier-rx.gif 单载波接收示例 %}

18.7. 单载波接收示例

天线也不例外，也是可编程的。但不幸的是，它是 SDR 中最弱的元素之一[\[1\]](#参考)。由于大多数天线结构的带宽仅为其中心频率的一小部分，因此多频带操作会变得困难。在使用单个工作频带的许多应用中，这不是个问题。但是，对于必须在多个几个频率上运行的系统，必须通过某种方式调整天线以跟踪工作频率、保持工作效率。

的确，几乎所有天线都可以与有源电子设备进行阻抗匹配，但是通常会牺牲链路增益，从而可能导致天线损耗，而大多数天线设计实际上应该提供适度的信号增益。因此，需要通过简单地改变天线的匹配来调整天线的电长度。TODO:尝试解释。

信号链中的下一个是频带选择滤波器这一电子器件。提供该元件是为了限制呈现给高增益阶段的输入频率的范围，以最大程度地减小互调失真的影响。即使在互调不成问题的情况下，高强度的频带外信号也有可能在随后的阶段中限制潜在的增益量，从而导致灵敏度受限，尤其是对于在发射功率电平可能超过 100 kW 的电视和音频广播服务附近调谐的接收器。

对于必须处理许多数量级信号幅度的多载波接收机而言，这尤其成问题。如果所有信号都令人感兴趣，那么将不可能对较强的信号进行滤波，而且得到的接收器必须具有相对较大的信号动态范围[\[8\]](#参考)。

大多数接收器需要一个低噪声放大器（LNA）。一个 SDR 理想情况下应包含能够在所需频率范围内工作的 LNA。除了典型的 LNA 和 High IP3 之外，可能还需要具有调整增益的能力，并在可能的情况下按比例减小功率（通常是 NF 和 IP3 跟踪偏置电流），这将允许各种信号条件在整个操作的频带范围内都存在。// TODO: 优化翻译

混频器用于将 RF 频谱转换为合适的 IF 频率。尽管在图 18.7 中仅显示了一个混频器，但是许多接收器可以使用两个或三个混频器级，每个级依次产生一个较低的频率。（请注意：接收器 IF 并不总是低于 RF 信号。在高频接收器中可以找到一个常见的例子，在该接收器中，所需的RF信号可能只有几个 MHz。在这些情况下，它们经常混频到 10.7 MHz，21.4 MHz，45 MHz 或更高的 IF 频率，因为所需组件的可用性或性能）每个连续级还利用了分布在整个链中的滤波功能，以消除不需要的像/，以及其他在混合过程中留存下来的不需要的信号。滤波也应适合该应用程序。传统的单载波接收器通常会通过混频器级应用信道滤波，以帮助控制每级的 IP3 要求。而在多载波接收机的情况下，无法预先知道信道带宽，从而无法进行模拟信道滤波。

因此，混合过程必须保留整个感兴趣的频谱。同样，我们的单载波 SDR 应用程序也必须保留最大可能的频谱，以防 SDR 需要全频谱。在这种情况下，即使仅关注一个载波，我们的单载波示例也可能正在处理许多载波。与 LNA 一样，我们希望 SDR 中的混频器具有可调的偏置。与 LNA 一样，该偏置可用于正确设置设备的转换增益和 IP3 以对应于所需的信号条件。

除混合器之外或代替混合器，某些接收机体系结构还使用正交解调器。解调器的目的是分离 I 和 Q 分量。 分开后，I 和 Q 路径必须保持单独的信号调理。在数字域，这不是问题。但是，在模拟域中，信号路径必须完美匹配，否则将引入 I/Q 不平衡，从而可能限制系统的适用性。

如单载波示例所示，许多 SDR 接收器通过利用实采样（而不是复采样）来避免此问题，并在数字预处理器中使用可提供完美正交的数字正交解调器。

当与输入的 RF 信号混合时，本地振荡器用于生成适当的 IF。通常，本地振荡器（LO）的频率可变，并且可以使用 PLL 或 DDS 技术通过软件控制轻松编程。在某些情况下，LO 可能不需要跳频。一个例子是用于接收固定频带内的多个载波。在这种情况下，LO 是固定的，并且整个频带被按块转换为所需的中频。通常可能需要更改 LO 的驱动电平，以优化各种信号条件下的寄生/伪性能。// TODO: 优化翻译

中频放大器通常是 AGC 形式的。AGC 的目标是在不过度驱动信号链其余部分的情况下，使用可能的最大增益。有时，AGC 由模拟控制回路控制。但是，数字控制回路也可以用于实现使用模拟反馈无法实现的困难控制回路。在多载波应用中，使用 AGC 最好的情况下也很难。如果接收器中的动态范围不足（主要由 ADC 决定），则强信号的增益降低可能会导致较弱的信号在接收器的本底噪声中丢失。在这样的应用中，理想的增益数字控制环路。只要没有信号丢失的危险，就可以正常使用控制回路。

然而，如果在存在非常强的信号的情况下检测到弱信号，可以做出决定允许有限量的削除，而不是减少弱信号的增益，而因此产生弱信号丢失的风险。通过数字控制环路比通过模拟环路更容易控制此类条件情况，从而可以更好地控制接收器的总转换增益。

ADC 用于将一个或多个 IF 信号转换为数字格式以进行处理。ADC 通常是瓶颈，而 ADC 的选择通常是决定 SDR 架构的驱动因素[\[1、9、10\]](#参考)。通常，设计人员被迫选择最佳的可用 ADC，因为意识到在许多情况下 ADC 可能会被过度指定。

还有一些时候，空中接口标准可能不针对多载波接收器，并且比在现场部署时所要求的 ADC 要好得多，这仅仅是因为该标准规定了测试方法。对于 ADC，可能需要更改采样率，输入范围以及潜在的活动带宽。数字预处理器可以采用多种形式。对于很高的采样率和数据速率，通常将其实现为 FPGA 或 ASIC。这些电路本质上在功能和参数范围上都非常灵活。当然，可以针对所需的任何功能对 FPGA 进行编程。通常，将对 FPGA 进行编程以执行正交解调和调谐，通道滤波以及数据速率降低。// TODO: 优化翻译

其他功能，例如 RF 功率测量和信道线性化也是可能的。所有这些元素都可以使用多种数字技术轻松生成，并且可以通过将各种系数加载到 FPGA 来轻松进行编程。通过这样做，可以使用单芯片配置来生成数字预处理器，这样的数字预处理器能够调整 ADC 的奈奎斯特频带的整个范围，还可以过滤从数 kHz 到数 MHz 带宽的信号。当需要多个频道时，可以重复设计以填充 FPGA。如果需要低成本的选择，则可以使用执行这些功能的各种 ASIC，它们通常被称为通道器，RSP 或 DDC。

SDR 中的最后一个元素是 DSP。由于这是一个通用 DSP，因此可以针对任何所需的处理任务进行编程。典型的任务包括均衡，检测，实现 rake 接收器的功能，甚至是实现网络接口，仅举几例。

由于它们是完全可编程的，因此它们几乎可以用于任何信号处理任务，并控制框图其他元素中的所有功能。随着 DSP 处理能力的提高，它也可能会接管数字预处理器中的许多功能。

# 总结

第三部分将会讲解 SDR 的发送端。

# 参考

1. J. H. Reed, Software Radio: A Modern Approach to Radio Engineering, Prentice Hall, Upper Saddle River, NJ, 2002.
2. J. Mitola, III, “Software Radio”Cognitive Radio,” http://ourworld. compuserve.com/homepages/jmitola/.
3. B. Brannon, D. Efstathiou, and T. Gratzek, “A Look at Software Radios: Are They Fact or Fiction?” Electronic Design, (December 1998): pp. 117″122.
4. B. Clarke and K. Kreitzer, “Software Radio Concepts,” unpublished paper.
5. B. Brannon, “Digital-Radio-Receiver Design Requires Reevaluation of Parameters,” EDN, 43 (November 1998): pp. 163″170.
6. B. Brannon, “New A/D Converter Benefi ts Digital IFs,” RF Design, 18 (May 1995): pp. 50″65.
7. W. H. Hayward, “Introduction to Radio Frequency Design,” The American Radio Relay League, 1994″1996.
8. J. J. Carr, Secrets of RF Circuit Design, McGraw-Hill, New York, 2001.
9. B. Brannon, “Fast and Hot: Data Converters for Tomorrow's Software-Defi ned Radios,” RF Design, 25 (July 2002): pp. 60″66.
10. B. Brannon and C. Cloninger, “Redefi ning the Role of ADCs in Wireless,” Applied Microwave and Wireless, 13 (March 2001): pp. 94″105.
11. B. Brannon, “DNL and Some of Its Effects on Converter Performance,” Wireless Design and Development, 9 (June 2001): p. 10. w.newnespress.com
12. B. Brannon, “Overcoming Converter Nonlinearies with Dither,” Analog Devices Applications Note AN-410, www.analog.com.
13. W. Kester, “High-Speed Sampling and High-Speed ADCs,” Section 4, High-Speed Design Techniques, www.analog.com.
14. W. Kester, “High-Speed DACs and DDS Systems,” Section 6, High-Speed Design Techniques, www.analog.com.
15. About CDMA and CDMA University. Available at http:// www.qualcomm.com.
16. Specifi cations. Available at http://www.3gpp2.org.
17. R. H. Walden, “Analog-to-Digital Converter Survey and Analysis,” IEEE Communications Magazine, 17 (April 1999): pp. 539″550.
18. H. Nyquist, “Certain Topics in Telegraph Transmission Theory,” AIEE Transactions, 47 (April 1928): pp. 617″644.
19. AD6645 Datasheet. Available at http://www.analog.com. 
