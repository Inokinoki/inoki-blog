---
title: Bug AX88179_178a USB-Ethernet adapter Linux Driver
date: 2019-12-12 10:52:00
tags:
- Linux
- Linux Driver
- ASIX
- Bug
categories:
- [Source Code, Linux Driver, USB-Net]
- [Bug, Linux Driver]
- Linux Driver
---

In my previous post, [AX88179_178a USB-Ethernet adapter Linux Driver](/2019/12/09/AX88179_178a_USB_Ethernet_adapter_Linux_Driver/), there is a simple analysis of the Linux Driver of AX88179_178a. And I mentioned that on the mainline, there is a bug while handling the USB packet that we received.

# Background

The phenomenon is that the TLS connection cannot be established through a bridged network. Both in the two following cases:

1. Bridged network on VirtualBox

In VirtualBox, we setuped a bridged network via the device `Edimax EU-4306`, to connect the Virtual Machine with a raspberry.

2. Bridged network on Raspberry Pi

{% asset_img topology.png Topology %}

On device B, we made a network bridge to connect the PC and the device A. All the packets which don't have a destination to device a will be resent to the other side.

# Diagnosis

It was a mystery why in these two cases, the communication doesn't work.

So, I used Wireshark to do a monitoring on the interfaces.

First one was running on the PC:

{% asset_img 1.pc_send.png PC send packet %}

We can see that, the first packet with 1514 length is the No.616. We should note that the packet No.617 is the one with length 336, and it acts as a TLS handshake packet.

The second one is on the device B, monitoring the network interface which is created by `Edimax EU-4306`:

{% asset_img 2.a_receive.png A reception %}

The packet matches the No.616 is the packet No.1858 on this interface. And No.617 matches No.1859. Both of them has two bytes in addition at the end. The two bytes are translated as `VSS-Monitoring ethernet trailer, Source Port: 26490` or something similar.

The device B should resent all packets to the other network interface.

Here is the traffic on the other network interface:

{% asset_img 3.a_send.png A send packet %}

We cannot find the index of packet, but we can well find the packet in order. The two we are following are the one with 1516 length and the one following it with 338 length.

{% asset_img 4.b_receive.png B reception %}

And finally, on the device A, our destination, we can see that all packets with 1516 length disappeared, which means that they are dropped.

# Problem

Up to here, we can see that it's the `Edimax EU-4306` USB-Ethernet Adapter causing the bug. But, why?

So, we need firstly introduce the concept of MTU, Maximum Transmission Unit. In Linux world and maybe the other system, it's the maximum size, in byte, of a packet, which can be sent to a network interface.

The sender will check the size of data it's going to send, and do some segmentation to cut the data into packets if the size of data is larger than MTU. But the device which acts as a switch, that means which provides the bridged network, will not do the segmentation because it has no such permission. The device just receives a packet, and try to resend it to another physical network. Meanwhile, the network interface of this device will do a check of packet size. The packet will be dropped if it's too large(larger than MTU).

It's kind of something abstract. So we just take the second case in the Background chapter as an example. This is the topology of the bridged network.

{% asset_img topology.png Topology %}

All MTU in the picture are 1500, it's also the one in the Ethernet protocol.

To describe better the question, we just use a packet of size 1514(1500 + 6 bytes destionation MAC address + 6 bytes source MAC address + 2 bytes protocol type). The target is to send this packet to device A.

{% asset_img 1.wrap_with_usb.png Wrap with USB %}

The first step is using the USB network driver to wrap the network packet, with some necessary USB information. This will be done by Linux Kernel, and the output will be sent to the USB device.

{% asset_img 2.arrive_at_usb_device.png Arrival of packet %}

When the adapter receives the packet, it will handle with it, there may be some control message.

{% asset_img 3.unwrap_ethernet.png Unwrapping USB packet %}

The adapter squashes out the network packet, and send it to another side.

{% asset_img 4.arrive_at_adapter.png Arrival of packet %}

{% asset_img 5.warp_with_usb.png Wrapping with USB %}

Another side is also an adapter, it will wrap the network packet to a USB packet, as to send it to the USB Host. Here the USB Host is device B.

{% asset_img 6.arrive_at_host.png Arrival of USB packet %}

{% asset_img 7.unwrap_ethernet.png Unwrapping USB packet %}

Here, the adapter is well `Edimax EU-4306` using `AX88179_178a` driver. The driver unwraps the USB packet, but unfortunately, adds two bytes at the end of network packet. So, the size of network packet becomes 1516, with two bytes in addition and by accident.

{% asset_img 8.failure.png Failure of transmission %}

Then, device B, as a switch, tries to resend the network packet to the other interface. But the other interface realizes the packet is larger than its MTU. Finally, it drops the network packet. Thus, device A will never receive the packet.

# Fixup

Up to now, it's clear that the error is caused by the reception function of `AX88178_179a`, while unwrapping a packet.

## Single packet

To make it simpler, we come back to the tiny packet describe in my previous post:

{% asset_img rx_usb_net_packet.png RX USB Ethernet Packet %}

{% asset_img rx_net_packet.png RX Ethernet Pacquet %}

Obviously, the larger one is the USB packet.

The analysis in detail of the packet can be found in that post. We'll directly the data that is extracted from the packet.

The packet length should be `0x3e` -> 62 bytes. So, if we count from `0040`, the end should be at `007d`.

```c
if (pkt_cnt == 0) {
    /* Skip IP alignment psudo header */
    skb_pull(skb, 2);
    skb->len = pkt_len;
    skb_set_tail_pointer(skb, pkt_len);
    skb->truesize = pkt_len + sizeof(struct sk_buff);
    ax88179_rx_checksum(skb, pkt_hdr);
    return 1;
}
```

With the code on Linux mainline codebase:

1. Remove the first two bytes because they are useless, and they just work as an auxiliary tool to align some bytes. Here, `0xee 0xee` are removed , the length in the buffer structure is also reduced. So, the real packet size is `0x3c` - 60 bytes.
2. Then, set the length to the packet length: `0x3e`.
3. Finally, do something with the buffer. We don't care this.

If you are sensitive, you should have already realized that the problem occured in the second step.

We begin at `0042` after the removing. But it always ends up with an offset of 62 bytes. So, we got a packet from `0xff 0xff` to `0xf9 0xc2`, where the last two bytes are not in the origin network packet, they are a part of USB packet.

Here is my code to fix it up:

```c
if (pkt_cnt == 0) {
    /* Skip IP alignment psudo header */
    skb->len = pkt_len;
    skb_pull(skb, 2);
    skb_set_tail_pointer(skb, pkt_len);
    skb->truesize = skb->len + sizeof(struct sk_buff);
    ax88179_rx_checksum(skb, pkt_hdr);
    return 1;
}
```

It's really simple, I just change the order of the first step and the second step.

It means that we'll firstly change the size to the packet size that we extract, then we remove the first two bytes and reduce the size by 2.

Thus, the packet is okay, with 60 bytes and from `0xff 0xff`.

## Multiple packet

For the case when we have plenty of network packets in a single USB packet, we do nearly the same thing:

```c
ax_skb = skb_clone(skb, GFP_ATOMIC);
if (ax_skb) {
    /* Code on mainline
    ax_skb->len = pkt_len;
	ax_skb->data = skb->data + 2;
    */
    ax_skb->len = pkt_len;
    ax_skb->data = skb->data + 2;
    /* Skip IP alignment psudo header */
    skb_pull(ax_skb, 2);
    
    skb_set_tail_pointer(ax_skb, pkt_len);
    ax_skb->truesize = ax_skb->len + sizeof(struct sk_buff);
    ax88179_rx_checksum(ax_skb, pkt_hdr);
    usbnet_skb_return(dev, ax_skb);
} else {
    return 0;
}
```

Okay, we test!

# Test

We test it with the ARP packet mentioned in my last post:

{% asset_img fixed.png Fixed %}

Here we can see the length is 60, no more 62. It means we fixed it!

# Conclusion

This is a serious bug in common, but the use case is not in common: if the packet need not be resent, there is no panic because the protocol on top-level can well handle the packet length with its own length field.

I hope one day the bug can be fixed on the mainline codebase of Linux. Maybe I can do that? As it's a driver of a device for a manufacturer, I don't know whether have the right to do that...
