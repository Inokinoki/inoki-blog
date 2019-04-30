---
title: Build Go for Newifi 2 (D1) router
date: 2019-04-30 13:41:40
tags:
- Cross Compile
- Router
- Go
categories:
- [Embedded System, Cross Compile, Router]
---

This post will give you a guide to build Go on no matter which system.

# Prerequisite
1. After Go 1.5, all the source codes are written in Go or Assembly. So in a system where there is a Go install, we can build another Go using Go itself. The feature is called **bootstrapping**.
2. With `GOOS` and `GOARCH` flag, we can build Go program for given platform with given architecture. This is cross compile of Go.

So, it's possible to build a Go environment for my Lenovo Newifi 2 (D1), which is based on OpenWRT, equiped with MIPS Little Endian MT7621AT processor, 256MB memory.

But I want to keep the official firmware, so I decided to build an independant build of Go for my router.

# Preparing
Get your Go>=1.5 installed in your system:
```bash
> which go
/usr/bin/go
> go version
go version go1.10.4 linux/amd64
```

If you don't have Go installed, please install it with your current package manager. 
For Ubuntu, 
```bash
> sudo apt-get install golang-go
```

Get Golang source code from [the downloads page](https://golang.org/dl/).

I chose to use Golang 1.12.4:
```bash
> wget https://dl.google.com/go/go1.12.4.src.tar.gz
```

# Building
Decompress the tarball:
```bash
> tar xvf go1.12.4.src.tar.gz
```

We'll have a directory like this:
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

Enter `src` directory.
Begin directly your build for mipsle:
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

# Installing
After the building, copy the following folders to the router:
```
api   
bin   
misc  
pkg   
src   
test
```

For example, I created `/mnt/mmcblk0p1/usr/share/go` folder for them. 

Then move `go` and `gofmt` from `bin/mipsle` to `bin`.

Add `GOROOT` to environment variables and `bin` to PATH:
```
> export GOROOT=/mnt/mmcblk0p1/usr/share/go
> PATH=$GOROOT/bin:$PATH
```

# Run your first Go program
Create the Hello World code in `test.go`:
```go
package main
import (
        "fmt"
)

func main() {
       fmt.Println("hello newifi2")
}
```

Run it:
```bash
> go run test.go
hello newifi2
```
or build and run it:
```bash
> go build test.go
> ./test
hello newifi2
```

Enjoy your journal with Go on your router!
