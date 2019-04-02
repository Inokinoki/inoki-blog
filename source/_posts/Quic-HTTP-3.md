---
title: 【译】Quic-HTTP/3
date: 2018-11-26 12:48:24
update: 2019-03-24 09:55:03
tags:
- QUIC
- HTTP
- 中文
- 翻译
categories:
- [Translation, Chinese]
- Protocol
---

原文链接: [https://daniel.haxx.se/blog/2018/11/11/http-3/](https://daniel.haxx.se/blog/2018/11/11/http-3/)

曾经被称为 HTTP-over-QUIC 的协议改头换面，成为了官方的 HTTP/3 协议。Mark Nottingham 提出了这个提议，并且被工作组接受。

社区中使用不同的名字来称呼不同的版本，比如 iQUIC 和 gQUIC 来区分 IEFT 和 Google 的 QUIC 协议（因为在细节上它们的确有很多不同）。在很长一段时间里，经由 iQUIC 传输的 HTTP 协议被称为 HTTP-over-QUIC。

目前，IETF 中的 QUIC 工作组致力于创造 QUIC 传输协议。QUIC 协议作为一个基于UDP协议的 TCP 协议的替代品，最早由 Google 提出，后来被作为 HTTP/2-encrypted-over-UDP 使用。

 当这项工作由 IETF 接手来标准化时，它被分为了两个部分：传输部分和HTTP部分。这是因为我们也希望能够使用这个协议传输其他数据，而不仅仅是HTTP或类HTTP协议，但是我们保留了 QUIC 这个名字。

Mark Bishop 在 IETF 103 举行的 QUIC 工作组会议上惊吓到了他们，可以看到这个幻灯片上已经放出了一个 Logo ......

{% asset_img Screenshot_2018-11-06-HTTP-QUIC-slides-103-httpbis-httpquic-00.png QUIC naming slide %}

2018年1月7日，Litespeed 的 Dmitri 宣布他们和 Facebook 已经成功的实现了两个 HTTP/3 实现的互操作。紧接着 Mike Bishop 在 HTTPbis 的演讲的幻灯片如上。会议最后达成共识，新的名字为 HTTP/3 。

那么，不再有任何争议。**HTTP/3 将会成为新的使用 QUIC 传输的 HTTP 版本！**

{% asset_img QUIC.png Logo QUIC %}
