---
title: Install Linux QQ on ChromeOS
date: 2019-12-08 22:38:00
tags:
- Chrome OS
categories:
- Chrome OS
---

Recently, Tencent has updated and released their out-of-date QQ client for Linux, on their [official Linux QQ website](https://im.qq.com/linuxqq/download.html).

Meanwhile, Chrome OS has already an experimental feature: `Linux subsystem`, which is equipped with a Linux distro named Penguin, under Debian. So, installing the full-featured desktop QQ on Chrome OS can be interesting.

# Get the right package

We can see that, there are several options on the download page. But which one should we choose ?

{% asset_img download-page.png Download page of Linux QQ %}

It depends on the architecture of your Chrome Book. We need to recognise it to choose the right version.

So, firstly, we need to check the archtecture.

## Architecture

Open your Linux terminal and run the `uname -m` command.

My output is like this:

```bash
> uname -m
x86_64
```

### Intel processor: x86_64

Here I have `x86_64`. If yours is same with mine, fortunately, we can directly download the `deb` in the `x64` line.

As well, if yours is `amd64` or `i686`, you should be able to use the same package. It means you have Intel/AMD x86 processor and the machine is running in 64 bit mode. If you have x86 processor, but you've got something like `i386`, you may have a wrong version Chrome OS. Please check it!

### ARM 64 bits processor: aarch64

If you've got one of these:

- aarch64
- arm64

You should be able to use `deb` in the `ARM64` line.

The string `arm64` was created by Apple for its 64 bits ARM processor. But it's not an official name of ARM 64 processors. Apple finally removed it and adopts `aarch64`, see [here](https://www.phoronix.com/scan.php?page=news_item&px=MTY5ODk). But maybe it's still being used by some machines somewhere.

So, if you have one of them, just choose one in the `ARM64` line.

### mips 64 bits, little endian processor: mips64el

If you've seen `mips64el`, unfortunately, you need choose the only version in the `MIPS64` line.

If you've seen only `mips`, you cannot use any version on that page. We don't have either the source code. So, explain to Tencent :)

## Format

The distro penguin is one based on Debain, so the easiest way is to download `deb` file.

But, considering the mips processor, some people may need use the shell script, because of missing of `deb`.

# Dependence

Before installing, we need prepare the dependence of it. It requires gtk 2.0 library to run the GUI.

On Debian distro like Penguin, just run

```bash
> sudo apt install libgtk2.0-0
```

Well done!

# Install

It's very simple to install it. Just open a terminal, and find the instruction for your format.

## deb

To install `deb` file, just run

```bash
> sudo dpkg -i linuxqq_1.0.1-b1-100_<arch>.deb
```

or

```bash
> sudo apt install -y /path/to/linuxqq_1.0.1-b1-100_<arch>.deb
```

## shell

To install shell, just run

```bash
> sudo ./linuxqq_1.0.1-b1-100_<arch>.sh
```

The script will create a tarball and extract it to your system.

# Run

Run `linuxqq` in the terminal or click on the icon in your Chrome OS to launch it.

{% asset_img wrong.jpg Problem of Linux QQ %}

# Problem of character displaying

You may see that in the picture, there are lots of characters which are not being shown correctly.

Because in the Linux distro, there is not chinese font to show them. We can install a chinese font to display them correctly.

```bash
> sudo apt-get install ttf-wqy-zenhei ttf-wqy-microhei
```

# Rerun

After installation, run it:

{% asset_img success.jpg Linux QQ %}

It's okay! Enjoy!
