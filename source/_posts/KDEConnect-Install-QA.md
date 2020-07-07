---
title: KDE Connect 安装 Q&A
date: 2020-07-07 23:33:33
tags:
- KDE Connect
categories:
- KDE Connect
- 中文
---

这篇文章记录了 QQ 群中回答的一些安装配置方面的问题。

群号码：668331167 或点击链接加入群聊[【KDE Connect 中文交流群】](https://jq.qq.com/?_wv=1027&k=0rBiLpax)

# Windows

## 安装后无法运行问题

https://bugs.kde.org/show_bug.cgi?id=412665

文件：`bin/data/dbus-1/services/org.kde.kdeconnect.service`

把这个文件里面的Exec原本的 `C:/CraftRoot/bin/kdeconnectd` 改成 `<你的安装路径>/bin/kdeconnectd` 或 `kdeconnectd`。

## 32 位系统

暂时无解，请等待 KDE 的打包系统更新。

## 同步 Win 的通知

现在桌面版读取通知仅限 KDE plasma 下可用。

## 传多个文件

它实际上是去开了 kdeconnect-handler，把文件路径当参数传进去，但是估计实现不好，把多个文件路径当作一个了，就出 bug。

可以在状态栏图标那右键选 send files，然后再多选。

# Linux

## Ubuntu/Debian

### “演讲指针”插件崩溃

前几天有朋友反馈，在 kubuntu 下的使用“演讲指针”插件存在崩溃的问题，是因为缺一个运行时依赖，可以这样解决：

```
sudo apt-get install qml-module-qtquick-particles2
```

Ubuntu 和 Kubuntu 应该是相似的 apt 源，可能也存在类似的问题

## Deepin

### 系统自带版本

西班牙人维护的软件源里面有 1.0 版本的 indicator-kdeconnect 和 kdeconnect 本体。

需要的话在安装软件源之后可以安装：

```
sudo apt update
sudo apt install kdeconnect
sudo apt install indicator-kdeconnect
```

## Flatpak

先安上flatpak，debian/ubuntu/deepin 可以直接

```
sudo apt install flatpak
```

添加官方 flathub 源（需挂梯子）：

```
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

添加 KDE 官方依赖的 flatpak 源

```
flatpak remote-add kdeapps http://distribute.kde.org/kdeapps.flatpakrepo
```

在安装之后执行这个命令，允许 KDE Connect 访问下载文件夹：

```
sudo flatpak override --filesystem=xdg-download org.kde.kdeconnect
```

电脑发送文件还有问题【待修复】—— xdg-portal-desktop 版本太老，[读写文件的 bug ](https://github.com/flatpak/xdg-desktop-portal/issues/141)确认至少在 0.11 版就已经被修复了。可以尝试安装新版 xdg-portal-desktop 修复。

卸载

```
flatpak uninstall org.kde.kdeconnect
```

## GSConnect

https://extensions.gnome.org/extension/1319/gsconnect/

# Android

## Android 10 剪贴板

Android 10 不让后台应用访问剪贴板了，新版本可以从通知栏主动发送剪贴板内容。

## Android 无法接收到文件

如果是 Android 10 的话需要预先配置好访问权限：

插件设置-》 FileSystem Expose

加上传输目录就行。

## MIUI

有人反映过有些文件传输问题。。。

# macOS

## 翻译问题

在中文系统下界面目前没有翻译。

## macOS 主动查找设备问题

发现一个 macOS 版本的 bug，mac 无线网络不支持 1500 以上的 MTU，所以发不出 UDP 广播识别包。

解决方法:从手机端刷新，找到 Mac 并连接配对😂

## 配置页面不在最前

配置了不让 KDE Connect 的图标在 Dock 栏显示的副作用。
如果有需要的话，可以把 `kdeconnect-indicator.app/Contents/Info.plist` 里的

```xml
<key>LSUIElement</key>
<string>1</string>
```

删掉，就可以在最上层打开窗口了，但是相应的 KDE Connect 的图标会在 Dock 中显示。

# Chrome OS

## Android 子系统自带 NAT

我才发现 chrome OS 也能用（Android 版的），但是因为有层 NAT，需要添加IP+从 Chrome OS 里发起配对请求😂

# 系统无关

## 梯子相关

    Chien：你梯子的规则可能没设置好，绕过局域网和大陆地址比较好。国情国情，国内网络环境太复杂了

解决方案：

1. 先检查是否挂了梯子
2. 请在梯子的例外列表添加 KDE Connect
3. 或在白名单添加路由器内网


## 微信通知无法同步

TIM 可以，QQ 可能可以，微信通知不完全走系统通知，目前还有问题。
