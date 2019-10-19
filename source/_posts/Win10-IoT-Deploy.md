---
title: Win 10 IoT - Deployment
date: 2019-10-19 19:29:40
tags:
- Embedded System
- Win 10 IoT
- Raspberry PI
categories:
- [Embedded System, IoT, Win 10 IoT]
- [Embedded System, Raspberry PI]
---

In the previous months, I deployed Win IoT programs through Windows Device Portal. Because my Visual Studio could not find the remote device to do the deplyment and debug. It seems to be a bug in the previous Win 10 IoT version. My previous version was `15xxx`. So I used Windows Device Portal to deploy an application.

# Deploy through Windows Device Portal

You should be able to look up the information of your device through Windows Device Portal with a browser. The link is the address of your Raspberry PI, and the port is `8080`.

{% asset_img Portal.jpg Windows Device Portal %}

The application can be installed and controlled in `Apps -> Apps Manager`.

# Deploy via Visual Studio

After reinstalling Win 10 IoT to `v.10.0.17763.107`, the deployment via Visual Studio is normal.

{% asset_img SetPIN.jpg SET Pin %}

So, I set the PIN for debugging in Windows Device Portal. Everything works well:

{% asset_img Debug.jpg Debug %}

To do this, you just need to right click on the project, then choose `Properties`.

In the `Debug` tab, input the IP address of your Raspberry PI, choose `General` as authentification. If needed, input the PIN you've set.

{% asset_img Conf.jpg Configuration %}

Enjoy!
