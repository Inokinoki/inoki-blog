---
title: 【译】软件定义无线电的基础 —— 1.概述
date: 2021-11-12 20:08:00
tags:
- SDR
- 中文
- 翻译
categories:
- [Translation, Chinese]
- SDR
---

原文链接：[What is physical significance of IP3, why it is more important in Receiver Chain ?](https://www.techplayon.com/physical-significance-iip3-important-receiver-chain/)

# 了解三阶截点（IP3）的物理意义

The higher the output at the intercept, the better the linearity and the lower the IMD. The IP3 value essentially indicates how large a signal the amplifier can process before IMD occurs. For example, an IP3 rating of 25 dBm is better than one of 18 dBm.
Why IIP3 is measured in Receiver Chain

当一个放大器或其他电路变得非线性时，它将开始产生放大的输入的谐波。二次、三次和更高次的谐波通常在放大器带宽之外，所以它们通常很容易过滤掉。然而，非线性也会产生两个或多个信号的混合效应。

如果信号的频率很接近，产生的一些称为互调产物（Intermodulation products）的和差频率会出现在放大器的预期工作带宽内。这些不能被过滤掉，所以它们最终会成为被放大的主要信号中的干扰信号。

举例来说：接收链中的期望输入信号（F0）在 1750MHz，两个不期望的信号，F1=1760，F2=1770，所以当两个不期望的信号混合时，它们会产生三阶互调产物，其中一个在（2*F1-F2）落在 1750MHz，这也是期望信号的频率，因此期望信号的 SNR 会降低。

{% asset_img IIP3_1.png 例子 %}

三阶互调产物的功率水平取决于设备或放大器的线性度，以三阶截点（IP3）表示。

三阶截点（IP3）处的输出越高，线性度越好，互调扰动（IMD）越低。IP3 值本质上表明在 IMD 发生之前，放大器可以处理多大的信号。例如，IP3 值为 25 dBm 比 18 dBm 的要好。

# 为什么 IP3 在接收链中被测量

在接收链中，多个信号通过天线端口输入，由于干扰信号在天线端口的混合，产生的 IMD 会在所需的频段混合，从而影响所需信号的信噪比。我们无法控制天线端口的干扰信号，因为在空气中存在着不同频率的不同类型的信号。它们中的少数会在所需的频段上引起 IMD。

{% asset_img IIP3_2.png 接收链 %}

因此，测量接收器的三阶输入截点（IIP3）变得非常重要，以确保它产生多少影响信噪比的 IMD 水平。

接收器链的 IIP3 值越高，性能就越好，因为 IMD 功率水平更低。因此，它表明一个设备（如放大器）或系统（如接收器）在强信号下的表现如何。

# 发射器链中的 IP3 是什么？

在发射链中，通常 IP3 规格不太重要，因为在发射链中产生的信号通常是单载波，不会产生 IMD。例如，在单载波 GSM 中，传输的是一个载波信号，不会产生 IMD。在多载波 GSM 中，会产生 IMD，因为发射链中的多个信号混合在一起，产生互调产物。在多载波系统中，发射器链中的输出截点被测量（OIP3）或发挥着重要作用。

在 LTE 系统中，只产生一个载波，所以 OIP3 就不那么重要了。在 LTE Advanced 中，由于载波聚合，会产生多个载波，所以 OIP3 在这种情况下很重要。

但是，即使在发射机链中产生了单载波，在任何情况下，干扰信号都可能通过天线端口以相反的方向进入发射机链而导致互调产物，所以通常在发射机链中测量反向互调。
