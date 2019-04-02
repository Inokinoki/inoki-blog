---
title: 【译】 从源代码构建 deb 包
date: 2019-04-02 21:08:00
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

The hithere part MUST be the same as the source package name. 1.0-1 is the version. The 1.0 part is the upstream version. The -1 part is the Debian version: the first version of the Debian package of upstream version 1.0. If the Debian package has a bug, and it gets fixed, but the upstream version remains the same, then the next version of the package will be called 1.0-2. Then 1.0-3, and so on.

UNRELEASED is called the upload target. It tells the upload tool where the binary package should be uploaded. UNRELEASED means the package is not yet ready to be uploaded. It's a good idea to keep the UNRELEASED there so you don't upload by mistake.

Ignore urgency=low for now. Just keep it there.

The (Closes: #XXXXXX) bit is for closing bugs when the package is uploaded. This is the usual way in which bugs are closed in Debian: when the package that fixes the bug is uploaded, the bug tracker notices this and marks the bug as closed. We can just remove the (Closes...) bit. Or not. It doesn't matter right now.

The final line in the changelog tells who made this version of the package, and when. The dch tool tries to guess the name and e-mail address, but you can configure it with the right details. See the dch(1) manual page for details.
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
The list of packages that must be installed for the program in the binary package to work. Listing such dependencies manually is tedious, error-prone work. To make this work, the ${shlibs:Depends} magic bit needs to be in there. The other magic stuff is there for debhelper. The ${misc:Depends} bit. The shlibs magic is for shared library dependencies, the misc magic is for some stuff debhelper does. For other dependencies, you need to add them manually to Depends or Build-Depends and the ${...} magic bits only work in Depends

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

<!> Note: The last line should be indented by one TAB character, not by spaces. The file is a makefile, and TAB is what the make command wants

debian/rules can actually be quite a complicated file. However, the dh command in debhelper version 7 has made it possible to keep it this simple in many cases.

### debian/source/format
The final file we need is debian/source/format, and it should contain the version number for the format of the source package, which is "3.0 (quilt)".

```
3.0 (quilt)
```

## Step 4: Build the package
First try
Now we can build the package.

There are many commands we could use for this, but this is the one we'll use. If you run the command, you'll get output similar to this:

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

Something went wrong. This is what usually happens. You do your best creating debian/* files, but there's always something that you don't get right.

So, the thing that went wrong is this bit:


install hithere /home/liw/debian-packaging-tutorial/x/hithere-1.0/debian/hithere/usr/local/bin

The upstream Makefile is trying to install the compiled program into the wrong location.

There are a couple of things going on here: first is a bit about how Debian packaging works.

Correction
When the program has been built, and is "installed", it does not get installed into /usr or /usr/local, as usual, but somewhere under the debian/ subdirectory.

We create a subset of the whole file system under debian/hithere, and then we put that into the binary package. So the .../debian/hithere/usr/local/bin bit is fine, except that it should not be installing it under usr/local, but directly under usr.

We need to do something to make it install into the right location (debian/hithere/usr/bin).

The right way to fix this is to change debian/rules so that it tells the Makefile where to install things.

```
#!/usr/bin/make -f
%:
        dh $@

override_dh_auto_install:
        $(MAKE) DESTDIR=$$(pwd)/debian/hithere prefix=/usr install
```

It's again a bit of magic, and to understand it you'll need to know how Makefiles work, and the various stages of a debhelper run.

For now, I'll summarize by saying that there's a command debhelper runs that takes care of installing the upstream files, and this stage is called dh_auto_install.

We need to override this stage, and we do that with a rule in debian/rules called override_dh_auto_install.

The final line in the new debian/rules is a bit of 1970s technology to invoke the upstream Makefile from debian/rules with the right arguments.

Let's try again

```bash
$ debuild -us -uc
```

It still fails!

This time, this is the failing command:

```
install hithere /home/liw/debian-packaging-tutorial/x/hithere-1.0/debian/hithere/usr/bin
```

We are now trying to install into the right place, but it does not exist. To fix this, we need to tell the packaging tools to create the directory first.

Ideally, the upstream Makefile would create the directory itself, but in this case the upstream developer was too lazy to do so.

Another correction
The packaging tools (specifically, debhelper) provide a way to do that.

Create a file called debian/hithere.dirs, and make it look like this:
```
usr/bin
usr/share/man/man1
```

The second line creates the directory for the manual page. We will need it later. You should be careful to maintain such *.dirs files because it can lead to empty directories in future versions of your package if the items listed in those files aren't valid any more.

Let's try once more

```bash
$ debuild -us -uc
```

Now the build succeeds, but there's still some small problems.

debuild runs the lintian tool, which checks the package that has been built for some common errors. It reports several for this new package:

```
Now running lintian...
W: hithere source: out-of-date-standards-version 3.9.0 (current is 3.9.1)
W: hithere: copyright-without-copyright-notice
W: hithere: new-package-should-close-itp-bug
W: hithere: wrong-bug-number-in-closes l3:#XXXXXX
Finished running lintian.
```

These should eventually be fixed, but none of them look like they'll be a problem for trying the package. So let's ignore them for now.

Look in the parent directory to find the package that was built.

```bash
$ ls ..
hithere-1.0                  hithere_1.0-1_amd64.deb  hithere_1.0.orig.tar.gz
hithere_1.0-1_amd64.build    hithere_1.0-1.debian.tar.gz
hithere_1.0-1_amd64.changes  hithere_1.0-1.dsc
```

## Step 5: Install the package
The following command will install the package that you've just built.

Do NOT run it on a computer unless you don't mind breaking it.

In general, it is best to do package development on a computer that is well backed up, and that you don't mind re-installing if everything goes really badly wrong.
Virtual machines are a good place to do development.

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

How do we test the package? We can run the command.

```bash
$ hithere
```

OK 了！

但现在并不完美。记得 lintian 还有一些事情涵待解决，`debian/copyright` 仍然是空的，等等。我们现在有了一个可以运行的 deb 包了，但是它还并不是我们所期待的高质量的 Debian 包。

# 结论

一旦您构建了您自己的包，自然而然地，您会想要知道如何设置您自己的 apt 仓库，这样您自己的包会很容易被安装。我所知道的最好的工具是 `reprepro`。为了更多的测试您的包，您可能也会想要了解 `piuparts`。原作者编写的这个工具，他觉得这个工具很棒并且没有任何 bug ！

最后，如果您开始修改上游代码，您可能想要了解一下 quilt 工具。

其他您可能想要阅读的信息可以在 [http://www.debian.org/devel/](http://www.debian.org/devel/) 页面找到。