---
title: 在 Ubuntu 18.04 构建 Intelligent Input Bus (IBus)
date: 2020-02-29 10:40:00
tags:
- IBus
- Ubuntu
categories:
- [Build]
---

# 简介

Intelligent Input Bus，简称IBus，是 Unix-like 操作系统下的多语输入法平台。因为它采用了总线（Bus）式的架构，所以命名为Bus。

在东北亚开源软件（OSS）论坛第3工作小组提出的《输入法引擎服务提供者界面规格》（Specification of IM engine Service Provider Interface）草案里，能实现以 Bus 为核心的架构被建议采用。SCIM-1.4 的架构并不被看好，因为它是用 C++ 开发的，因此常常会有C++应用二进制接口不符合的情况发生。

从那时起，一些人开始着手开发下一代的输入法平台，像是苏哲领导的IM-Bus，以及胡正的SCIM-2，可惜的是它们的开发进度仍然停滞不前。因此，时任红帽（现任谷歌）的黄鹏开始用 Python 开发 IBus 以实现 IM-Bus 提出的构想。IBus 并不完全实现东北亚 OSS 论坛所建议的函数，而是采用D-Bus及Glib来实做。尽管如此，IBus 已经开始被 OSS 社群所接受，FreeBSD 以及各大 Linux 发行版 如 Fedora、Ubuntu 已经将 IBus 纳入其包库里。在 Fedora 11 里，IBus 已经成为默认的多语输入平台。

IBus 是用 C 及 Python 开发的，如此可以避免 C++ ABI transition 问题。IBus 主要透过下列三种服务(Service)来提供功能：

- 输入法引擎服务：为输入法本身。
- 配置服务：管理IBus以及输入法的设置选项。
- 控制面板服务：提供诸如语言条，候选字菜单等用户界面。

IBus 使用 D-Bus 作 ibus-daemon服务，以及 IM客户端（像是konsole, gedit, firefox)之间的沟通。 ibus-daemon 透过接受服务登录，以及发送 D-Bus 消息来管理服务及IM客户端。IBus支持 XIM 协议及 Gtk IM 模块以及 Qt IM 模块。

项目托管在 GitHub IBus 组织下 [https://github.com/ibus/ibus](https://github.com/ibus/ibus)。

# 构建

首先，获取最新的源代码，并进入其目录：

```shell
git clone https://github.com/ibus/ibus.git
cd ibus
```

目前这里使用的是 master 分支上的代码，有时该分支可能并不稳定。可以使用一个 release 分支或标签的代码来构建，以避免一些奇怪的错误。这里我使用 1.5.y 分支的代码：

```shell
git checkout -b 1.5.y origin/1.5.y
```

使用脚本调用 auto configure 工具链，来生成 Makefile 文件

```shell
./autogen.sh --prefix=/usr --sysconfdir=/etc
```

这时，如果有错误，说明有些依赖并没有被安装在系统里，需要用户手动安装，请看[依赖章节](#依赖)。

如果一切正常，我们就可以用 make 进行构建和安装了：

```shell
make && sudo make install
```

如果构建失败，请对照[构建时依赖相关问题](#构建时依赖相关问题)。

完成之后运行一下：

```shell
ibus-setup
```

在 IBus 的代码里，有一个 simple engine 输入引擎服务，它不提供任何真实的输入功能，只是把桌面环境支持的各种键盘布局显示出来，我们可以用它检测 IBus 是否成功构建：

{% asset_img ibus-setup.jpg 运行预览 %}

若没有这些键盘布局，可能 ibus-daemon 出了些问题，尝试运行：

```shell
ibus-daemon
```

在[运行时依赖相关问题](#运行时依赖相关问题)中有一些我遇到的问题，可供参考。

之后就可以构建想用的输入服务了。据官方文档，目前的引擎有：

- ibus-anthy: 日文输入法。
- ibus-array: 行列输入法
- ibus-bopomofo: 使用注音符号的拼音输入法，基于ibus-pinyin引擎开发，但输入方式与一般标准智能形注音输入法（如新酷音输入法或微软新注音）不同。
- ibus-chewing: 新酷音输入法，智能形注音输入法。
- ibus-hangul: 韩文输入法。
- ibus-kkc：日文假名汉字转换输入法。
- ibus-m17n: 使用m17n-db的多语输入法。
- ibus-pinyin: 拼音输入法，为IBus主要开发者所开发。
- ibus-libpinyin: 是 Red Hat 工程师主导、基于 n-gram 语言模型的集成性泛拼音输入法引擎。
- ibus-libzhuyin: 与 ibus-libpinyin 系出同源，支持注音符号输入，名为“新注音”(New Zhuyin) 输入法，是智能形的注音输入法。
- ibus-table: 码表输入引擎。
- ibus-googlepinyin: Google拼音输入法的ibus版本（这个并不是官方的Google输入法，而是由爱好者从Android项目上迁移过来）

# 依赖

最基础的依赖是 D-Bus 及其 Python 绑定，在 Ubuntu 里，这些以来应该是已经被预置在桌面版本的系统中了：

```
python >= 2.5
dbus-glib >= 0.74
dbus-python >= 0.83.0
```

官方文档还推荐安装`qt >= 4.4.0`，这是为了让 IBus 能和 Qt 的 IM 协作，这个依赖对于使用 Qt 的应用程序（如使用的桌面环境是KDE）来说是至关重要的。但在 Ubuntu 18.04 中， Gnome 被作为默认的桌面环境，因此，可以根据自己的需要来配置。

# 构建时依赖相关问题

根据我的经历，以下这些是我在 Ubuntu 18.04 上配置期间遇到的问题：

- 配置期间，提示未找到 gnome-autogen.sh：安装 gnome-common
- 配置期间，提示未找到 gtk-doc：安装 gtk-doc
- 配置期间，提示未找到 gtk+-2.0：安装 libgtk2.0-dev
- 配置期间，提示未找到 gtk+-3.0：安装 libgtk-3-dev
- 配置期间，提示未找到 dconf：安装 libdconf-dev
- 配置期间，提示未找到 emoji-test.txt：安装 unicode-data
- 配置期间，提示未找到 annotations/en.xml：安装 unicode-cldr-core
- 配置期间，提示未找到 unicode/ucd/NamesList.txt：创建一个符号链接 unicode/NamesList.txt -> unicode/ucd/NamesList.txt (unicode-data 包已安装)
- 配置期间，提示未找到 unicode/ucd/Blocks.txt：创建一个符号链接 unicode/Blocks.txt -> unicode/ucd/Blocks.txt (unicode-data 包已安装)
- 编译期间，提示未找到 valac：安装 valac-0.40-vapi, valac-0.40-dev
- 编译期间，提示 Vala bindings require Gobject Introspection：安装 libgirepository1.0-dev

# 运行时依赖相关问题

## ibus_serializable_serialize_object 符号未找到

我在运行 ibus-daemon 时遇到了 `Not found symbol ibus_serializable_serialize_object` 的报错。
根据分析，是 libibus-1.0.so 被安错了地方：
ibus-daemon 链接到 `/usr/lib/x86_64-linux-gnu/libibus-1.0.so.5`，这个文件是个符号链接，指向真正的 so 文件。而在我的电脑它指向了上之前的包管理器安装的 so 版本，于是就出现 ABI 不兼容的问题，提示找不到 symbol。
根据 log，安装脚本里的确安装了新版本的 so 并且处理了指向，只是它被安在了 `/usr/lib`。于是我把 `/usr/lib/x86_64-linux-gnu/libibus-1.0.so.5` 指向改为了新安装的 so 文件，再次运行，一切正常。
