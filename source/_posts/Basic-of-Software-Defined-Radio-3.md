---
title: 【译】软件定义无线电的基础 —— 3.接收机
date: 2020-08-07 20:27:00
tags:
- SDR
- 中文
- 翻译
categories:
- [Translation, Chinese]
- SDR
---

原文链接：[https://www.eetimes.com/sdr-basics-part-3-transmitters/](https://www.eetimes.com/sdr-basics-part-3-transmitters/)

软件定义无线电（SDR）的发送功能也基于某种形式的超外差或直接转换。图 18.8 和 18.9 说明了这两个选项。多载波选项最适合单载波和多载波应用，而直接转换为单载波应用提供了一种出色的低成本解决方案。

随着集成技术的改进，多载波直接转换可能成为可能。但是，这样的发射配置需要比寄生需求好约 15 dB 的边带抑制，以防止中心频率一侧的图像超过另一侧的潜在弱载波。

在任何一种应用中，数字信号处理器（DSP）或基带 ASIC 均用于生成调制后的基带数据。此数据直接送入一对基带数字/模拟转换器（DAC）（I 和 Q）以进行直接 RF 调制，或送入负责将其数字转换为合适的数字中频（IF）的数字处理器。

取决于应用，可以单独使用 DSP 或与数字处理器结合使用，对基带数据进行数字预失真，从而消除信号链中稍后产生的失真产物。如果要使用 IF 级，则必须使用 FPGA 或 ASIC 或使用传统的混频器或调制器将 DSP 产生的基带数据数字化上变频至所需的 IF。

这种传统技术已被数字方式所取代，这是由于数字逻辑提供了更多的灵活性、而且良好的具有性价比的数模转换器已经可用。与相关的接收功能一样，该设备的目的是对所需通道的带宽进行整形，然后通过数字方式将其上变频至所需 IF 频率。 如果需要多个通道，则可以在一个芯片上合成它们。转换后，可以将每个通道加在一起并插值到所需的数据速率，然后发送到 DAC。如果需要，可以将数字预失真与 DSP 一起添加，以校正信号链中的失真。

混频器或调制器可以用来将频率转换为最终 RF 频率。如果采用直接射频调制，则使用射频调制器。如果使用中频（直接来自 DAC 或传统中频上变频），则将使用混频器转换为最终 RF 频率。与接收混频器/解调器一样，可能需要更改数据的偏置电平或驱动电平或 LO 电平以优化失真。

{% asset_img multichannel-transmit.gif 使用单个上变频超外差的多通道传输 %}

18.8 使用单个上变频超外差的多通道传输

{% asset_img single-carrier-direct-conversion-transmit.gif 单载波直接转换传输 %}

18.9: 单载波直接转换传输

与接收 LO 一样，发送 LO 的频率也可变，并且可以通过使用 PLL 或 DDS 技术的软件控制轻松编程。在此，也可能需要更改 LO 驱动电平，以优化各种信号条件下的杂散性能。与接收器的单频段操作一样，也可能存在需要固定 LO 的情况。

这样的例子将用于在单个频带内的操作，其中调谐在 ASIC 或 FPGA 内完成。与接收路径一样，数据转换器或 DAC 通常是瓶颈。但是，由于发射信号路径的动态范围要求比接收路径的动态范围要求低得多（通常为 25 至 45 dB），因此组件选择并不那么困难。有许多可用的 DAC 可以简化大范围的调整，包括增益和失调校正，从而可以最大程度地减小发射信号链中的 I/Q 不平衡。 其他所需的功能包括数据速率插值和 I/Q 相位校正。

最后，通过前置放大器和功率放大器（PA）实现功率增益。除了这些设备必须在很宽的频率范围内工作之外，还需要调整RF输出功率。这可能存在调整的问题，要求某些频率以比其他频率更低的功率进行传输。虽然 PA 增益通常是固定的，但前置放大器可以采用 VGA 的形式。

# 结论

随着全球范围内新的和更复杂的通信标准的发展，对新收发器架构的需求也将增长。但是，越来越多的可用资金，无论是资金还是人力，都限制了可以解决的设计。幸运的是，软件无线电技术可用于这些架构中不断壮大的一组，这些架构允许单个平台利用到许多不同的设计中。如此文所示，这具有许多明显的优势，并且不仅限于互操作性，投资保持和极大的灵活性。

与任何软件项目一样，SDR 的潜力通常仅受设计人员的想象力限制。与任何软件项目一样，最大的好处是，如果存在设计错误，则可以动动键盘就简单地解决问题。

幸运的是，最近十年来，半导体技术取得了重大进步，不仅在性能上，而且在成本上也取得了令人瞩目的成就[\[17\]](#参考)。SDR 是从这些多样化的技术中受益匪浅的领域，并且随着 SDR 含义的发展，它将继续这样的趋势，就像编程语言历史上的情况一样。

尽管 SDR 并非解决所有通信问题的方法，但它将在未来几年内为挑战性设计问题提供可靠的解决方案。包括相控阵技术，定位服务，互操作性以及尚未定义的复杂概念。但是，仍然存在一些挑战，使得无法完全接受该技术。两个主要问题分别是成本和功耗。有趣的是，这两者具有一阶正相关关系：解决一个问题、另一个只会变得更好。没有低功耗，用户设备将无法充分利用 SDR 技术。显然，电源问题来自对高性能组件的需求，高性能意味着超线性设备，高线性度器件意味着通过高电流会降低效率。

因此，如果解决了如何设计低功耗高线性度设备的问题，并且这是可以解决的，那么成本也将下降，这为许多其他应用打开了大门。因此，继续进行 SDR 开发和演进的关键是继续沿摩尔定律曲线改进设备，并继续对灵活的无线电架构产生兴趣。尽管存在这些挑战，但当前的性能状态已足以使工程师和制造商认真研究 SDR 的可能性。

# 参考

1. J. H. Reed, Software Radio: A Modern Approach to Radio Engineering, Prentice Hall, Upper Saddle River, NJ, 2002.
2. J. Mitola, III, “Software Radio”Cognitive Radio,” http://ourworld. compuserve.com/homepages/jmitola/.
3. B. Brannon, D. Efstathiou, and T. Gratzek, “A Look at Software Radios: Are They Fact or Fiction?” Electronic Design, (December 1998): pp. 117″122.
4. B. Clarke and K. Kreitzer, “Software Radio Concepts,” unpublished paper.
5. B. Brannon, “Digital-Radio-Receiver Design Requires Reevaluation of Parameters,” EDN, 43 (November 1998): pp. 163″170.
6. B. Brannon, “New A/D Converter Benefi ts Digital IFs,” RF Design, 18 (May 1995):pp. 50″65.
7. W. H. Hayward, “Introduction to Radio Frequency Design,” The American Radio Relay League, 1994″1996.
8. J. J. Carr, Secrets of RF Circuit Design, McGraw-Hill, New York, 2001.
9. B. Brannon, “Fast and Hot: Data Converters for Tomorrow's Software-Defi ned Radios,”
RF Design, 25 (July 2002): pp. 60″66.
10. B. Brannon and C. Cloninger, “Redefining the Role of ADCs in Wireless,” Applied Microwave and Wireless, 13 (March 2001): pp. 94″105.
11. B. Brannon, “DNL and Some of Its Effects on Converter Performance,” Wireless Design and Development, 9 (June 2001): p. 10. w.newnespress.com
12. B. Brannon, “Overcoming Converter Nonlinearies with Dither,” Analog Devices Applications Note AN-410, www.analog.com.
13. W. Kester, “High-Speed Sampling and High-Speed ADCs,” Section 4, High-Speed Design Techniques, www.analog.com.
14. W. Kester, “High-Speed DACs and DDS Systems,” Section 6, High-Speed Design Techniques, www.analog.com.
15. About CDMA and CDMA University. Available at http:// www.qualcomm.com.
16. Specifications. Available at http://www.3gpp2.org.
17. R. H. Walden, “Analog-to-Digital Converter Survey and Analysis,” IEEE Communications Magazine, 17 (April 1999): pp. 539″550.
18. H. Nyquist, “Certain Topics in Telegraph Transmission Theory,” AIEE Transactions, 47 (April 1928): pp. 617″644.
19. AD6645 Datasheet. Available at http://www.analog.com. 
