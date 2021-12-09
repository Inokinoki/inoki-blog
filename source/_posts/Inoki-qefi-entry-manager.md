---
title: EFI 启动项管理器——双系统启动神器，安全解决你的多系统启动难题
date: 2021-12-09 20:34:00
tags:
- Qt
- EFI
- 中文
categories:
- Inoki Home Made
- Qt
- EFI
---

你是否遇到过这样的问题？在电脑上安装多个系统：在安装好 FreeBSD 后，发现 Windows 启动不见了；在安装好 Windows 后，发现启动 Linux 用的 Grub 启动不见了。虽然用 refind 这种启动器可以部分解决这个问题，但有时候 Windows 更新之后一看，refind 启动也不见了。这时，运气好的话还可以在 EFI 固件设置中改变启动顺序找回，有些不支持的主板就只能重建引导啦。更何况，开机进入 EFI 固件要按的按键和时机也很麻烦。

这时就可以使用我开发的一个跨 Windows 和 Linux 平台的系统软件 EFI Entry Manager 解决。

# 安装

这个软件是通过 GPL 3.0 发布的开源软件，可以在我的 GitHub 上找到：[项目链接](https://github.com/Inokinoki/QEFIEntryManager)。

{% asset_img release.png %}

在 [Release](https://github.com/Inokinoki/QEFIEntryManager/releases/tag/v0.1.1) 中可以找到预先构建好的 Linux AppImage 和 Windows 的可执行程序压缩包，下载之后解压缩即可。

Linux 版本会有一个 AppImage 拓展名的文件，而 Windows 版本则需要放入一个文件夹中。

除此之外，Windows 版本还可能需要安装一个 VC 的运行时库，点击这个[链接](https://docs.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170#visual-studio-2015-2017-2019-and-2022)，选择 x64 版本下载并安装即可。

# 使用

在 Linux 中，需要使用 root 用户启动，比如 `sudo ./<executable>`。而在 Windows 中，需要右键使用管理员模式打开。

打开之后，首屏显示的是你的电脑当前的启动顺序。

![启动顺序](https://github.com/Inokinoki/QEFIEntryManager/raw/master/.github/entries.png)

用户可以选中一个启动项，点击 Move up 或 Move down 来改变启动顺序，最后点击 Save 来保存。

在第二个标签页中可以设置下次单次重启时使用的启动项。

![重启使用的启动项](https://github.com/Inokinoki/QEFIEntryManager/raw/master/.github/reboot.png)

保存之后可以选择是否立即重启，无论选择是与否，在下次启动时都会首先尝试使用用户保存的启动项启动。

# 原理解析

这个项目是基于我的另一个项目 [qefivar](https://github.com/Inokinoki/qefivar) 的，它是一个跨平台的库，可以通过系统 API 修改 EFI 固件的变量来改变启动顺序等。

在同个硬盘安装第二个系统后，往往原本系统的启动项会被覆盖。但其实只是 ESP 分区的 `Boot/Boot\<arch\>.efi` 这个默认启动项被覆盖了，实际的启动加载器的 efi 文件其实都还在，并且在 EFI firmware 配备的 nvram 中有入口。这时实际上只需要配置一下即可。

比如我安装了 win 之后又装了 FreeBSD，这时默认启动项就被 FreeBSD 写成了它的，没办法加载 win。我就使用 EFI Entry Manager 把启动顺序改成 win->FreeBSD->Ventoy 即可，然后每次想进 FreeBSD 只需要在进入 win 之后使用 QEFI Entry Manager 设置下次单次用 FreeBSD 的加载器启动，然后重启即可。

# 结论

这篇文章介绍了我六个月前的工作，如果帮到你的话可以给个 star，或者通过各种平台请我喝一杯咖啡吧~
