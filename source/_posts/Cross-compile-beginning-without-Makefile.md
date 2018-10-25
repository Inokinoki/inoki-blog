---
title: Cross compile beginning without Makefile
date: 2018-10-25 02:42:40
tags:
- Cross Compile
- Router
- openwrt
categories:
- [Embedded System, Cross Compile, Router]
---

For building a cross compiling system for my router Newifi D1\(2nd Generation\), I tried crosstools-ng.

In ``Ubuntu 18.04``, because of the version of perl, the environment cannot be built correctly with ``ct-ng build`` after the configuration.

I will not talk about the error here. In fact, the error has been fixed in the pull request [Pull 1043](https://github.com/crosstool-ng/crosstool-ng/pull/1043).As the latest version is ``crosstool-ng-1.23.0`` released at Apr 20, 2017. We can do nothing except waiting \(although we can build the tool manually, it's better to wait for an officiel release\).

We come back for the theme.

The CPU of my router is ``mt7621a``, and the system is based on ``openwrt Barrier Breaker``. The architecture of this CPU is ``mipsel 32``.

We can download [openwrt toolchain for mipsel](http://archive.openwrt.org/barrier_breaker/14.07/ramips/mt7620a/OpenWrt-Toolchain-ramips-for-mipsel_24kec+dsp-gcc-4.8-linaro_uClibc-0.9.33.2.tar.bz2) and decompress it.

The compiler is based on ``toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_uClibc-0.9.33.2/bin``.

To test, we create a simple hello world:
```c
#include <stdio.h>

int main()
{
	printf("Hello World\n");
	return 0;
}
```

Compile it:
```bash
toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_uClibc-0.9.33.2/bin/mipsel-openwrt-linux-gcc helloworld.c -o helloworld
```

Upload it:
```bash
scp helloworld root@192.168.99.1:/
```

We connect to the router with ``ssh`` and test it:
```bash
>./hello
Hello World
```

It works!
There will be a tutorial more advanced in some days.

