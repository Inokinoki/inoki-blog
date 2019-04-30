---
title: Build Go for Newifi 2 (D1) router
date: 2019-04-30 13:41:40
tags:
- Cross Compile
- Router
- Go
- 中文
categories:
- [Embedded System, Cross Compile, Router]
- [Chinese]
---

通过阅读这篇文章您应当可以为任何系统构建 Go 语言。

# 先决条件
1. 从 Go 1.5 开始，Go 语言所有的源代码都使用了 Go 或者汇编语言。因此在一个安装有 Go 语言的系统中使用 Go 语言构建另一个 Go 语言版本会十分简单。这个特性叫做语言的**自举**。
2. 使用 `GOOS` 和 `GOARCH` 环境变量，我们可以为另一个平台和架构构建 Go 语言程序，这是 Go 的交叉编译特性。

因此，为我的 Lenovo Newifi 2(D2) 编译 Go 语言环境是可行的。这个路由器的官方固件基于 Openwrt，处理器为 MT7621AT，MIPS 架构小端序，配有 256M 内存。

我希望能保留官方固件而非刷机，因此我决定为我的路由器构建一个独立的 Go 语言版本。

# 准备
在您的系统上安装 Go>=1.5 版本:
```bash
> which go
/usr/bin/go
> go version
go version go1.10.4 linux/amd64
```

如果您没有安装 Go 语言，请使用您发行版的包管理器安装。对于 Ubuntu 来说 
```bash
> sudo apt-get install golang-go
```

从 [下载页面](https://golang.org/dl/) 获取 Go 语言源代码。
我使用了 Golang 1.12.4:
```bash
> wget https://dl.google.com/go/go1.12.4.src.tar.gz
```

# 构建
解压代码包:
```bash
> tar xvf go1.12.4.src.tar.gz
```

目录结构如下：
```
.
├── api
├── AUTHORS
├── CONTRIBUTING.md
├── CONTRIBUTORS
├── doc
├── favicon.ico
├── lib
├── LICENSE
├── misc
├── PATENTS
├── README.md
├── robots.txt
├── src
├── test
└── VERSION
```

进入 `src` 目录。开始您的构建：
```bash
> GOOS=linux GOARCH=mipsle GOROOT_BOOTSTRAP=<your-go-root> ./make.bash
Building Go cmd/dist using <your-go-path>/go-1.10.
Building Go toolchain1 using <your-go-path>/go-1.10.
Building Go bootstrap cmd/go (go_bootstrap) using Go toolchain1.
Building Go toolchain2 using go_bootstrap and Go toolchain1.
Building Go toolchain3 using go_bootstrap and Go toolchain2.
Building packages and commands for host, linux/amd64.
Building packages and commands for target, linux/mipsle.
---
Installed Go for linux/mipsle in <your-build-path>/go
Installed commands in <your-build-path>/go/bin
```

# 安装
构建完成后，将以下文件夹复制到路由器:
```
api   
bin   
misc  
pkg   
src   
test
```

比如，我创建了 `/mnt/mmcblk0p1/usr/share/go` 文件夹来存放它们。

紧接着，从 `bin/mipsle` 将 `go` 和 `gofmt` 移至 `bin`。

添加 `GOROOT` 环境变量，并添加 `bin` 到 PATH 中:
```
> export GOROOT=/mnt/mmcblk0p1/usr/share/go
> PATH=$GOROOT/bin:$PATH
```

# 运行您的第一个 Go 程序
在 `test.go` 创建 Hello World 代码:
```go
package main
import (
        "fmt"
)

func main() {
       fmt.Println("hello newifi2")
}
```

直接运行它:
```bash
> go run test.go
hello newifi2
```
或者构建+运行:
```bash
> go build test.go
> ./test
hello newifi2
```

一切 OK!
