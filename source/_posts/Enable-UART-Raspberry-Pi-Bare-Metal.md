---
title: Enable UART to play with Raspberry Pi Bare Metal
date: 2020-05-17 23:57:50
tags:
- Embedded System
- Bare Metal
- Raspberry PI
- Debug
- UART
categories:
- [Embedded System, Raspberry PI]
---

If you want to write an OS for Raspberry Pi, you may need play with its Bare Metal mode. Thus, a UART debug serial is needed.

Considering that the bootloader of Raspberry Pi is proprietary, and it's provided as a binary file in the `/boot` partition, we cannot modify the boot sequence, and we cannot see the output of the binary executable. Through the UART serial, the only thing that we can see is the successful boot after the loading of Raspian kernel:

{% asset_img raspbian.png %}

But, as we are on Bare Metal mode, if anything goes wrong during booting your own "kernel", it's not easy to find out the reason.

This post will help you enable the UART debug mode to see what's happening behind the proprietary code before loading your own kernel.

# Bootloader file `bootcode.bin`

Mount the `/boot` partition on the SD card, you can see lots of files. Some of them are device tree files; some of them are configuration files. The one we concentrate on, is `bootcode.bin`, the proprietary executable from Raspberry Pi.

It's a binary file, so it's not readable for human-being. But there are some static strings in the binary file, which might be meaningful to us.

{% asset_img bootcode.png %}

For us, the most important string is `BOOT_UART`. To enable the debug output of the binary executable, just modify its value from `0` to `1`:

{% asset_img modification.png %}

# Save and boot

Save that modification and insert the SD card into your Raspberry Pi. Then boot it, you will see the magic output:

{% asset_img boot.png %}

I hope this post can help you, and enjoy your Raspberry Pi Bare Metal development!
