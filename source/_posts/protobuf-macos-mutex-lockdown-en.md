---
title: Cross-Language Butterfly Effect: A Protobuf C++ Mutex Refactor Deadlocks the macOS Python Data Ecosystem
date: 2026-03-09 08:52:00
tags:
- Apple
- macOS
- Protobuf
- C++
- Python
- Reverse Engineering
categories:
- [macOS]
- [Programming Language, Python]
- [Programming Language, C++]
- [Source Code, Python]
---

Recently, an [issue](https://github.com/protocolbuffers/protobuf/issues/21686) I submitted to the Protobuf project nearly a year ago has been increasingly referenced by Google's own projects, including TensorFlow and Gemma. It describes a problem on macOS where an internal Mutex refactor in the Protobuf library affects multiple mainstream Python projects—importing these libraries in Python can cause deadlocks.

Although this issue was eventually closed, its impact has continued to grow, especially in the data science and machine learning fields, as many Python libraries directly or indirectly depend on Protobuf for data serialization. How did an internal refactor of a C++ low-level library cross language boundaries and cause the Python data ecosystem relying on PyArrow to collapse, with effects persisting for several years (from 2023 to 2026)? This article documents my investigation process, reproduction methods, and the structural hidden dangers behind this seemingly "small problem."

# The Starting Point

The story began in a project where I was collaborating with Google DeepMind, using their Python bindings that referenced the Tink encryption library. One day, when I imported this library followed by Hugging Face's `datasets` library, I encountered deadlocks or program crashes. Initial investigation revealed this was caused by an interaction between the Tink encryption library and the PyArrow library that Hugging Face's `datasets` depends on.

This issue can be traced back to [tink-crypto/tink-py#25 from 2023](https://github.com/tink-crypto/tink-py/issues/25). After the Tink Python bindings version 1.9 update, users started encountering crashes on macOS:

```
libc++abi: terminating due to uncaught exception of type
std::__1::system_error: mutex lock failed: Invalid argument
```

By 2024, PyArrow users reported the exact same issue at [apache/arrow#40088](https://github.com/apache/arrow/issues/40088).

In my case, importing `tink==1.11.0` alone or `pyarrow==20.0.0` alone was fine, but when both met in the same Python process:

- Import Tink first, then PyArrow → **Deadlock**
- Import PyArrow first, then Tink → **Immediate crash**

The import order determined the failure mode, but the result was the same: your Python process **crashes/hangs**.

Note: Although these issues were only observed on Apple Silicon macOS, they are not Apple Silicon-specific—they also occur on Intel macOS (likely due to fewer data science users still on Intel Macs, resulting in no similar reports). This is caused by Protobuf using different versions in these two libraries. As long as both libraries are loaded on macOS, this problem is triggered.

# A Small Protobuf Refactor

After investigation, I found that both Tink and PyArrow depend on Protobuf, but use different versions:

- Tink 1.11.0 uses Protobuf 3.25.1
- PyArrow 20.0.0 uses Protobuf 3.21.3

By reading extensive diffs and debugging, I discovered that a certain commit in a newer version of Protobuf migrated the internal implementation from `std::mutex` to `absl::Mutex`—a "small refactor."

## Assembly-Level Debugging

I decided to use LLDB to dive deeper into what was happening. After setting a breakpoint on the `google::protobuf::internal::OnShutdownRun` function, I found the problem.

**Assembly code when importing PyArrow:**

```assembly
0x10732a114 <+32>: adrp x8, 1794
0x10732a118 <+36>: ldr x8, [x8, #0x340]    ; Load singleton data
0x10732a11c <+40>: ldaprb w8, [x8]
0x10732a120 <+44>: adrp x19, 1796
0x10732a124 <+48>: ldr x19, [x19, #0x50]
0x10732a128 <+52>: tbz w8, #0x0, 0x10732a238
0x10732a12c <+56>: ldr x22, [x19]
0x10732a130 <+60>: add x19, x22, #0x18
0x10732a134 <+64>: mov x0, x19
0x10732a138 <+68>: bl 0x107531dd0           ; Call std::mutex::lock()
```

Registers show:

```
x8 = 0x0000000107b2b8c8  ; Guard variable for google::protobuf::internal::ShutdownData::get()::data
```

This calls the standard C++ library's `std::mutex::lock()`, because PyArrow's Protobuf 3.21.3 version still uses `std::mutex`.

**Assembly code after importing Tink:**

```assembly
0x103f5b128 <+36>: adrp x8, 501
0x103f5b12c <+40>: ldr x8, [x8, #0xe8]     ; Load singleton data
0x103f5b130 <+44>: ldaprb w8, [x8]
0x103f5b134 <+48>: adrp x19, 502
0x103f5b138 <+52>: ldr x19, [x19, #0xaa0]
0x103f5b13c <+56>: tbz w8, #0x0, 0x103f5b218
0x103f5b140 <+60>: ldr x22, [x19]
0x103f5b144 <+64>: add x19, x22, #0x18
0x103f5b148 <+68>: mov x0, x19
0x103f5b14c <+72>: bl 0x104026a88           ; Call absl::Mutex::Lock()
```

Registers show:

```
x8 = 0x0000000107b2b8c8  ; Same address!
```

**This is the problem**: both libraries obtained the same singleton data address (`0x0000000107b2b8c8`), but Tink's Protobuf 3.25.1 version was already using `absl::Mutex`, while PyArrow uses `std::mutex`. When Tink tried to use `absl::Mutex::Lock()` to lock an object that was actually a `std::mutex`, the program either crashed (illegal memory access) or deadlocked (mutex could not be released).

## The Root Cause That Confuses Python Users

But why do two libraries share the same singleton data address? This is a question that advanced Python users and experts would ask (and indeed was the [question](https://github.com/apache/arrow/issues/40088#issuecomment-2858547071) raised by CPython core contributor and PyArrow maintainer @pitrou): Shouldn't `.so` files loaded in Python use `RTLD_LOCAL` to achieve isolation?

The core of the problem lies in the dynamic linker behavior on macOS: in Mach-O format, **weak symbols participate in global symbol search**. This is to support C++'s One Definition Rule (ODR).

When two libraries export weak symbols with the same name, even if they are loaded with `RTLD_LOCAL`, the dynamic linker merges them into the same address. This is why two different versions of Protobuf share the same `ShutdownData::get()::data` instance.

In Protobuf, symbol export is controlled by the following macros:

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

On Linux, ELF format supports Symbol Versioning, so even if symbol names are the same, different versions are treated as different entities, thus avoiding this problem.

# A Project to Verify the Hypothesis

To verify this hypothesis, I created a minimal project to reproduce and compare behavior on Linux and macOS: [loading-dynlib-test](https://github.com/Inokinoki/loading-dynlib-test).

## Experimental Design

The project contains two libraries: libA and libB, both defining a weak symbol `DoShutdown()`.

- **libA** is loaded with `RTLD_GLOBAL`
- **libB** is loaded with `RTLD_LOCAL`

The goal is to check whether libB gets "contaminated" by libA's version of `DoShutdown()`.

### Evidence on macOS (Mach-O)

On macOS, **weak symbols always participate in flat global search** to satisfy C++ One Definition Rule (ODR).

**Runtime addresses:**

| Library | Flag | DoShutdown Address | Result |
|---|---|---|---|
| libA | GLOBAL | 0x1010ec528 | Target |
| libB | LOCAL | 0x1010ec528 | **Contaminated** (symbol merged) |

**Symbol table (`nm -m`):**

Both symbols are exported as `weak external`, triggering the dynamic linker (dyld) to ignore handle-level isolation:

```
0000000000000528 (__TEXT,__text) weak external __Z10DoShutdownv
```

### Evidence on Linux (ELF)

On Linux, **Symbol Versioning** (via version scripts) is used to distinguish symbols.

**Runtime addresses:**

| Library | Flag | DoShutdown Address | Result |
|---|---|---|---|
| libA | GLOBAL | 0x7fffff210170 | Target |
| libB | LOCAL | 0x7fffff20b160 | **Isolated** (correct) |

**Symbol table (`nm -D`):**

Symbols have version tags (`@@VERSION`). Even if names are the same, the dynamic linker treats them as different entities due to version script mismatch, for example:

```
0000000000001170 W _Z10DoShutdownv@@LIBPROTO_1.0
0000000000001160 W _Z10DoShutdownv@@LIBPROTO_2.0
```

## Why Linux is OK but macOS is Not

This is the most interesting part of the entire investigation. The same code runs fine on Linux but crashes on macOS.

### Mach-O vs ELF

The Mach-O format used by macOS and the ELF format used by Linux have fundamental differences in handling weak symbols:

**Mach-O (macOS):**
- Weak symbols always participate in flat global search
- This is to support C++ ODR, ensuring only one definition of the same symbol exists in a process
- `RTLD_LOCAL` provides almost no isolation in this case

**ELF (Linux):**
- Supports Symbol Versioning
- Adds version tags to symbols via version scripts
- Even if symbol names are the same, different versions are treated as different symbols
- `RTLD_LOCAL` truly provides isolation

### Protobuf Build Differences

I examined Protobuf's build configuration and found that the Linux version uses version scripts:

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

This script content is as follows:

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

The macOS version has no such version script, so `HAVE_LD_VERSION_SCRIPT` is not defined. This causes symbols on macOS to have no version tags, triggering weak symbol merging.

# Affected Ecosystem and Solutions

This issue affects more than just Tink. I found a series of related issues in Protobuf's issue tracker:

- [apache/arrow#40088](https://github.com/apache/arrow/issues/40088) - PyArrow users report the same issue
- TensorFlow users also encountered similar problems
- Gemma and other Python packages depending on Protobuf are affected

Essentially, **any Python project that loads multiple different versions of Protobuf on macOS may encounter this problem**. This phenomenon can still be reliably reproduced today because these issues were never actually fixed—instead, they were avoided by upgrading different libraries to compatible Protobuf versions (e.g., PyArrow 22.0.0).

Short-term solutions:

1. **Pin versions**: Ensure all dependencies use compatible Protobuf versions
2. **Avoid simultaneous imports**: Avoid loading conflicting libraries simultaneously (this is unrealistic for most Python projects)

Long-term solutions:

1. **Protobuf fix**: Use symbol versioning on macOS as well (but this is troublesome because Mach-O doesn't natively support it, and the similar `--exported_symbols_list` approach is not flexible enough)
2. **dyld behavior modification**: This would require Apple's support, which is unrealistic
3. **Use namespace isolation**: Refactor code to place different Protobuf versions in different namespaces

# Conclusion

This issue reveals a structural weakness in macOS's dynamic linking mechanism. The global merging behavior of weak symbols, while beneficial for C++ ODR, becomes a hidden danger in the modern Python ecosystem where multi-version dependencies coexist, causing completely different behavior compared to Linux.

This isn't obvious, especially for Python users and even maintainers who are one layer removed from the language. They may not fully understand the implementation details of the underlying C++ library, let alone the differences in symbol handling between Mach-O and ELF. Otherwise, there wouldn't have been no fundamental fix from when the issue was first raised in 2023 to now, and Google's own projects (TensorFlow, Gemma) would not have been affected by this problem.

Currently, for users encountering similar issues, you can try:

1. Check Protobuf versions in your dependency tree
2. Consider using libraries with compatible versions (e.g., upgrade PyArrow)
3. In extreme cases, compile Protobuf yourself and use symbol versioning

My description may be exaggerated, but due to the widespread use of Hugging Face's `datasets` library and its underlying `PyArrow` in the Python ecosystem, this issue indeed has a large impact, especially in the data science and machine learning fields.

Finally, thanks to this issue, I gained a deep understanding of the dynamic linker's internals. Although the debugging process was painful, the gain was substantial. I hope this investigation helps others encountering similar issues understand the underlying principles and find appropriate solutions.

---

**References:**

- [tink-crypto/tink-py#25](https://github.com/tink-crypto/tink-py/issues/25)
- [protocolbuffers/protobuf#21686](https://github.com/protocolbuffers/protobuf/issues/21686)
- [apache/arrow#40088](https://github.com/apache/arrow/issues/40088)
- [loading-dynlib-test](https://github.com/Inokinoki/loading-dynlib-test)
