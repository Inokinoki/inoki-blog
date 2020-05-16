---
title: 【译】扩频因子如何影响 LoRaWAN 设备的电池寿命
date: 2020-05-16 22:27:00
tags:
- LoRaWAN
- LoRa
- IoT
- 中文
- 翻译
categories:
- LoRa
---

原文链接：https://www.thethingsnetwork.org/article/how-spreading-factor-affects-lorawan-device-battery-life

在 LoRaWAN 中，扩频因子是一个关键指标，它既可以帮助你完成你的 IoT 解决方案，也可以毁掉它，所谓 “成也SF，败也SF”。找到正确的扩频因子对实现 LoRaWAN 设备长期性能至关重要。这篇文章会解释如何找到电池寿命和长距离通信之间的正确平衡。

扩频因子（SF）决定每秒发送多少个线性调频脉冲，即数据的载体。网络根据通信设备和网关之间的环境条件来决定扩展因子（等级在7-12之间）。我们假定设备已启用 “自适应数据速率（ADR）” 功能，除持续移动的设备外，这个功能应当应用于所有设备。

较低的 SF 意味着每秒发送更多的 Chirps；因此，您可以每秒编码更多数据。较高的 SF 意味着每秒更少的 Chirps；因此，每秒能编码的数据较少。由于数据速率低，发送具有较高 SF 的相同数量的数据需要更长的传输时间，即空中时间。更长的通话时间意味着调制解调器的启动和运行时间更长，并且消耗更多的能量。

高 SF 的好处在于，更长的通话时间使接收机有更多机会对信号功率进行采样，从而提高了灵敏度。更高的灵敏度意味着您可以在更远的地方接收信号，从而获得更好的覆盖范围。从理论上讲，SF中的每一步都将传输相同数量的数据的时间加倍，请参见下图。SF 的每一个步长都与大约 2.5dB 的额外链路预算相关。

{% asset_img relationship.png LoRa 调制中扩频因子和空中时间的关系 %}

理论都很美好，但实践中空中传输时间和电池寿命如何呢？

为了对此获得一个估计，我们使用了两个工具：
1. LoRaTools 中的空中传输时间计算器
2. 用 Otii 测试 SF7 和 SF12 的能量消耗曲线

在此测试中，我们测量了 Bintel 的一个 LoRaWAN 设备，该设备使用 Semtech 的 SX1276 芯片组。我们的设置是室内室外场景：设备是在办公室，在开发人员的桌子上，并且网关位于附近一栋建筑物的外面。因此，这不是该设备的正常使用场景，他的正常使用场景是户外的垃圾箱。我们使用 19 字节的有效负载和 125kHz 的带宽测量了第一次传输和整个活动周期的能耗。


{% asset_img Bintel-LoRaWAN.png 用于废物管理的 LoRaWAN 设备 %}

测量中，活动周期包含了对一个需要确认的消息的传输和一个对 ACK 的监听周期。

{% asset_img Measured-energy-consumption.png 带有网关上的确认（ack）的情况下，测得的SF12（蓝色）和SF7（绿色）传输的能耗 %}

{% asset_img Measured-and-calculated-transmission-time-and-measured-energy.png 测量和计算的传输时间以及SF12和SF7消耗的能量 %}

测量显示，与 SF7 相比，在 SF12 中传输大约需要25倍的时间和25倍的能量。空中时间计算器显示了相同的结果。

但是，数字 25 并非一成不变。它取决于有效负载大小和分配用于传输的报头。如果您使用不同大小的有效载荷，则可以看到不同的倍数。

请注意，以上计算仅仅对于发送时间，并不是整个活动周期。在此特定测量中，SF12中每个活动周期的能量消耗比是SF7能量的20倍（能量统计显示 55.1 uWh 对 2.78 uWh，见下图）。

{% asset_img Marked-energy-consumption.png 在整个活动周期（包括上行链路和下行链路）中，标记为在SF12（蓝色）和SF7（绿色）上传输的能耗 %}


值得一提的是，活动周期的能耗取决于设备的类别。如果是 A 类设备，则只有两个接收窗口，这意味着接收器的唤醒时间不会超过这两个窗口。另一种配置（C类）可以是设备保持连续收听，这会大大增加能耗。在这种情况下，SF 数无关紧要。

{% asset_img Measured-energy-consumption-no-ack.png 在网关未确认的情况下，测得的在SF12（红色）和SF7（黄色）上传输的能耗 %}

由于每种应用都是独特的，很难得出更多的结论。但是我们要强调的是，使能耗最低的最佳扩展因子不一定是最高或最低的，而是很可能介于两者之间：由于需要确认消息，如果重传次数过多，则短时传输的节能将因重传而迅速丢失。要记住的重要一点是，总能耗永远不会仅通过一个参数进行优化。

您可以下载下面的 `.otii` 文件来检查不同 SF 设置时的能耗测量：

需要用 [Otii 应用程序](https://www.qoitech.com/download) 打开：
[https://github.com/qoitech/otii-example-projects/blob/master/LoRa-SF7-vs-SF12.otii](https://github.com/qoitech/otii-example-projects/blob/master/LoRa-SF7-vs-SF12.otii)

更多有关 LoRa, LoRaWAN 的信息可以在下列链接找到：
- [LoRa CHIRP](https://www.youtube.com/watch?v=dxYY097QNs0)
- [LoRa crash course](https://www.youtube.com/watch?v=T3dGLqZrjIQ&feature=youtu.be&t=2122)
- [Decoding the LoRa PHY](https://www.youtube.com/watch?v=NoquBA7IMNc)
