---
title: 跨语言蝴蝶效应：Protobuf C++ 库的一次 Mutex 重构，让 macOS Python 数据生态死锁
date: 2026-03-09 08:52:00
tags:
- Apple
- macOS
- Protobuf
- C++
- Python
- 逆向
- 中文
categories:
- [macOS]
- [Programming Language, Python]
- [Programming Language, C++]
- [Source Code, Python]
---

最近，我在 GitHub 上向 Protobuf 项目近一年前提交的一个 [issue](https://github.com/protocolbuffers/protobuf/issues/21686)越来越多地被 Google 自家项目引用，包括 TensorFlow 和 Gemma。它描述了一个在 macOS 上，由于 Protobuf 的一个内部的 Mutex 重构，影响到了多个主流 Python 项目——在 Python 中先后引用这些库可能会造成死锁。

虽然这个 issue 最终被关闭了，但它造成的影响却在持续发酵，尤其是在数据科学和机器学习领域，因为很多 Python 库都直接或者间接依赖 Protobuf 来处理数据序列化。一个 C++ 底层库的内部重构，如何跨越语言边界，让依赖于 PyArrow 的 Python 数据生态陷入崩溃，并且持续数年（从 2023 开始，到了 2026 年仍在产生影响）？这篇文章记录了我的调查过程、复现方法，以及这个看似"小问题"背后的结构性隐患。

# 一切的起点

故事起源于我在和 Google Deepmind 团队合作的项目中，使用他们的引用了 Tink 加密库的 Python 绑定的项目。有一天，当我先后引入这个库和 Hugging Face 的 `datasets` 库时，产生了死锁或者程序崩溃的问题。初步的调查让我定位到，这是 Tink 加密库和 Hugging Face 的 `datasets` 库引入的 PyArrow 库共同导致的问题。

这个问题最早可以追溯到[2023 年的 tink-crypto/tink-py#25](https://github.com/tink-crypto/tink-py/issues/25)。Tink 的 Python 绑定在 1.9 版本更新后，用户开始在 macOS 上遇到崩溃：

```
libc++abi: terminating due to uncaught exception of type 
std::__1::system_error: mutex lock failed: Invalid argument
```

到了 2024 年，PyArrow 的用户也报告了完全相同的问题 [apache/arrow#40088](https://github.com/apache/arrow/issues/40088)。

在我的情况下，单独导入 `tink==1.11.0` 或单独导入 `pyarrow==20.0.0` 都没问题，但当两者在同一个 Python 进程中相遇时：

- 先导入 Tink，再导入 PyArrow → **死锁**
- 先导入 PyArrow，再导入 Tink → **直接崩溃**

导入顺序决定了崩溃的方式，但结果一样：你的 Python 进程**挂掉/挂起**了。

注意：尽管这些问题都只在 Apple Silicon 的 macOS 上发生，但它们并不是 Apple Silicon 特有的，Intel 的 macOS 上也会发生（可能只是因为还在用 Intel Mac 的数据科学用户太少，导致没有类似的报告），而是由于 Protobuf 在这两个库中使用了不同版本的 Protobuf 导致的。只要在 macOS 上同时加载了这两个库，就会触发这个问题。

# Protobuf 的一次小重构

经过排查，我发现 Tink 和 PyArrow 都依赖 Protobuf，但版本不同：

- Tink 1.11.0 使用 Protobuf 3.25.1
- PyArrow 20.0.0 使用 Protobuf 3.21.3

通过阅读大量 diff 和调试，我发现 Protobuf 在较新版本的某次提交中将内部实现从 `std::mutex` 迁移到了 `absl::Mutex`——一次"小重构"。

## 汇编级别的调试

我决定用 LLDB 深入看看发生了什么。在 `google::protobuf::internal::OnShutdownRun` 函数上设置断点后，我发现了问题所在。

**导入 PyArrow 时的汇编代码：**

```assembly
0x10732a114 <+32>: adrp x8, 1794
0x10732a118 <+36>: ldr x8, [x8, #0x340]    ; 获取 singleton 数据
0x10732a11c <+40>: ldaprb w8, [x8]
0x10732a120 <+44>: adrp x19, 1796
0x10732a124 <+48>: ldr x19, [x19, #0x50]
0x10732a128 <+52>: tbz w8, #0x0, 0x10732a238
0x10732a12c <+56>: ldr x22, [x19]
0x10732a130 <+60>: add x19, x22, #0x18
0x10732a134 <+64>: mov x0, x19
0x10732a138 <+68>: bl 0x107531dd0           ; 调用 std::mutex::lock()
```

寄存器显示：

```
x8 = 0x0000000107b2b8c8  ; google::protobuf::internal::ShutdownData::get()::data 的守护变量
```

这里调用的是标准 C++ 库的 `std::mutex::lock()`，因为 PyArrow 的 Protobuf 3.21.3 版本仍在使用 `std::mutex`。

**导入 Tink 后的汇编代码：**

```assembly
0x103f5b128 <+36>: adrp x8, 501
0x103f5b12c <+40>: ldr x8, [x8, #0xe8]     ; 获取 singleton 数据
0x103f5b130 <+44>: ldaprb w8, [x8]
0x103f5b134 <+48>: adrp x19, 502
0x103f5b138 <+52>: ldr x19, [x19, #0xaa0]
0x103f5b13c <+56>: tbz w8, #0x0, 0x103f5b218
0x103f5b140 <+60>: ldr x22, [x19]
0x103f5b144 <+64>: add x19, x22, #0x18
0x103f5b148 <+68>: mov x0, x19
0x103f5b14c <+72>: bl 0x104026a88           ; 调用 absl::Mutex::Lock()
```

寄存器显示：

```
x8 = 0x0000000107b2b8c8  ; 相同的地址！
```

**问题就在这里**：两个库获取到了同一个 singleton 数据地址（`0x0000000107b2b8c8`），但 Tink 的 Protobuf 3.25.1 版本已经在使用 `absl::Mutex` 了，而 PyArrow 的使用 `std::mutex`。当 Tink 尝试用 `absl::Mutex::Lock()` 去锁一个实际上是 `std::mutex` 的对象时，程序要么崩溃（非法数据访问），要么死锁（Mutex 无法被释放）。

## 令 Python 视角的用户困惑的根本原因

但是，为什么两个库会共享同一个 singleton 数据地址呢？这应该是高级 Python 用户/Python 专家的一个疑问（实际上也正是 CPython 核心贡献者和 PyArrow 维护者 @pitrou 的[问题](https://github.com/apache/arrow/issues/40088#issuecomment-2858547071)）：引入的 Python 的时候的 `.so` 不是应该使用了 `RTLD_LOCAL` 加载、从而隔离开来的吗？

问题的核心在于在 macOS 中动态链接器的行为：在 Mach-O 格式中，**弱符号 (weak symbols) 会参与全局符号搜索**，这是为了支持 C++ 的 One Definition Rule (ODR)。

当两个库都导出相同名称的弱符号时，即使它们是用 `RTLD_LOCAL` 加载的，动态链接器也会将它们合并到同一个地址。这就是为什么两个不同版本的 Protobuf 会共享同一个 `ShutdownData::get()::data` 实例。

在 Protobuf 中，

```cpp
#if defined(PROTOBUF_USE_DLLS) && defined(_MSC_VER)
# if defined(LIBPROTOBUF_EXPORTS)
#  define PROTOBUF_EXPORT __declspec(dllexport)
#  define PROTOBUF_EXPORT_TEMPLATE_DECLARE
#  define PROTOBUF_EXPORT_TEMPLATE_DEFINE __declspec(dllexport)
# else
#  define PROTOBUF_EXPORT __declspec(dllimport)
#  define PROTOBUF_EXPORT_TEMPLATE_DECLARE
#  define PROTOBUF_EXPORT_TEMPLATE_DEFINE __declspec(dllimport)
# endif  // defined(LIBPROTOBUF_EXPORTS)
#elif defined(PROTOBUF_USE_DLLS) && defined(LIBPROTOBUF_EXPORTS)
# define PROTOBUF_EXPORT __attribute__((visibility("default")))
# define PROTOBUF_EXPORT_TEMPLATE_DECLARE __attribute__((visibility("default")))
# define PROTOBUF_EXPORT_TEMPLATE_DEFINE
#else
# define PROTOBUF_EXPORT
# define PROTOBUF_EXPORT_TEMPLATE_DECLARE
# define PROTOBUF_EXPORT_TEMPLATE_DEFINE
#endif
```

而在 Linux 上，ELF 格式支持符号版本控制 (Symbol Versioning)，即使符号名称相同，但版本不同也会被视为不同的实体，从而不会出现这个问题。

# 用来验证假设的项目

为了验证这个假设，我创建了一个最小化的在 Linux 和 macOS 上复现并比较的项目：[loading-dynlib-test](https://github.com/Inokinoki/loading-dynlib-test)。

## 实验设计

项目包含两个库：libA 和 libB，都定义了一个弱符号 `DoShutdown()`。

- **libA** 用 `RTLD_GLOBAL` 加载
- **libB** 用 `RTLD_LOCAL` 加载

然后检查 libB 是否会被 libA 的 `DoShutdown()` 版本"污染"。

### macOS 上的证据 (Mach-O)

在 macOS 上，**弱符号总是参与扁平的全局搜索**，以满足 C++ One Definition Rule (ODR)。

**运行时地址：**

| 库 | 标志 | DoShutdown 地址 | 结果 |
|---|---|---|---|
| libA | GLOBAL | 0x1010ec528 | 目标 |
| libB | LOCAL | 0x1010ec528 | **被污染** (符号合并) |

**符号表 (`nm -m`)：**

两个符号都被导出为 `weak external`，触发动态链接器 (dyld) 忽略句柄级别的隔离：

```
0000000000000528 (__TEXT,__text) weak external __Z10DoShutdownv
```

### Linux 上的证据 (ELF)

在 Linux 上，我们使用**符号版本控制 (Symbol Versioning)**（通过版本脚本）来区分符号。

**运行时地址：**

| 库 | 标志 | DoShutdown 地址 | 结果 |
|---|---|---|---|
| libA | GLOBAL | 0x7fffff210170 | 目标 |
| libB | LOCAL | 0x7fffff20b160 | **隔离** (正确) |

**符号表 (`nm -D`)：**

符号带有版本标签 (`@@VERSION`)。即使名称相同，动态链接器也会因为版本脚本不匹配而将它们视为不同的实体，例如：

```
0000000000001170 W _Z10DoShutdownv@@LIBPROTO_1.0
0000000000001160 W _Z10DoShutdownv@@LIBPROTO_2.0
```

## 为什么在 Linux 上没事

这是整个调查中最有趣的部分。同样的代码，在 Linux 上运行良好，在 macOS 上却崩溃了。

### Mach-O vs ELF

macOS 使用的 Mach-O 格式和 Linux 使用的 ELF 格式在处理弱符号时有本质区别：

**Mach-O (macOS):**
- 弱符号总是参与扁平的全局搜索
- 这是为了支持 C++ ODR，确保同一符号在进程中只有一个定义
- `RTLD_LOCAL` 在这种情况下很难起到隔离作用

**ELF (Linux):**
- 支持符号版本控制 (Symbol Versioning)
- 通过版本脚本 (version scripts) 为符号添加版本标签
- 即使符号名称相同，版本不同也被视为不同符号
- `RTLD_LOCAL` 确实能真正起到隔离作用

### Protobuf 的构建差异

我检查了 Protobuf 的构建配置，发现 Linux 版本会使用版本脚本（version scripts）：

```cmake
if(protobuf_HAVE_LD_VERSION_SCRIPT)
  if(${CMAKE_VERSION} VERSION_GREATER 3.13 OR ${CMAKE_VERSION} VERSION_EQUAL 3.13)
    target_link_options(libprotoc PRIVATE -Wl,--version-script=${protobuf_SOURCE_DIR}/src/libprotoc.map)
  elseif(protobuf_BUILD_SHARED_LIBS)
    target_link_libraries(libprotoc PRIVATE -Wl,--version-script=${protobuf_SOURCE_DIR}/src/libprotoc.map)
  endif()
  set_target_properties(libprotoc PROPERTIES
    LINK_DEPENDS ${protobuf_SOURCE_DIR}/src/libprotoc.map)
endif()
```

这个脚本内容如下：

```ld
{
  global:
    extern "C++" {
      *google*;
      pb::*;
    };
    scc_info_*;
    descriptor_table_*;

  local:
    *;
};
```

而 macOS 版本没有版本脚本这种东西，因此 `HAVE_LD_VERSION_SCRIPT` 不会被定义。这导致 macOS 上的符号没有版本标签，触发了弱符号合并。

# 受影响的生态与解决方案

这个问题不仅仅影响 Tink。我在 Protobuf 的 issue 里又发现了一系列相关问题：

- [apache/arrow#40088](https://github.com/apache/arrow/issues/40088) - PyArrow 用户报告相同问题
- TensorFlow 用户也遇到了类似问题
- Gemma 和其他依赖 Protobuf 的 Python 包都受影响

本质上，**任何在 macOS 上同时加载多个不同版本 Protobuf 的 Python 项目都可能遇到这个问题**。这一现象至今仍然可以稳定复现，因为事实上它们并没有被修复，只是通过把不同的库升级到了兼容的 Protobuf 版本来规避了这个问题（例如 PyArrow 22.0.0）。

短期方案：

1. **固定版本**：确保所有依赖使用兼容版本的 Protobuf
2. **避免同时导入**：在代码结构上避免同时加载冲突的库（这对于 Python 项目来说不太现实）

长期方案：

1. **Protobuf 修复**：在 macOS 上也使用符号版本控制（但是很麻烦，因为 Mach-O 不原生支持，类似的 `--exported_symbols_list` 也不够灵活）
2. **dyld 行为修改**：但这需要 Apple 的支持，不太现实
3. **使用命名空间隔离**：通过重构代码将不同版本的 Protobuf 放在不同的命名空间中

# 结论

这个问题揭示了 macOS 动态链接机制的一个结构性弱点。弱符号的全局合并行为虽然有利于 C++ ODR，但在多版本依赖共存的现代 Python 生态中却成了隐患，造成了和 Linux 上完全不同的行为。

这并不显然，尤其是对于跨了一层语言的 Python 用户甚至维护者来说，他们可能不完全了解底层 C++ 库的实现细节，更不知道 Mach-O 和 ELF 在符号处理上的差异。不然也不会从 issue 最早提出的 2023 年至今，都还没有得到一个根本性的修复；并且 Google 自家的项目（TensorFlow、Gemma）也都受到了这个问题的影响。

目前对于用户来说，如果遇到类似问题，可以尝试：

1. 检查依赖树中的 Protobuf 版本
2. 考虑使用兼容版本的库（例如升级 PyArrow）
3. 在极端情况下，自己编译 Protobuf 并使用符号版本控制

我的描述或许有夸大，但是由于 Hugging Face 的 `datasets` 库和它背后的 `PyArrow` 在 Python 生态中的广泛使用，这个问题的影响范围确实很大，尤其是在数据科学和机器学习领域。

最后，也感谢这个问题让我深入了解了动态链接器的 internals。虽然调试过程很痛苦，但收获颇丰。希望这个调查能帮助其他遇到类似问题的人理解背后的原理，并找到合适的解决方案。

---

**参考资料：**

- [tink-crypto/tink-py#25](https://github.com/tink-crypto/tink-py/issues/25)
- [protocolbuffers/protobuf#21686](https://github.com/protocolbuffers/protobuf/issues/21686)
- [apache/arrow#40088](https://github.com/apache/arrow/issues/40088)
- [loading-dynlib-test](https://github.com/Inokinoki/loading-dynlib-test)
