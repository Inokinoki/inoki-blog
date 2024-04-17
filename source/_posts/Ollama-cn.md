---
title: Ollama 架构解析
date: 2024-04-16 18:03:00
tags:
- LLM
- ollama
- 翻译
- 中文
categories:
- [AI, LLM]
---

最近，我偶然探索了一个名为 `ollama` 的项目，因为我想让我的 AMD 显卡（拥有不俗的 VRAM - 32G！）在 Windows 上获得支持。Linux 上已经有了基于 AMD ROCm 的支持。由于 ROCm 在 Windows 上的发布，它在 Windows 上也应该是开箱即用的。但是，`ollama` 阻止我使用它。因此，我尝试了 ZLUDA 和修改 `ollama` 的代码，以达到我的目的。

这个功能已经在 [ollama v0.1.29](https://github.com/ollama/ollama/releases/tag/v0.1.29) 中合并并发布了。为了避免遗漏细节和我学到的东西，本博客负责记录我自己的 `ollama` 架构。

在我看来，`ollama`是[llama.cpp](https://github.com/ggerganov/llama.cpp)的一个精简但足够智能的封装。**它对终端用户非常友好，提供了网络接口和 cli，以便运行多个大型语言模型 (LLM) 并与之交互。**事实上，在大多数情况下，是由`llama.cpp`加载并运行模型，而`ollama`只是`llama.cpp`的"领航员"（是的，我用了熟悉生成式人工智能的人都熟悉的一个词）。稍后会对这部分内容进行讨论。

这篇文章假定你能够阅读 golang 代码或其他类似 C 语言的代码。对于代码中的关键点，我会给出一些简短的描述或类比，以便帮助更好地理解。

在这篇文章中，我将首先介绍`ollama`的项目结构。然后，将介绍围绕`llama.cpp`的核心架构和实现，以及构建系统。接下来，我将介绍`ollama`如何选择运行 LLM 的设备（一般指硬件）。最后，将介绍 Web 服务、客户端和实用程序以及其他部分，作为本篇文章的结束。

# 项目结构

你可以在 GitHub 上获取 [ollama 的源代码](https://github.com/ollama/ollama)。该项目主要使用 Golang 编写，下表是每个目录的简要说明：

<!-- Dir structure -->
| 目录名称     | 描述                                  |
| ----------- | ------------------------------------ |
| api         | Go 编写的的客户端 API 库                |
| app         | 桌面应用程序（主要是一个托盘）            |
| auth        | 验证                                  |
| cmd         | 命令和相关的处理程序                     |
| docs        | 文档                                  |
| examples    | 使用 ollama 的示例                     |
| format      | 用于单位和时间的格式处理的工具            |
| gpu         | GPU 和加速设备的检测                    |
| llm         | 用于运行 llama.cpp 的实现               |
| macapp      | Mac 桌面应用程序                       |
| openai      | 用于 ollama 的 OpenAI API 兼容封装     |
| parser      | 模型信息和消息的解析器                   |
| progress    | 显示加载进度的实用程序                   |
| readline    | 从终端读取输入的实用程序                 |
| scripts     | 用于构建和发布的脚本                    |
| server      | Go 编写的 Web 服务实现                 |
| version     | 版本信息                              |

请注意，由于项目正在开发中，这些目录可能随时被更改。

# 幕后英雄：llama.cpp

让我们先来介绍一下在 `ollama` 中运行 LLM 的核心 `llama.cpp`。

`llama.cpp` 作为 git 子模块包含在 `ollama` 中。您可以在 `llm` 目录中找到它。在同一目录下还有围绕它所需的文件，稍后我们将详细介绍它们。

`llama.cpp` 项目[本身](https://github.com/ggerganov/llama.cpp)是一个开源库，最开始是用于推断纯 C/C++ 的 Meta LLaMA 模型。它后来被扩展用于运行更多模型，比如 Mistral 和 Google Gemma（最近才支持）。它利用同一作者创建的另一个项目 [ggml](https://github.com/ggerganov/ggml) 的功能，可在不同平台上原生运行（与 Python 项目相比）。

## 支持的后端

目前，`llama.cpp` 通过 `ggml` 支持的一些推理后端如下：

- `llama.cpp`可运行 x86 上的 **AVX、AVX2 和 AVX512**，或 ARM 上的 **NEON**。
- 通过 MPI（如 MPICH 和 OpenMPI），`ggml` 可以在 CPU 或 CPU 集群上运行模型。
- **Apple Metal**集成支持macOS和iOS上的GPU，包括Mac上的GPU和iOS设备或Apple Silicon Mac上的Apple制造的GPU。
- 基于BLAS架构的`ggml`使用了一个古老的开放标准**OpenCL**。
- cuBLAS "支持英伟达™（NVIDIA®）公司的**GPU**。
- 最近的**AMD GPU**通过`hipBLAS`支持，它是[AMD ROCm](https://www.amd.com/en/products/software/rocm.html)的一部分，与`cuBLAS`的应用程序接口几乎相同。
- 最近引起我注意的是 `llama.cpp` 中的 Vulkan 支持。这项（有些漏洞）支持最初是由 Nomic 通过其 kompute 框架启动的。最近的进展是在 `ggml` 中直接使用 Vulkan 库的[实现](https://github.com/ggerganov/llama.cpp#vulkan)。

这些后端允许开发人员运行可在从台式电脑到智能手机等多个平台上运行的 LLM。此外，`llama.cpp` 还为 Linux（包括 Android Linux）、Windows、macOS 和其他各种操作系统（如 iOS，参见 [whispher.cpp on iOS](https://github.com/ggerganov/whisper.cpp/tree/master/examples/whisper.objc)）甚至 WebAssembly（[whispher.wasm](https://github.com/ggerganov/whisper.cpp/tree/master/examples/whisper.wasm)）提供原生支持。

因此，`ollama` 在诞生之初就应支持各种平台和操作系统。

# 构建系统

接下来，让我们看看构建系统，了解 `ollama` 如何与 `llama.cpp` 协作。

C 或 C++ 项目通常使用 `cmake`（尽管现在有了更多选择）来处理编译、链接等工作。`llama.cpp` 也是如此：它使用编译定义（或者说 flag）来利用不同的后端。例如

- `LLAMA_AVX`、`LLAMA_AVX2`、`LLAMA_AVX512`用于支持 AVX；
- 用于 Apple Metal 支持的 `LLAMA_METAL`；
- 用于 NVIDIA CUDA 支持的 `LLAMA_CUBLAS`；
- 以及 `LLAMA_HIPBLAS` 用于 AMD ROCm 支持。

不过，`ollama` 本身是一个 go 项目，利用的是 go 提供的构建系统。这两个构建系统共存，以构建不同的部分：

- `cmake` 用 `ollama.cpp` 中的一些文件构建 `llama.cpp`，以进行“领航”并提供接口；
- go 构建系统编译、链接和打包其余部分，以生成 `ollama` 的应用程序和 cli。

除了纯 go 代码，go 编译系统还需要 `cgo` 来编译一些 C 语言代码。在 `llm` 目录（用于加载和提供接口的 `dyn_ext_server.c` 文件）和 `gpu` 目录（用于检测 GPU 的 C 或 Objective-C 实现 `gpu_info_cuda.c`、`gpu_info_rocm.c` 和 `gpu_info_darwin.m`）中有一些例子。

通过利用 [go generate](https://go.dev/blog/generate)，`ollama` 中的 go 编译系统还可以运行调用 `cmake` 的命令来构建 `llama.cpp`。这项工作位于 `llm/generate` 目录中，例如在 Linux 上：

```
package generate

//go:generate bash ./gen_linux.sh
```

`llm/generate/generate_darwin.go` 告诉 go generate 运行 `gen_linux.sh` 脚本来构建 `llama.cpp` 的部分。

## 一些适用于不同平台的脚本

目前有 `gen_common.sh`、`gen_linux.sh` 和 `gen_darwin.sh`，用于在类 Unix 操作系统（如 macOS 和 Linux）上为 `ollama` 创建 `llama.cpp`。同时，在 Windows 上使用的是 `gen_windows.ps1` PowerShell 脚本。

让我们以在 Linux 上构建支持 AVX 的 `llama.cpp` 为例：

```shell
init_vars
CMAKE_DEFS="${COMMON_CPU_DEFS} -DLLAMA_AVX=on -DLLAMA_AVX2=off -DLLAMA_AVX512=off -DLLAMA_FMA=off -DLLAMA_F16C=off ${CMAKE_DEFS}"
BUILD_DIR="${LLAMACPP_DIR}/build/linux/${ARCH}/cpu_avx"
echo "Building AVX CPU"
build
compress_libs
```

前三行初始化变量，为编译做准备。`init_vars` 调用了 `gen_common.sh` 中的一个子程序来准备常用变量，例如

```shell
CMAKE_DEFS=""
CMAKE_TARGETS="--target ext_server"
```

其中 `CMAKE_TARGETS` 将把构建目标设置为 `ext_server`。该目标是一个库，用于从 `llama.cpp` 为 `ollama` 提供接口和函数，我们将在下一节讨论它。

在 `CMAKE_DEFS` 中，只有 `LLAMA_AVX` 是启用的。而   `COMMON_CPU_DEFS` 的定义如下，以构建独立于位置代码的动态库（对于 gcc，它将被转换为 `-fpic` 标志）：

```shell
COMMON_CPU_DEFS="-DCMAKE_POSITION_INDEPENDENT_CODE=on -DLLAMA_NATIVE=off"
```

它在终端输出 "Building AVX CPU" 之后，由 `build` 子程序调用 `cmake`：

```shell
build() {
    cmake -S ${LLAMACPP_DIR} -B ${BUILD_DIR} ${CMAKE_DEFS}
    cmake --build ${BUILD_DIR} ${CMAKE_TARGETS} -j8
    mkdir -p ${BUILD_DIR}/lib/
    g++ -fPIC -g -shared -o ${BUILD_DIR}/lib/libext_server.${LIB_EXT} \
        ${GCC_ARCH} \
        ${WHOLE_ARCHIVE} ${BUILD_DIR}/examples/server/libext_server.a ${NO_WHOLE_ARCHIVE} \
        ${BUILD_DIR}/common/libcommon.a \
        ${BUILD_DIR}/libllama.a \
        -Wl,-rpath,\$ORIGIN \
        -lpthread -ldl -lm \
        ${EXTRA_LIBS}
}
```

通过 `cmake` 编译后，它将生成一个 `libext_server` 动态链接库（Windows 下为 `.dll`，Linux/BSD 下为 `.so`，macOS 下为 `.dylib`）。该库包含 `llama.cpp` 下 `examples/server` 的编译代码（`examples/server/libext_server.a`）、命令代码和 `llama.cpp` 的核心代码—— `common/libcommoa.a` 和 `libllama.a`。它们将作为可执行文件的"载荷"嵌入主 go 程序，以方便分发。

最后，它会压缩载荷，使可执行文件更小：

```shell
compress_libs() {
    echo "Compressing payloads to reduce overall binary size..."
    pids=""
    rm -rf ${BUILD_DIR}/lib/*.${LIB_EXT}*.gz
    for lib in ${BUILD_DIR}/lib/*.${LIB_EXT}* ; do
        gzip --best -f ${lib} &
        pids+=" $!"
    done
    echo 
    for pid in ${pids}; do
        wait $pid
    done
    echo "Finished compression"
}
```

The dynamic library will finally reside under a `cpu_avx` directory in the build folder. If it builds for the other variants (such as GPUs), they will be in different directories in the build folder.

动态链接库最终将位于构建文件夹中的 "cpu_avx" 目录下。如果为其他变体（如 GPU）构建，它们将位于构建文件夹中的不同目录下。

# 为 llama.cpp 领航

然后，让我们回到 `llm` 目录，看看 `ollama` 中建立在 `llama.cpp` 基础上的实现。对于 `ollama` 来说，引导 `llama.cpp` 的最重要部分是：

1. 在 `ext_server` 中，包装器实现提供了 `ollama` 可以调用的函数，例如 `llama_server_init` 来初始化一个 `llama.cpp` 实例，`llama_server_completion` 来完成一次聊天，或者 `llama_server_embedding` 来计算文本的嵌入。
2. `ext_server` 中还包含一个额外的 makefile (`CMakeLists`)，用于将 `llama.cpp/examples/server` 示例作为库来构建代码。然后，它可以被 `llm` 下的 `dyn_ext_server` 代码加载，与 `llama.cpp` 实例一起提供服务。
3. 使用 [go embed package](https://pkg.go.dev/embed) 将库嵌入 go 程序，并在运行时提取。
4. 此外，调用 `ext_server` 中的函数时会携带 `llm` 目录中定义的一些参数。一般来说，请求和响应都以 JSON 格式传递，并包含更多结构信息。它们定义在 `ggml.go`（描述模型）和 `llama.go`（描述不同的请求和响应）中。
5. 为了动态管理 `llama.cpp` 实例，`ollama` 为原始的 `llama.cpp` 提供了一些补丁。

让我们逐一研究它们。

## 1. 外部服务器

我们首先来看看 `ext_server`。我们已经知道，动态库是在生成过程中构建的。但如何使用它们呢？

在 `llm/dyn_ext_server.go` 中，`newDynExtServer` 负责加载动态库、初始化 `llama.cpp` 实例并启动事件循环以接收任何请求并生成响应。

### 动态链接库的加载和服务器的启动

在 `newDynExtServer` 中，go 函数会调用一个以 `dyn_init` 命名的 C 函数来加载动态库。描述和所需函数被加载到 `struct_dynamic_llama_server` 描述中，并封装在 `dynExtServer`（一个 go 结构）中。

然后，它们会被用于另一个 C 函数 `dyn_llama_server_init`，其中包含运行 `llama.cpp` 服务器的参数，用于服务器实例初始化。

如果没有问题，`newDynExtServer` 将调用初始化过程中的最后一个 C 函数 `dyn_llama_server_start`。服务器将开始运行，并能接收来自 `ollama` 的请求。

上述 C 函数位于 `llm/dyn_ext_server.c` 中，并在 `llm/dyn_ext_server.h` 中声明。让我们快速了解一下 `dyn_init`：

```c
void dyn_init(const char *libPath, struct dynamic_llama_server *s,
                       ext_server_resp_t *err);
```

它接收库路径 `libPath` 作为参数，并通过 C 指针（对于不熟悉 C 的人来说就是内存地址，go 能够像 go 结构体一样处理它们，存储它们并传递给其他 C 函数）返回一个 `dynamic_llama_server` 实例或一个错误。

`dynamic_llama_server` 结构能够存储必要的 C 函数地址，以及加载的动态链接库的引用。其定义如下：

```c
struct dynamic_llama_server {
  void *handle;
  void (*llama_server_init)(ext_server_params_t *sparams,
                            ext_server_resp_t *err);
  void (*llama_server_start)();
  void (*llama_server_stop)();
  void (*llama_server_completion)(const char *json_req,
                                  ext_server_resp_t *resp);
  void (*llama_server_completion_next_result)(const int task_id,
                                              ext_server_task_result_t *result);
  void (*llama_server_completion_cancel)(const int task_id,
                                         ext_server_resp_t *err);
  void (*llama_server_release_task_result)(ext_server_task_result_t *result);
  void (*llama_server_tokenize)(const char *json_req, char **json_resp,
                                ext_server_resp_t *err);
  void (*llama_server_detokenize)(const char *json_req, char **json_resp,
                                  ext_server_resp_t *err);
  void (*llama_server_embedding)(const char *json_req, char **json_resp,
                                 ext_server_resp_t *err);
  void (*llama_server_release_json_resp)(char **json_resp);
};
```

`dyn_init` 的核心功能是加载由 `libPath` 指示的动态链接库，读取符号表，找到所需的 C 函数地址，并将其存储到 `dynamic_llama_server` 结构的实例中。`libPath` 可以是以 `libext_server` 为前缀的已构建动态链接库的路径。这样，基于 `llama.cpp` 的内置库就可以被 `ollama` 使用。

加载后，对 `dyn_llama_server_start` 和 `dyn_llama_server_start` 的调用实际上是直接调用动态库中的 C 函数：

```c
inline void dyn_llama_server_init(struct dynamic_llama_server s,
                                           ext_server_params_t *sparams,
                                           ext_server_resp_t *err) {
  s.llama_server_init(sparams, err);
}

inline void dyn_llama_server_start(struct dynamic_llama_server s) {
  s.llama_server_start();
}
```

调用 `dyn_llama_server_start` 后，从动态库创建的 `llama.cpp` 服务器就可以进行预测了。

### 预测

当 `ollama` 收到预测请求时，它会调用 `dynExtServer` 实例上的 `Predict`。该函数能够格式化请求（稍后会看到），并调用 C 函数 `dyn_llama_server_completion` 开始预测：

```c
inline void dyn_llama_server_completion(struct dynamic_llama_server s,
                                                 const char *json_req,
                                                 ext_server_resp_t *resp) {
  s.llama_server_completion(json_req, resp);
}
```

正如你所看到的，它也是直接调用从构建在 `llama.cpp` 上的动态库中加载的函数。

由于在 `Predict` 函数中使用了 `fn func(PredictResult)`参数，这部分的一个非常好的设计就是流式响应。这是一个回调函数，可以在收到响应后立即连续发送：

```go
if p.Content != "" {
  fn(PredictResult{
    Content: p.Content,
  })
}
```

它还依赖于对 `dyn_llama_server_completion_next_result` 的便捷调用（尽管它也是直接调用基于 `llama.cpp` 的动态库中加载的 C 函数 `llama_server_completion_next_result`）。

### 其他

其他调用也类似。您可以在 `llm/dyn_ext_server.go` 和 `llm/dyn_ext_server.c` 中找到它们，例如 `dyn_llama_server_tokenize`, `dyn_llama_server_detokenize` 用于 token 化或去 token 化，以及 `dyn_llama_server_embedding` 用于计算嵌入（embedding）。

## 2. `llama.cpp` 作为 `ollama` 的服务器

接下来让我们看一下 C 部分：`ollama` 说如何使用 `llama.cpp` 作为 LLM 服务器的。

在 `llm/dyn_ext_server.go` 的开头，cgo 的注释中有一些构建注释：

```c
/*
#cgo CFLAGS: -I${SRCDIR}/ext_server -I${SRCDIR}/llama.cpp -I${SRCDIR}/llama.cpp/common -I${SRCDIR}/llama.cpp/examples/server
#cgo CFLAGS: -DNDEBUG -DLLAMA_SERVER_LIBRARY=1 -D_XOPEN_SOURCE=600 -DACCELERATE_NEW_LAPACK -DACCELERATE_LAPACK_ILP64
#cgo CFLAGS: -Wmissing-noreturn -Wextra -Wcast-qual -Wno-unused-function -Wno-array-bounds
#cgo CPPFLAGS: -Ofast -Wextra -Wno-unused-function -Wno-unused-variable -Wno-deprecated-declarations
#cgo darwin CFLAGS: -D_DARWIN_C_SOURCE
#cgo darwin CPPFLAGS:  -DGGML_USE_ACCELERATE
#cgo darwin CPPFLAGS: -DGGML_USE_METAL -DGGML_METAL_NDEBUG
#cgo darwin LDFLAGS: -lc++ -framework Accelerate
#cgo darwin LDFLAGS: -framework Foundation -framework Metal -framework MetalKit -framework MetalPerformanceShaders
#cgo linux CFLAGS: -D_GNU_SOURCE
#cgo linux LDFLAGS: -lrt -ldl -lstdc++ -lm
#cgo linux windows LDFLAGS: -lpthread

#include <stdlib.h>
#include "dyn_ext_server.h"

*/
```

它们可以为不同的平台设置不同的编译和链接标志（`darwin` 用于 macOS，当然 `linux` 用于 Linux，而 `windows` 用于 Windows）。这样，cgo 就能找到 C 头文件（现有类型和函数的声明），将 `llm/dyn_ext_server.c` 与 go 部分编译和链接。

然后，让我们从动态库中查看 `ollama` 中使用的 C 函数。作为两个例子，我们从 `llama_server_init` 和 `llama_server_start` 开始。

它们的实现位于 `llm/ext_server/ext_server.cpp`，在 `llm/ext_server/CMakeLists.txt`中被设置为以 `ext_server` 命名的目标库。在构建目标时，该文件将与 `llama.cpp` 示例服务器一起编译。编译结果就是我们提到的动态链接库之一。

因此，`ext_server.cpp` 中的 C 函数可以从 `ollama` 中调用，并能利用 `llama.cpp` 中的函数。它实际上是两个项目之间的桥梁，**使 `llama.cpp` 中的示例服务器成为 `ollama` 的 LLM 服务器（或称 llama 服务器）**。

在初始化过程中，`llama_server_init` 会解析参数，为服务器创建上下文，并调用 `llama.cpp` 提供的函数：

```c
void llama_server_init(ext_server_params *sparams, ext_server_resp_t *err) {
  /* ... */
    llama = new llama_server_context;
  /* ... */
    llama_backend_init();
    llama_numa_init(params.numa);
  /* ... */
  if (!llama->load_model(params)) { 
    // an error occurred that was not thrown
    err->id = -1;
    snprintf(err->msg, err->msg_len, "error loading model %s", params.model.c_str());
    return;
  }
  /* ... */
    llama->initialize();
  /* ... */
}
```

例如，它会调用 `llama_backend_init` 来初始化后端（可以是 AVX、CUDA 等），调用 `llama_numa_init` 来初始化 NUMA（如果存在）。然后，它会调用服务器上下文中的 `load_model` 函数，使用给定参数加载模型，并使用 `initialize` 函数完成初始化。

如果出现错误，错误信息将被格式化为 `err` 参数返回，并在 go 部分进行处理。

同时，在 `llama_server_start` 中：

```c
void llama_server_start() {
  assert(llama != NULL);
  // TODO mutex to protect thread creation
  ext_server_thread = std::thread([&]() {
    try {
      LOG_TEE("llama server main loop starting\n");
      ggml_time_init();
      llama->queue_tasks.on_new_task(std::bind(
        &llama_server_context::process_single_task, llama, std::placeholders::_1));
      llama->queue_tasks.on_finish_multitask(std::bind(
          &llama_server_context::on_finish_multitask, llama, std::placeholders::_1));
      llama->queue_tasks.on_all_tasks_finished(std::bind(
          &llama_server_context::run_on_all_tasks_finished, llama));
      llama->queue_results.on_multitask_update(std::bind(
          &llama_server_queue::update_multitask,
          &llama->queue_tasks,
          std::placeholders::_1,
          std::placeholders::_2,
          std::placeholders::_3
        ));
      llama->queue_tasks.start_loop();
    } catch (std::exception &e) {
      LOG_TEE("caught exception in llama server main loop: %s\n", e.what());
    } catch (...) {
      LOG_TEE("caught unknown exception in llama server main loop\n");
    }
    LOG_TEE("\nllama server shutting down\n");
    llama_backend_free();
  });
}
```

它为任务处理设置一些回调，并在一个新线程中启动一个事件循环。事件循环负责预测。这样，对 `llama_server_start` 的调用就会立即返回。

此类 C 函数的更详细实现可以在同一文件中找到，即 `llm/ext_server/ext_server.cpp`。

## 3. 将库作为载荷嵌入

然后，让我们来探究一下载荷是如何完成的。

在以 `payload_*` 为前缀的 go 文件中，我们可以看到 `ollama` 的选择。例如，在`llm/payload_linux.go`中，有两行嵌入了每个`ext_server`库的不同变体：

```go
//go:embed llama.cpp/build/linux/*/*/lib/*
var libEmbed embed.FS
```

`llama.cpp/build/linux/*/*/lib/` 下的所有内置库都使用[类文件系统接口](https://pkg.go.dev/embed#hdr-File_Systems)作为载荷嵌入。这样，`ollama` 就可以像在文件系统中读写一样访问它们。

在初始化 `ollama` 的过程中，`llm/payload_common.go` 中的 `Init` 将调用 `nativeInit`：

```go
func Init() error {
	return nativeInit()
}
```

它的主要工作是将动态库从文件系统提取到临时位置，并检查驱动程序的访问权限（如适用）：

```go
libs, err := extractDynamicLibs(payloadsDir, "llama.cpp/build/*/*/*/lib/*")
/* ... */
err := verifyDriverAccess()
```

提取完成后，`ollama` 可以格式化库路径（[外部服务器](#1-外部服务器)小节中的 `dyn_init` 函数中使用的 `libPath`）。选择运行环境和匹配库的方法将在[决定运行位置](#决定运行位置) 小节中介绍。

## 4. 格式化请求和响应

我们再来看看 C 语言函数中使用的函数参数。

```go
inline void dyn_llama_server_init(struct dynamic_llama_server s,
                                           ext_server_params_t *sparams,
                                           ext_server_resp_t *err) {
  s.llama_server_init(sparams, err);
}

inline void dyn_llama_server_completion(struct dynamic_llama_server s,
                                                 const char *json_req,
                                                 ext_server_resp_t *resp) {
  s.llama_server_completion(json_req, resp);
}
```

在它们的函数签名中，我们可以看到它们使用的函数参数： 在 `dyn_llama_server_init` 中使用了 `ext_server_params_t` 参数，在 `dyn_llama_server_completion` 中使用了 `json_req` 字节数组。

`ext_server_params_t` 参数是一个 C 结构，包含启动 llama 服务器的配置，稍后将在 `llm/ext_server/server.cpp` 中解释（由于篇幅有限，我们不展开这部分内容）。

同时，完成调用的 `json_req` 在 `llm/ext_server/ext_server.cpp` 中使用如下：

```c
void llama_server_completion(const char *json_req, ext_server_resp_t *resp) {
  assert(llama != NULL && json_req != NULL && resp != NULL);
  resp->id = -1;
  resp->msg[0] = '\0';
  try {
    if (shutting_down) {
      throw std::runtime_error("server shutting down");
    }
    json data = json::parse(json_req);
    resp->id = llama->queue_tasks.get_new_id();
    llama->queue_results.add_waiting_task_id(resp->id);
    llama->request_completion(resp->id, data, false, false, -1);
  } catch (std::exception &e) {
    snprintf(resp->msg, resp->msg_len, "exception %s", e.what());
  } catch (...) {
    snprintf(resp->msg, resp->msg_len, "Unknown exception during completion");
  }
}
```

事实上，它包含 json 格式的完成请求，包括提示词、温度等。我们可以看到 `llama_server_completion` 为其创建了一个任务，并通过正常路径中的 `resp` 返回任务 ID。否则，它将格式化错误信息并返回。

如果您对其详细格式感兴趣，请查看 `llm/dyn_ext_server.go` 文件。

## 5. 补丁

为了适应在 `ollama` 中使用多个 llama 服务器，它还对原始版本的 `llama.cpp` 做了一些额外的修改。

例如，以下补丁导出了 `ggml_free_cublas` 并调用它来释放一个 llama 服务器实例：

```patch
diff --git a/examples/server/server.cpp b/examples/server/server.cpp
index 7800c6e7..be30db23 100644
--- a/examples/server/server.cpp
+++ b/examples/server/server.cpp
@@ -30,6 +30,10 @@
 #include <atomic>
 #include <signal.h>
 
+#ifdef GGML_USE_CUBLAS
+extern "C" GGML_CALL void ggml_free_cublas(void);
+#endif
+
 using json = nlohmann::json;
 
 struct server_params
@@ -353,6 +357,9 @@ struct llama_server_context
             llama_free_model(model);
             model = nullptr;
         }
+#ifdef GGML_USE_CUBLAS
+        ggml_free_cublas();
+#endif
     }
```

## 做个小总结

通过对 `llama.cpp` 的所有额外模块和修改，`ollama` 能够根据需要启动 llama 服务器，通过不同编译动态库中对不同硬件的支持动态选择硬件（参见 [构建系统](#构建系统)）。运行 llama 服务器后，`ollama` 提供的额外模块允许发送完成请求，并在稍后检索回复。

现在，我们应该清楚地了解了后面的 `ollama` 架构（我们也可以称其为后端）。关于后端的更多细节，读者可以查看源代码，因为它们上会经常更改。毕竟，`ollama` 正在积极开发中。

但是，此时还有一些谜团：

- 在后端方面：`ollama` 如何知道选择哪种硬件和动态库？
- 在前端方面：它提供哪种前端？

下面的章节可能就是这些问题的答案。

# 决定运行位置

让我们回到动态库和 `dyn_init` 中的 `libPath` 参数，在 [动态链接库的加载和服务器的启动](#动态链接库的加载和服务器的启动) 中提到过。我们在 [Embed libraries as payloads](#3-将库作为载荷嵌入)中已经知道，`ollama` 会将嵌入的动态库提取到一个临时目录，并通过格式化和传递 `libPath` 到 `dyn_init` 来加载它们。

问题是： `ollama` 如何通过传递不同的 `libPath` 参数来选择库？

在`llm/dyn_ext_server.go`中实现的`newDynExtServer`函数中，`libPath`作为第一个参数`library`被传递。在 Windows 环境下，它通过调用 `gpu.UpdatePath(filepath.Dir(library))` 进行更新，以便在 `PATH` 中添加父目录。这样就可以无缝加载动态链接库。不过，在 Linux 或 macOS 上不必这样做。

因此，我们可以知道这里的 `libPath` 已经是动态链接库文件的完整路径。然后，让我们检查生成 `libPath` 的位置。

通过简单搜索，我们可以在 `llm/llm.go` 下的 `newLlmServer` 函数中找到答案：

```go
err2 := fmt.Errorf("unable to locate suitable llm library")
for _, dynLib := range dynLibs {
	srv, err := newDynExtServer(dynLib, model, adapters, projectors, opts)
	if err == nil {
		return srv, nil
	}
	slog.Warn(fmt.Sprintf("Failed to load dynamic library %s  %s", dynLib, err))
	err2 = err
}
```

它会遍历 `dynLibs` 以调用 `newDynExtServer` 函数。一旦加载成功，它就会返回 llama 服务器实例。

在 `newLlmServer` 开始的地方，`dynLibs` 一般在 `getDynLibs` 函数中检索，这是一个要尝试的动态链接库的有序列表：

```go
func newLlmServer(gpuInfo gpu.GpuInfo, model string, adapters, projectors []string, opts api.Options) (LLM, error) {
	dynLibs := getDynLibs(gpuInfo)
	/* ... */
}
```

顺序是一种偏好，它从 `gpuInfo gpu.GpuInfo` 中获取 GPU 信息。它并不强制是 "GPU 信息"，它也可以指示使用某个 CPU 变体。我想 `ollama` 团队可能很快就会修改它。

一般来说，返回的 `dynLibs` 来自 `llm/payload_common.go` 中的键值映射 `availableDynLibs`。它是在提取所有动态库之后在 `nativeInit` 中生成的：

```go
func nativeInit() error {
	/* ... */
	/* Extract dynamic libraries in temporary directory */
	/* ... */
	for _, lib := range libs {
		// The last dir component is the variant name
		variant := filepath.Base(filepath.Dir(lib))
		availableDynLibs[variant] = lib
	}
	/* ... */
}
```

它的关键字是全路径中除库文件名之外的最后一个组成部分。例如，在我的电脑上是 `cpu`、`cpu_avx`、`cpu_avx2`、`cuda_v11.3` 和 `rocm_v5.7`。而对应值当然是完整路径。

我们可以先看看 `getDynLibs` 函数（在 `llm/payload_common.go` 中实现）的一般处理过程，忽略一些特定平台的情况。

第一步是从 "GPU 信息" 中找到与请求完全匹配的内容：

```go
exactMatch := ""
dynLibs := []string{}
altDynLibs := []string{}
requested := gpuInfo.Library
if gpuInfo.Variant != "" {
	requested += "_" + gpuInfo.Variant
}
// Try to find an exact match
for cmp := range availableDynLibs {
	if requested == cmp {
		exactMatch = cmp
		dynLibs = []string{availableDynLibs[cmp]}
		break
	}
}
```

它会根据 "GPU 信息" 中的 `Library` 字段生成一个 `requested` 字符串变量，并附加一个 `变体（Variant）`。如果有一个与 `requested` 字符串完全匹配的库，`dynLibs` 中的第一个库路径将是所请求库的路径。第一个库路径也将是加载过程中首先尝试的路径。

然后，它会尝试不完全匹配的 GPU 库（可能存在版本不匹配等情况）：

```go
// Then for GPUs load alternates and sort the list for consistent load ordering
if gpuInfo.Library != "cpu" {
	for cmp := range availableDynLibs {
		if gpuInfo.Library == strings.Split(cmp, "_")[0] && cmp != exactMatch {
			altDynLibs = append(altDynLibs, cmp)
		}
	}
	slices.Sort(altDynLibs)
	for _, altDynLib := range altDynLibs {
		dynLibs = append(dynLibs, availableDynLibs[altDynLib])
	}
}
```

接下来，它会调用另一个实用程序 `GetCPUVariant`，尝试优先选择最快（可能）的 CPU 变体：

```go
// Load up the best CPU variant if not primary requested
if gpuInfo.Library != "cpu" {
	variant := gpu.GetCPUVariant()
	// If no variant, then we fall back to default
	// If we have a variant, try that if we find an exact match
	// Attempting to run the wrong CPU instructions will panic the
	// process
	if variant != "" {
		for cmp := range availableDynLibs {
			if cmp == "cpu_"+variant {
				dynLibs = append(dynLibs, availableDynLibs[cmp])
				break
			}
		}
	} else {
		dynLibs = append(dynLibs, availableDynLibs["cpu"])
	}
}
```

该实用程序在 `gpu/cpu_common.go` 中定义。它能检测 x86 平台上的 CPU 扩展：

```go
func GetCPUVariant() string {
	if cpu.X86.HasAVX2 {
		slog.Info("CPU has AVX2")
		return "avx2"
	}
	if cpu.X86.HasAVX {
		slog.Info("CPU has AVX")
		return "avx"
	}
	slog.Info("CPU does not have vector extensions")
	// else LCD
	return ""
}
```

该顺序将把 `avx2` 作为最高优先级，然后是 `avx`，最后是纯 CPU 变体。最后，如果上述方法都不奏效，它将回退到 CPU 变体：

```go
func getDynLibs(gpuInfo gpu.GpuInfo) []string {
	/* Apple specific loading */
	/* ... */

	// Finally, if we didn't find any matches, LCD CPU FTW
	if len(dynLibs) == 0 {
		dynLibs = []string{availableDynLibs["cpu"]}
	}
	slog.Debug(fmt.Sprintf("ordered list of LLM libraries to try %v", dynLibs))
	return dynLibs
}
```

然后，`dynLibs` 将被返回以进行加载尝试。

现在我们可以探讨一下如何生成 "GPU 信息" `gpuInfo`，从而使偏好成为可能。`llm/llm.go`中的 `New` 函数以 "GPU 信息" 为第一个参数调用 `newLlmServer`。它完成了许多重要工作：

1. 打开、加载并检测 LLM 的参数。
2. 加载 "GPU 信息"：`info := gpu.GetGPUInfo()`。
3. 检查 VRAM 和模型与硬件的兼容性。

初始检测在 2 中进行。不过，也有可能模型被标记为与模型不兼容。在这种情况下，它将回退到具有最快变体的 CPU：

```go
info.Library = "cpu"
info.Variant = gpu.GetCPUVariant()
```

让我们重点关注 2，看看在 `GetGPUInfo` 函数中发生了什么。

## Apple Metal

让我们从最特殊的平台开始。苹果 macOS 平台，包括 XNU 内核和用户空间，通常被称为 "Darwin"。

在前面提到的 `getDynLibs` 中，Darwin 平台上的检测非常简单：

```go
// Short circuit if we know we're using the default built-in (darwin only)
if gpuInfo.Library == "default" {
	return []string{"default"}
}
// TODO - temporary until we have multiple CPU variations for Darwin
// Short circuit on darwin with metal only
if len(availableDynLibs) == 1 {
	if _, onlyMetal := availableDynLibs["metal"]; onlyMetal {
		return []string{availableDynLibs["metal"]}
	}
}
```

It uses `default` library according to the "GPU information", or just use `metal`. The `gpu.GetGPUInfo()` is in `gpu/gpu_darwin.go`, as simple as possible:

它会根据 "GPU 信息" 使用 `default` 库，或者直接使用 `metal`。`gpu.GetGPUInfo()` 在 `gpu/gpu_darwin.go` 中，非常简单：

```go
func GetGPUInfo() GpuInfo {
	mem, _ := getCPUMem()
	if runtime.GOARCH == "amd64" {
		return GpuInfo{
			Library: "cpu",
			Variant: GetCPUVariant(),
			memInfo: mem,
		}
	}
	return GpuInfo{
		Library: "metal",
		memInfo: mem,
	}
}
```

我们可以看到，它获取内存信息，并检测 `ollama` 是否运行在英特尔 x86_64/amd64 平台上。如果是，它就会使用扩展速度最快的 CPU。否则，只有 ARM Mac 才能利用 Metal API 加速。

据我所知，英特尔 Mac 上的 AMD 显卡应该也支持 Metal。但 `ollama` 不会在英特尔 Mac 上使用它。可能只是因为驱动程序或显卡本身过时了。

## Nvidia CUDA 和 AMD ROCm

然后，我们看一下 Nvidia 和 AMD GPU 的通用检测，因为它们在 `ollama` 中是耦合在一起的。

实现方法在 `gpu/gpu.go`中：

```go
func GetGPUInfo() GpuInfo {
	// TODO - consider exploring lspci (and equivalent on windows) to check for
	// GPUs so we can report warnings if we see Nvidia/AMD but fail to load the libraries
	gpuMutex.Lock()
	defer gpuMutex.Unlock()
	if gpuHandles == nil {
		initGPUHandles()
	}

	// All our GPU builds on x86 have AVX enabled, so fallback to CPU if we don't detect at least AVX
	cpuVariant := GetCPUVariant()
	if cpuVariant == "" && runtime.GOARCH == "amd64" {
		slog.Warn("CPU does not have AVX or AVX2, disabling GPU support.")
	}

	var memInfo C.mem_info_t
	resp := GpuInfo{}
	/* Getting the actual GPU information */
	/* ... */
	/* Fallback to CPU if no GPU detected */
	/* ... */

	resp.DeviceCount = uint32(memInfo.count)
	resp.FreeMemory = uint64(memInfo.free)
	resp.TotalMemory = uint64(memInfo.total)
	return resp
}
```

第一个程序块调用 `initGPUHandles` 来定义要搜索的 GPU 库，以便使用它们获取 GPU 信息。对于 Nvidia，它会检测 Windows 上独立显卡的 `nvml.dll`，Linux 上的 `libnvidia-ml.so`，以及某些特殊设备上的 `libcudart.so*`，例如 [Jetson 系列](https://www.nvidia.com/fr-fr/autonomous-machines/embedded-systems/)（感谢 [最近的 PR](https://github.com/ollama/ollama/pull/2279)）。

第二个程序块检测 CPU 变体，它要求 CPU 至少有 `AVX` 变体才能支持 GPU。

然后，它会检查句柄，并使用相关库查找相应的 GPU。

对于 Nvidia 独立 GPU：

```go
if gpuHandles.nvml != nil && (cpuVariant != "" || runtime.GOARCH != "amd64") {
	C.nvml_check_vram(*gpuHandles.nvml, &memInfo)
	if memInfo.err != nil {
		slog.Info(fmt.Sprintf("[nvidia-ml] error looking up NVML GPU memory: %s", C.GoString(memInfo.err)))
		C.free(unsafe.Pointer(memInfo.err))
	} else if memInfo.count > 0 {
		// Verify minimum compute capability
		var cc C.nvml_compute_capability_t
		C.nvml_compute_capability(*gpuHandles.nvml, &cc)
		if cc.err != nil {
			slog.Info(fmt.Sprintf("[nvidia-ml] error looking up NVML GPU compute capability: %s", C.GoString(cc.err)))
			C.free(unsafe.Pointer(cc.err))
		} else if cc.major > CudaComputeMin[0] || (cc.major == CudaComputeMin[0] && cc.minor >= CudaComputeMin[1]) {
			slog.Info(fmt.Sprintf("[nvidia-ml] NVML CUDA Compute Capability detected: %d.%d", cc.major, cc.minor))
			resp.Library = "cuda"
		} else {
			slog.Info(fmt.Sprintf("[nvidia-ml] CUDA GPU is too old. Falling back to CPU mode. Compute Capability detected: %d.%d", cc.major, cc.minor))
		}
	}
}
```

它调用在 `gpu/gpu_info_nvml.c` 中实现的 C 函数 `nvml_check_vram`，以获取 VRAM。如果发现一个可用设备，它还会通过 `nvml_compute_capability` 检查计算能力，以确保该设备可用。

这样的设计使我无法在 Windows 下使用 ZLUDA 通过 `ollama` 在 AMD 显卡上运行 LLM。因为当时 ZLUDA 将此功能标记为未实现。然而，我的 AMD 显卡已经支持该功能。现在我不再需要 ZLUDA 了。

在本篇文章中，我选择跳过 `Cudart` 支持，因为它并不常见。现在让我们来看看最近令人兴奋的 AMD 支持！

针对 AMD 的 `GetGPUInfo` 代码非常简短：

```go
else {
	AMDGetGPUInfo(&resp)
	if resp.Library != "" {
		return resp
	}
}
```

你可能会注意到，这是一个 `else`。因此，与 `if` 子句一起，只有在未检测到 Nvidia 处理器的情况下，才会尝试 AMD。这将导致一个问题：当安装了 Nvidia GPU 库，但未检测到 GPU 或检测到的 GPU 不兼容时，AMD 显卡也永远不会被检测到。我为此开设了一个[问题](https://github.com/ollama/ollama/issues/3172)。

好了，让我们回到 `GetGPUInfo`。如果检测到 Nvidia 显卡，"GPU 信息" 中的 `Library` 将设为 `cuda`。如果是 AMD 显卡，则会设置为 `rocm` 。

因此，如果检测成功，"GPU 信息" 将与 `availableDynLibs` 配合，为 `cuda_*` 或 `rocm_*` 变体优先选择库路径。
这就揭示了 GPU 是如何被检测到的，以及从一堆动态库中创建 llama 服务器时可能使用的 GPU。

# Web service and client

# 网络服务和客户端

让我们来看看 "前端"！在 `ollama` 中确实没有所谓的前端。相反，它和其他大多数 LLM 服务一样，提供了一系列 Web API。

基本的 Web API 在`server`中实现，主要在`server/routes.go`模块中。完整的 API 可在 [GitHub](https://github.com/ollama/ollama/blob/main/docs/api.md) 上找到。在此，我们也仅以 chat 的 completion 端点为例，快速从 API 建立起到我们在上面解析过的部分的概览。这个端点定义如下：

```
r.POST("/api/chat", ChatHandler)
```

其中 `ChatHandler` 是处理请求的回调。它以 `var req api.ChatRequest` 结构创建并解析请求。处理程序会做很多事情，比如加载模型，以确保预测是可能的。

一切准备就绪后，最重要的事情就来了：

```go
// Start prediction
predictReq := llm.PredictOpts{
	Prompt:  prompt,
	Format:  req.Format,
	Images:  images,
	Options: opts,
}
if err := loaded.runner.Predict(c.Request.Context(), predictReq, fn); err != nil {
	ch <- gin.H{"error": err.Error()}
}
```

它用提示（用户输入、提示等）、图像和其他选项准备预测请求。然后，它调用 runner 的 `Prediction` 函数，其中 runner 需要实现 `llm` 模块下的 `LLM` 接口：

```go
var loaded struct {
	mu sync.Mutex

	runner llm.LLM

	expireAt    time.Time
	expireTimer *time.Timer

	*Model
	*api.Options
}
```

`LLM` 接口的定义如下：

```go
type LLM interface {
	Predict(context.Context, PredictOpts, func(PredictResult)) error
	Embedding(context.Context, string) ([]float64, error)
	Encode(context.Context, string) ([]int, error)
	Decode(context.Context, []int) (string, error)
	Close()
}
```

`Predict` 的实现来自 [预测](#预测)一节中描述的 `dynExtServer`。然后，它将调用 `dyn_llama_server_completion` 从动态库中请求启动 llama 服务器。

## Ollama 的 Go API

在项目内部，`ollama` 在 Go 的 `api` 下直接提供了一个封装。用户可以利用它更方便地调用网络 API。事实上，`ollama` 本身也使用 Go 封装提供实际的前端——终端用户界面。

此外还有 Python 和 JavaScript/TypeScript 绑定：
- [https://github.com/ollama/ollama-python](https://github.com/ollama/ollama-python)
- [https://github.com/ollama/ollama-js](https://github.com/ollama/ollama-js)

## OpenAI API 封装器

尽管有本地 API 端点，`ollama` 还在 `server/routes.go` 中提供了与 OpenAI API 兼容（部分兼容）的端点：

```
// Compatibility endpoints
r.POST("/v1/chat/completions", openai.Middleware(), ChatHandler)
```

它实际上是从 OpenAI 请求到 `ollama` 本机请求的转换器，反之亦然。 如果您感兴趣，可以查看 `openai/openai.go`。

# 其他实用程序

终端 UI 利用 Web API 端点的 Go 包装器来提供基于终端的对话。 它需要一些实用程序，例如 `readline` 来与终端中的用户输入进行交互，以及 `progress`来显示进度。

此外，还有用于 API 端点认证的 `auth`，用于cli命令提供者的 `cmd`，用于单位转换的 `format`，用于模型文件解析的 `parser` 等。可以根据您的意愿详细查看源代码。这篇文章已经足够长了，并且只关注 `ollama` 的整体架构。我也希望看到有关它的其他帖子 ;)

# 结论

最后，我会在运行前得到一个关于 `ollama` 架构的简单图：

{% asset_img ollama.drawio.svg ollama 架构 %}

我仍要说：`ollama` 是 `llama.cpp` 的一个薄（也许不是那么薄）但足够智能的封装。
尽管它仍然有一些缺点，但我们确实需要尽可能多的此类封装，以使最终用户的生活更轻松。
