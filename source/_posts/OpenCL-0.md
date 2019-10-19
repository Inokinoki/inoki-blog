---
title: OpenCL - Heterogeneous Computing (0)
date: 2019-10-18 22:29:40
tags:
- OpenCL
- Heterogeneous Computing
categories:
- OpenCL
---

OpenCL (Open Computing Language) is a framework for writing programs that execute across heterogeneous platforms consisting of central processing units (CPUs), graphics processing units (GPUs), digital signal processors (DSPs), field-programmable gate arrays (FPGAs) and other processors or hardware accelerators. OpenCL specifies programming languages (based on C99 and C++11) for programming these devices and application programming interfaces (APIs) to control the platform and execute programs on the compute devices. OpenCL provides a standard interface for parallel computing using task- and data-based parallelism.

This is the definition of OpenCL on Wikipedia. In this post, I'd like to do some research about the architecture in a brief view, based on Arch Linux. Arch Linux is chosen because of its clear software source, in which we can find out what exactly in a package for OpenCL components.

Here, we only talk about the type that runs on GPU.

# GPGPU

GPGPU is a notion standing **General-Purpose computing on Graphics Processing Units**. It's called `General Purpose` because through it, we will not use Graphics Processing Units to process graphics data. Instead, we'd like to use them as more general computing devices.

To achieve this, there are several frameworks proposed by different communities, organizations or companies. For example:
1. NVIDIA Cuda
2. ATI Stream
3. OpenCL

NVIDIA Cuda is proprietary and of course supported by NVIDIA. OpenCL is an open standard maintained by the non-profit technology consortium Khronos Group. But in face, the implementations rely on hardware/software providers.

The important stuff of the various implementations is OpenCL Runtime libraries, which are prerequisites of executing a program that uses OpenCL.

# OpenCL Runtime libraries

To be clarified, OpenCL Runtime libraries depend on hardware manufacturers. So, we should install the runtime libraries that match our hardwares.

For example, I have an Intel CPU along with integrated Intel GPU, and a NVIDIA GPU beside. So, what I need to use all GPU devices is just to install Intel GPU OpenCL runtime libraries and NVIDIA GPU OpenCL runtime libraries.

If you have an AMD GPU, or other types of devices, like an integrated FPGA(wow, you must be really professional), you should install the libraries provided by their manufacturers, or a compatible version.

On Arch Linux, `pacman` is used to install packages. There are not bad OpenCL runtime library packages in the repository:

```
AMD/ATI
    opencl-mesa: free runtime for AMDGPU and Radeon
    opencl-amdAUR: proprietary standalone runtime for AMDGPU (pal and legacy stacks in a single package)
    rocm-opencl-runtimeAUR: Part of AMD's fully open-source ROCm GPU compute stack, which supports GFX8 and later cards(Fiji, Polaris, Vega)
    opencl-amdgpu-pro-orcaAUR: proprietary runtime for AMDGPU PRO (supports legacy products older than Vega 10)
    opencl-amdgpu-pro-palAUR: proprietary runtime for AMDGPU PRO (supports Vega 10 and later products)
    opencl-catalystAUR: AMD proprietary runtime, soon to be deprecated in favor of AMDGPU
    amdapp-sdkAUR: AMD CPU runtime

NVIDIA
    opencl-nvidia: official NVIDIA runtime

Intel
    intel-compute-runtime: a.k.a. the Neo OpenCL runtime, the open-source implementation for Intel HD Graphics GPU on Gen8 (Broadwell) and beyond.
    beignet: the open-source implementation for Intel HD Graphics GPU on Gen7 (Ivy Bridge) and beyond, deprecated by Intel in favour of NEO OpenCL driver, remains recommended solution for legacy HW platforms (e.g. Ivy Bridge, Sandy Bridge, Haswell).
    intel-openclAUR: the proprietary implementation for Intel HD Graphics GPU on Gen7 (Ivy Bridge) and beyond, deprecated by Intel in favour of NEO OpenCL driver, remains recommended solution for legacy HW platforms (e.g. Ivy Bridge, Sandy Bridge, Haswell).
    intel-opencl-runtimeAUR: the implementation for Intel Core and Xeon processors. It also supports non-Intel CPUs.

Others
    poclAUR: LLVM-based OpenCL implementation
```

I'd like to install the one for NVIDIA, so I did

```
sudo pacman -S opencl-nvidia
```

We can see what are in the package from [Arch website](https://www.archlinux.org/packages/extra/x86_64/opencl-nvidia/).

```
    etc/
    etc/OpenCL/
    etc/OpenCL/vendors/
    etc/OpenCL/vendors/nvidia.icd
    usr/
    usr/lib/
    usr/lib/libnvidia-compiler.so
    usr/lib/libnvidia-compiler.so.435.21
    usr/lib/libnvidia-opencl.so
    usr/lib/libnvidia-opencl.so.1
    usr/lib/libnvidia-opencl.so.435.21
    usr/share/
    usr/share/licenses/
    usr/share/licenses/opencl-nvidia
```

There are some dynamic libraries for OpenCL with NVIDIA prefixes and a configuration file in `/etc/OpenCL/vendors`.

The configuration file in `etc/OpenCL/vendors/nvidia.icd` should be able to tell someone, that there is NVIDIA OpenCL runtime, and where it is. The file content is:

```
libnvidia-opencl.so.1
```

If you'd like also to use Intel GPU, install `intel-compute-runtime`. Files to be installed is below:

```
    etc/
    etc/OpenCL/
    etc/OpenCL/vendors/
    etc/OpenCL/vendors/intel.icd
    usr/
    usr/bin/
    usr/bin/ocloc
    usr/lib/
    usr/lib/intel-opencl/
    usr/lib/intel-opencl/libigdrcl.so
    usr/share/
    usr/share/licenses/
    usr/share/licenses/intel-compute-runtime/
    usr/share/licenses/intel-compute-runtime/LICENSE
```

You may notice that, there is nothing like `libnvidia-compiler` in Intel OpenCL Runtime. But it's not true, the fact is that the OpenCL compiler of Intel OpenCL runtime is installed in another library, [intel-graphics-compiler](https://www.archlinux.org/packages/community/x86_64/intel-graphics-compiler/). And, this package is a mandatory dependency of `intel-compute-runtime`.

You should be able to install other OpenCL runtime if you have other devices.

But it's not the end, we are not aiming at just "running" an OpenCL program, we aim at developing one.

# Develop Environment

Basically, OpenCL is for C/C++ development. To develop, at least we need header files and dynamic libraries.

The most used header file is `CL/cl.h`, which can be installed by installing [opencl-headers](https://www.archlinux.org/packages/extra/any/opencl-headers/) package, which will import other necessary headers as well.

```
    usr/
    usr/include/
    usr/include/CL/
    usr/include/CL/cl.h
    usr/include/CL/cl.hpp
    usr/include/CL/cl2.hpp
    usr/include/CL/cl_egl.h
    usr/include/CL/cl_ext.h
    usr/include/CL/cl_ext_intel.h
    usr/include/CL/cl_gl.h
    usr/include/CL/cl_gl_ext.h
    usr/include/CL/cl_platform.h
    usr/include/CL/cl_va_api_media_sharing_intel.h
    usr/include/CL/opencl.h
    usr/share/
    usr/share/licenses/
    usr/share/licenses/opencl-headers/
    usr/share/licenses/opencl-headers/LICENSE
```

And, the most import library is `libOpenCL.so`, which is in `ocl-icd` package.

```
    usr/
    usr/include/
    usr/include/ocl_icd.h
    usr/lib/
    usr/lib/libOpenCL.so
    usr/lib/libOpenCL.so.1
    usr/lib/libOpenCL.so.1.0.0
    usr/lib/pkgconfig/
    usr/lib/pkgconfig/OpenCL.pc
    usr/lib/pkgconfig/ocl-icd.pc
    usr/share/
    usr/share/doc/
    usr/share/doc/ocl-icd/
    usr/share/doc/ocl-icd/examples/
    usr/share/doc/ocl-icd/examples/ocl_icd_bindings.c
    usr/share/doc/ocl-icd/html/
    usr/share/doc/ocl-icd/html/libOpenCL.html
    usr/share/licenses/
    usr/share/licenses/ocl-icd/
    usr/share/licenses/ocl-icd/COPYING
    usr/share/man/
    usr/share/man/man7/
    usr/share/man/man7/libOpenCL.7.gz
    usr/share/man/man7/libOpenCL.so.7.gz
```

The full name of this package is **OpenCL Installable Client Driver**. It's a mechanism to allow developers to build applications against an Installable Client Driver loader (ICD loader) rather than linking their applications against a specific OpenCL implementation. The ICD Loader is responsible for:
- Exporting OpenCL API entry points
- Enumerating OpenCL implementations
- Forwarding OpenCL API calls to the correct implementation

The official implementation of ICD Loader can be found here on GitHub: [https://github.com/KhronosGroup/OpenCL-ICD-Loader](https://github.com/KhronosGroup/OpenCL-ICD-Loader).

There are other SDKs as well, but we ought not talk about them because they are out of scope:

```
    intel-opencl-sdkAUR: Intel OpenCL SDK (old version, new OpenCL SDKs are included in the INDE and Intel Media Server Studio)
    amdapp-sdkAUR: This package is installed as /opt/AMDAPP and apart from SDK files it also contains a number of code samples (/opt/AMDAPP/SDK/samples/). It also provides the clinfo utility which lists OpenCL platforms and devices present in the system and displays detailed information about them. As AMD APP SDK itself contains CPU OpenCL driver, no extra driver is needed to execute OpenCL on CPU devices (regardless of its vendor). GPU OpenCL drivers are provided by the catalystAUR package (an optional dependency).
    cuda: Nvidia's GPU SDK which includes support for OpenCL 1.1.
```

Besides, for the OpenCL Implementations, we've already talked about them. They are runtime libraries along with configuration files in `/etc/OpenCL/vendors`.

A utility to show all possible properties on your system, is `clinfo`.

Owning headers, OpenCL dynamic libraries and runtime libraries, we can start developing and running OpenCL program on C/C++. As well, there are lots of bindings for other languages, take ease to use them if you want.

In the next post, we will write a first OpenCL program. See you then!
