---
title: Win 10 ARM Installing on Raspberry PI 3
date: 2019-05-16 23:44:40
tags:
- Embedded System
- Win 10 ARM
- Raspberry PI
categories:
- [Embedded System, Raspberry PI]
---

Since Microsoft published their Win 10 on ARM (WoA), many devices based on ARM64 get their own versions of Windows 10. The one I prefer is the Lumia 950 XL stuff by [@imbushuo](https://twitter.com/imbushuo). This gives new life to Lumia 950 and Lumia 950 XL, although WoA cannot be used in the productivity environment on these two phones.

This article will show a simple step to install WoA on Raspberry PI (3rd generation or later). And the platform of your host should be Windows.

# Preparation

You can follow the step on the [https://pi64.win/](https://pi64.win/) using WoA deployer.

But here, in this article, we will use the other one: `Windows on Raspberry Installer` on [https://www.worproject.ml/](https://www.worproject.ml/). So download and extract it.

To install Windows on ARM, we should have a SD card with capacity of more than 8G, 32G is recommanded.

## Getting image

Before flashing, we need prepare the Windows image and drivers.

Image can be got on [https://uup.rg-adguard.net/](https://uup.rg-adguard.net/). You can follow the guide on [https://github.com/WOA-Project/guides/blob/master/GettingWOA.md](https://github.com/WOA-Project/guides/blob/master/GettingWOA.md).

{% asset_img image.jpg Win 10 ARM Image %}

Download the script and run it in the cmd. After long waiting, there should be an image file in the same directory of the downloaded script.

## Getting drivers

Download drivers on the same page of `Windows on Raspberry Installer`.

## Getting UEFI firmware

Access [https://github.com/andreiw/RaspberryPiPkg/](https://github.com/andreiw/RaspberryPiPkg/) and take one `.fd` file in `Binary/prebuilt/` folders, in general, we use the latest one. Its name could be `RPI_EFI.fd`.

# Flashing your SD card

Open the application and choose your language. Here we just use English for more readers.

{% asset_img 1.jpg Language %}

Choose your SD card.

{% asset_img 2.jpg SD Card %}

Select the image which you downloaded during the preparing periode, and choose the version you want to install.

{% asset_img 3.jpg Choose image %}

Select the zipped drivers you downloaded.

{% asset_img 4.jpg Choose drivers %}

Select the UEFI firmware you downloaded.

{% asset_img 5.jpg Choose firmware %}

And just flash it !

# Launch Win 10 on Raspberry PI

If all goes well, you can get into the activation screen of Win 10 (after a really long waiting, because Raspberry PI is not so performent).

Count the processor if you want, and there are many interesting things to do :)

![Launch](https://pbs.twimg.com/media/D5lbVseXkAYup6q.jpg:large)

# Bug fix

If you get stuck during the UEFI boot screen, please reboot the device, before the loading bar ended, press an appropriate key to enter BIOS setting. Move Windows boot item as the first one, save and exit.
