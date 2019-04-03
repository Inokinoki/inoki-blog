---
title: 【译】 从源代码构建 deb 包
date: 2019-04-02 21:08:00
update: 2019-04-03 12:33:00
tags:
- Pack
- Debian
- 中文
- 翻译
categories:
- [Package, Debian]
---

原文链接: [https://wiki.debian.org/Packaging/Intro](https://wiki.debian.org/Packaging/Intro)

# Debian 打包介绍

本文是一个关于如何制作 Debian 包的介绍性教程，它不会对 Debian 打包系统中的复杂概念深入介绍，但它介绍了能够为简单软件制作 Debian 包的方法。
出于这个目的，我们只使用来自于 `debhelper 9` 的 `dh` 命令。

# 需求

这个教程假设您已：
- 理解二进制包的安装过程；
- 了解命令行的使用，并且使用您偏爱的文本编辑器编辑文本文件；

技术要求：
- build-essential
- devscripts
- debhelper version 9 或更高版本

# 三个核心概念

三个最核心的概念为：
- 上游原始代码包（upstream tarball）:
    - 通常，人们为上游开发者（通常为第三方）编写的软件打包。
    - 上游开发者会使用源代码归档软件或原始代码包的方式发放他们的软件。
    - 原始代码包一般是上游制作的 `.tar.gz` 或 `.tgz` 文件，它也可能被压缩成 `.tar.bz2`，`.tb2` 或 `.tar.xz` 格式。原始代码包就是 Debian 构建包时使用的原材料。
- 源码包：
    - 当您拥有了上游制作的原始代码包，下一步就可以制作 Debian 源码包了。
- 二进制包：
    - 从源码包您可以构建 Debian 二进制包，它才是是实际上会被安装的包。

最简单的源码包由3个文件组成：

- 上游原始代码包，需要被重命名来符合一个特定的模式。
- 一个 debian 目录，带有所有上游源代码的更改记录，外加所有为 Debian 打包系统生成的所有文件。这种包拥有 `.debian.tar.gz` 的文件名。
- 一个描述文件（以 `.dsc` 结尾），罗列了其他两个文件。

听起来有些过于复杂，人们的第一印象是：所有东西都放在一个文件里会更简单。然而，保持上游代码包与 Debian 特定更改分离可以节省大量磁盘空间和带宽。对 Debian 来说，追踪必要的修改也更加简单。

# 打包工作流
打包工作流通常如下表所示：

1. 重命名上游代码包
2. 解压缩上游代码包
3. 添加 Debian 打包文件
4. 构建这个包
5. 安装这个包

之后您就可以在您的电脑上测试它了。

源码包和二进制包都可以被上传到 Debian。

为了这个教程，我们使用这个代码包：[hithere](https://wiki.debian.org/Packaging/Intro?action=AttachFile&do=view&target=hithere-1.0.tar.gz)

## 第一步：更改上游代码包名称

Debian 打包系统假定上游代码包拥有一个十分特殊的名字，必须遵守一个特定的模式。它的名字由源代码包名、一个下划线、上游版本号组成，最后以`.orig.tar.gz` 组成。源代码包应当全部使用小写字母，并且包含字母、数字、符号，一些其他的字符也可以出现。

如果上游开发者使用了一个很好的 Debian 源代码包名，您可以直接使用。否则，请尽可能小的对名称进行改动以适应 Debian。在我们的情况下，上游开发者已经选取了一个很好的名字：“hithere”了，所以我们无需担心。我们应当最终使用 `hithere_1.0.orig.tar.gz` 作为上游代码包的名称。请注意，这里我们使用了一个下划线，而不是“-”，因为打包工具极其吹毛求疵。

```bash
$ mv hithere-1.0.tar.gz hithere_1.0.orig.tar.gz
```

## 第二步：解压缩上游代码包

通常情况下，源代码会进入一个以包名和上游版本号命名的目录中（使用连接符连接，而不是下划线），因此理想状况下我们使用的上游代码包会被解压缩到一个叫做`hithere-1.0` 的目录中。打包工具仍旧挑剔，因此我们必须这样做。

```bash
$ tar xf hithere_1.0.orig.tar.gz
```

## 第三步：添加 Debian 打包文件

以下所有文件都在源码树的 `debian/` 子目录中。

```bash
$ cd hithere-1.0
$ mkdir debian
```

我们需要提供不少文件，让我们按顺序来看。

### debian/changelog
第一个文件是 `debian/changelog`，这个是记录 Debian 包变化的日志文件。它无需罗列出上游代码的每一个改变，只要它能帮助用户总结这些变化即可。我们在制作第一个版本，所以这里应当什么都没有。然而，我们仍需制作一个变化日志的入口，因为打包工具会从日志里读取特定信息。最重要的是它会读取包的版本。

`debian/changelog` 拥有一个十分特殊的格式。最简单的创建方式就是使用 `dch` 工具。
```bash
$ dch --create -v 1.0-1 --package hithere
```

会在文件中产生以下内容：
```
hithere (1.0-1) UNRELEASED; urgency=low

  * Initial release. (Closes: #XXXXXX)

 -- Lars Wirzenius <liw@liw.fi>  Thu, 18 Nov 2010 17:25:32 +0000
```

这里有很多注意点：

`hithere` 部分必须与源代码包的名字相同。`1.0-1` 是版本号，`1.0` 部分是上游版本号。`-1` 部分是 Debian 的版本：它是第一个上游版本为 `1.0` 的 Debian 包。如果这个 Debian 包有错误，并且被修复了，那么上游版本号仍保持相同，下一个版本应当被叫做 `1.0-2`，接下来是 `1.0-3`，依此类推。

UNRELEASED 被称作上传目标。它会告诉上传工具这个二进制包应当被上传到哪里。UNRELEASED 意味着这个包还没有做好上传的准备。保持 UNRELEASED 是一个好主意，以避免您错误上传它。

目前请先忽略 `urgency=low`。

`(Closes：#XXXXXX)` 作用在于上传包时关闭错误。这是在 Debian 中关闭错误的常用方法：当上传修复错误的包时，错误跟踪器会注意到这一点，并将错误标记为已关闭。我们可以删除 `(Closes...)` 位。或者不管它，现在它不重要。

更改日志中的最后一行指出是谁在何时制作了这个版本的软件包。`dch` 工具会尝试猜测名称和电子邮件地址，但您应当使用正确的详细信息对其进行配置。详细信息，请参阅 `dch(1)` 手册页。

### debian/compat

`debian/compat` 明确 `debhelper` 工具的兼容等级。我们目前不需要知道它意味着什么。
```
10
```

### debian/control
控制文件描述代码和二进制包，并给出他们的详细信息，比如名称、包的维护者是谁，等等。下面是一个示例：
```
Source: hithere
Maintainer: Lars Wirzenius <liw@liw.fi>
Section: misc
Priority: optional
Standards-Version: 3.9.2
Build-Depends: debhelper (>= 9)

Package: hithere
Architecture: any
Depends: ${shlibs:Depends}, ${misc:Depends}
Description: greet user
 hithere greets the user, or the world.
```

在这个文件里有许多需求的字段，但是现在您可以像对待魔法一样对待它。那么，在 `debian/control` 中有两段文字。

第一段文字描述了源代码包，使用以下字段：

#### Source
源代码包名。
#### Maintainer
维护者的姓名和电子邮箱。
#### Priority
包的重要性（'required 可选的', 'important 重要的', 'standard 标准' 或 'optional' 其中之一）。通常，包是“可选”的，除非它对于标准系统功能是“必不可少的”，即启动或网络功能。 如果包与另一个“可选”包冲突，或者它不打算用于标准桌面安装，则应该是“额外”的而不是“可选”的。 “额外”包的显着例子是调试包。 （由Sebastian Tennant添加）。 
#### Build-Depends
需要安装以构建程序包的程序包列表。实际使用包时有可能需要它们。

第一个之后的所有段落都描述了从此源构建的二进制包。 可以有许多从同一来源构建的二进制包; 但对于我们的例子只有一个。 我们使用这些字段：
#### Package
二进制包的名称。 名称可能与源包名称不同。
#### Architecture
指定二进制包预期使用的计算机体系结构：用于32位Intel CPU的i386，用于64位的amd64，用于ARM处理器的armel等等。 Debian总共可以处理大约十几种计算机体系结构，因此这种体系结构支持至关重要。 “Architecture”字段可以包含特定体系结构的名称，但通常它包含两个特殊值中的一个。

any
（我们在示例中看到）意味着可以为任何体系结构构建包。 换句话说，代码是可移植的，因此它不会对硬件做太多假设。 但是，仍然需要为每个体系结构单独构建二进制包。

all
意味着相同的二进制包将适用于所有体系结构，而无需为每个体系结构单独构建。 例如，仅包含shell脚本的包将是“all”。 Shell脚本在任何地方都可以工作，不需要编译。

#### Depends
为了让二进制包中程序能够正常运行，需要安装的包列表。手动列出这些依赖项是繁琐且容易出错的工作。为了能够让其工作，我们需要一个神奇的小东西 `${shlibs:Depends}`。另一个神奇的东西是给 `debhelper` 的，它是 `${misc:Depends}`。shlibs 是为了动态链接库，而 misc 是为了 `debherlper` 的一些工作。对于别的依赖，您可以将其手动加入到 `Depends` 或 `Build-Depends` 中。但请注意，`${...}` 仅在 `Depends` 中有效。

#### Description
二进制包的完整描述。它希望对用户有所帮助。第一行用作简要概要（摘要）描述，其余部分是包的更长的描述。
命令 `cme edit dpkg` 提供了一个GUI能够用来编辑大多数打包文件，包括 `debian/control`。 请参阅使用 `cme` 页面管理 `Debian` 软件包。`cme`命令在 Debian 中的 `cme` 包中提供。您也可以使用 `cme edit dpkg-control` 命令仅编辑 `debian/control` 文件。

### debian/copyright
这是一个非常重要的文件，但是现在我们将先使用一个空文件。
对于 Debian ，此文件用于跟踪有关包的合法性、版权相关信息。但是，从技术角度来看，这并不重要。目前，我们将专注于技术方面。如果有兴趣，我们可以稍后再回到 `debian/copyright`。

### debian/rules
它应当长这个样：
```
#!/usr/bin/make -f
%:
        dh $@
```

**注意： 最后一行应当使用一个 Tab 字符进行缩进，而不使用空格。这个文件是一个 Makefile，因此 Tab 字符是 make 所期望的。**

事实上 `debian/rules` 可能是一个相当复杂的文件。然而，在 `debhelper 7` 中的 `dh` 命令让它可以在大多数情况下变得更简单。

### debian/source/format
最后一个我们需要的文件是 `debian/source/format`，它应当包含源代码包的版本号，这里为 `3.0 (quilt)`。
```
3.0 (quilt)
```

## 第四步：构建这个包
### 第一次尝试
现在我们可以构建这个包了。有很多我们可以使用的命令，但是我们只使用其中一个，如果您运行以下命令，您会得到像下面的输出：

```bash
$ debuild -us -uc
make[1]: Entering directory '/home/liw/debian-packaging-tutorial/x/hithere-1.0'
install hithere /home/liw/debian-packaging-tutorial/x/hithere-1.0/debian/hithere/usr/local/bin
install: cannot create regular file '/home/liw/debian-packaging-tutorial/x/hithere-1.0/debian/hithere/usr/local/bin': No such file or directory
make[1]: *** [install] Error 1
make[1]: Leaving directory '/home/liw/debian-packaging-tutorial/x/hithere-1.0'
dh_auto_install: make -j1 install DESTDIR=/home/liw/debian-packaging-tutorial/x/hithere-1.0/debian/hithere returned exit code 2
make: *** [binary] Error 29
dpkg-buildpackage: error: fakeroot debian/rules binary gave error exit status 2
debuild: fatal error at line 1325:
dpkg-buildpackage -rfakeroot -D -us -uc failed
```

有些地方不太对劲。这经常发生：您已经尽力创建了符合规范的 `debian/*` 文件了，但是仍有一些东西不太对劲。可见，出错的地方在：
```
install hithere /home/liw/debian-packaging-tutorial/x/hithere-1.0/debian/hithere/usr/local/bin
```
上游代码中的 Makefile 尝试将程序安装到错误的地方。

这边有许多可以做的事情，来解决这个问题：第一件事是 Debian 打包系统如何工作。

### 修正
当程序被构建并被“安装”时，通常情况下，它还不会被安装到 `/usr` 或者 `/usr/local`，而是被安装到 `debian/` 子目录。

我们在 `debian/hithere` 目录下创建了一个整个文件系统的子集，并将其打包进二进制包中。因此 `.../debian/hithere/usr/local/bin` 是没问题的，除非它不应当被安装到 `usr/local` 而是 `usr` 目录。我们需要做一些事情来确保程序被安装到正确的位置 `debian/hithere/usr/bin`。正确的方法是修改 `debian/rules` 文件来告诉 Makefile 应当在哪里安装软件。
```
#!/usr/bin/make -f
%:
        dh $@

override_dh_auto_install:
        $(MAKE) DESTDIR=$$(pwd)/debian/hithere prefix=/usr install
```

这个仍是一个小魔法，为了理解它，您应当知道 Makefile 如何工作，还应当知道 `debhelper` 的不同阶段。

目前，我可以大概说明下：有一个名为 `debherlper` 的命令负责安装上游文件，这个阶段被称为 `dh_auto_install`。我们需要覆盖这个阶段，为此，我们在 `debian/rule` 中重写了 `override_dh_auto_install` 规则。这个文件的最后一行是一种1970年代的技术，为了从 `debian/rules` 中使用正确的参数调用上游中的 Makefile 文件。

让我们再试一下。

```bash
$ debuild -us -uc
```

仍然失败了！但这次失败的命令是：
```
install hithere /home/liw/debian-packaging-tutorial/x/hithere-1.0/debian/hithere/usr/bin
```

我们正在尝试将软件安装至正确的地方，但是这个目录不存在。为了修正这个错误，我们应当告诉打包工具先创建这个目录。

理想状况下，上游 Makefile 文件会自动创建目录，但这种情况下，是上游开发者太懒惰了，他没有创建这个目录。

### 另一个修正
打包工具（特别是`debhelper`）提供了一种实现方式。创建一个名为 `debian/hithere.dirs` 的文件，里面的内容应当是：
```
usr/bin
usr/share/man/man1
```

第二行创建了一个给手册页面的目录。之后我们会需要它。您应当小心的维护这样的文件，因为它可能会导致您的包在未来版本产生空目录，当包中的项目不再有效时。

让我们再试一下：
```bash
$ debuild -us -uc
```

现在构建成功了，但是仍有一些小问题。`debuild` 运行了 `lintian` 工具，这个工具可以检测构建的包的一些常见的错误，它给出了我们创建的包的一些错误：
```
Now running lintian...
W: hithere source: out-of-date-standards-version 3.9.0 (current is 3.9.1)
W: hithere: copyright-without-copyright-notice
W: hithere: new-package-should-close-itp-bug
W: hithere: wrong-bug-number-in-closes l3:#XXXXXX
Finished running lintian.
```
这些错误应当被修正，但是对我们来说它们不会导致错误。现在我们先忽略他们。查看父目录，您可以找到构建好的包。
```bash
$ ls ..
hithere-1.0                  hithere_1.0-1_amd64.deb  hithere_1.0.orig.tar.gz
hithere_1.0-1_amd64.build    hithere_1.0-1.debian.tar.gz
hithere_1.0-1_amd64.changes  hithere_1.0-1.dsc
```

## 第五步：安装构建好的包
接下来的命令会安装您构建好的包。**不要**在计算机上直接运行它，除非您不介意损坏系统。

通常情况下，在备份好的计算机上进行包开发是最好的，这样，在所有事情变糟糕的情况下，您可以不用完全安装整个系统。虚拟机是一个不错的进行开发的地方。
```bash
$ sudo dpkg -i ../hithere_1.0-1_amd64.deb

[sudo] password for liw:
Selecting previously deselected package hithere.
(Reading database ... 154793 files and directories currently installed.)
Unpacking hithere (from ../hithere_1.0-1_amd64.deb) ...
Setting up hithere (1.0-1) ...
Processing triggers for man-db ...
liw@havelock$
```

那么，如何测试打好的包呢？我们可以运行命令：
```bash
$ hithere
```

OK 了！

但现在并不完美。记得 lintian 还有一些事情涵待解决，`debian/copyright` 仍然是空的，等等。我们现在有了一个可以运行的 deb 包了，但是它还并不是我们所期待的高质量的 Debian 包。

# 结论

一旦您构建了您自己的包，自然而然地，您会想要知道如何设置您自己的 apt 仓库，这样您自己的包会很容易被安装。我所知道的最好的工具是 `reprepro`。为了更多的测试您的包，您可能也会想要了解 `piuparts`。原作者编写的这个工具，他觉得这个工具很棒并且没有任何 bug ！

最后，如果您开始修改上游代码，您可能想要了解一下 quilt 工具。

其他您可能想要阅读的信息可以在 [http://www.debian.org/devel/](http://www.debian.org/devel/) 页面找到。