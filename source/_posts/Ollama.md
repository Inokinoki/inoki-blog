---
title: On the architecture of ollama
date: 2024-03-24 15:34:00
tags:
- LLM
categories:
- [AI, LLM]
---

Recently, I took a chance to explore `ollama` project, because I want to enable the support of my AMD graphic card (with a not bad VRAM - 32G!) on Windows. There is already the support on Linux, based on AMD ROCm. It should be kind of out-of-box on Windows, thanks to the release of ROCm on Windows. But `ollama` prevents me from using it. So, I tried both ZLUDA and modified the code of `ollama` to get what I wanted.

This feature is already merged and released in [ollama v0.1.29](https://github.com/ollama/ollama/releases/tag/v0.1.29). To avoid missing the details and the things I 've learnt, this blog is in charge of noting the architecture of `ollama` for myself. 

To me, `ollama` is a thin but smart enough wrapper to [llama.cpp](https://github.com/ggerganov/llama.cpp). **It is really end-user friendly, and provides a web interface and a cli interface, in order to run and interact with a lot of Large Language Models (LLMs).** Indeed, in most cases, it's `llama.cpp` who loads and runs the models, and `ollama` just "pilots" (yes, I use a term that AI generations are famaliar with) the `llama.cpp`. I will give a talk about this part later.

<!-- ToC -->
In this post, I will

# Porject structure

You can get [the source code of ollama on GitHub](https://github.com/ollama/ollama). The project is mainly written in Golang. Here is a table of brief descriptions for each directory:

<!-- Dir structure -->
| Dir name    | Description                          |
| ----------- | ------------------------------------ |
| api         | Client API lib in go                 |
| app         | Desktop application (mainly a tray)  |
| auth        | Authentification                     |
| cmd         | Commands and handlers                |
| docs        | Documentations                       |
| examples    | Examples to use ollama               |
| format      | Utitility to format units and time   |
| gpu         | GPU and acceleration detection       |
| llm         | Implementations to run llama.cpp     |
| macapp      | Desktop application for Mac          |
| openai      | OpenAI API wrapper for ollama        |
| parser      | Model information and message parser |
| progress    | Utility to show loading progress     |
| readline    | Utility to read inputs from terminal |
| scripts     | Scripts for build and publish        |
| server      | Server implementation in go          |
| version     | Version information                  |

Notice that the directories can be changed anytime, since the project is under active development.

# The hero behind: llama.cpp

Let's first start by an introduction to the core, `llama.cpp`.

The `llama.cpp` is included as a submodule in `ollama`. You can find it in `llm` directory. There are also the needed files around it in the same directory. We will see them in details later.

The `llama.cpp` project [itself](https://github.com/ggerganov/llama.cpp) is an Open Soource library for the inference of Meta's LLaMA model in pure C/C++, at very first. And it is extended to run more models, such as Mistral, and Google Gemma (supported very recently). It leverages the capability of [ggml](https://github.com/ggerganov/ggml), another project created by the same author, to run it natively on different platforms (compared to Python project).

## Supported backends

Currently, some of the supported inference backends in `llama.cpp` are as follows  through `ggml`:

- It can run **AVX, AVX2 and AVX512** on x86 for `llama.cpp`, or **NEON** on ARM.
- With MPI (e.g. MPICH and OpenMPI), `ggml` allows to run models on CPU or CPU clusters.
- **Apple Metal** is integrated to support GPUs on macOS and iOS, including GPUs on Mac and Apple made GPU on iOS devices or Apple Silicon Mac.
- An old open standard, **OpenCL** is used by `ggml` based on the BLAS architecture.
- **NVIDIA GPU**s are supported by `cuBLAS`.
- Recent **AMD GPU**s are supported through `hipBLAS`, which is parts of [AMD ROCm](https://www.amd.com/en/products/software/rocm.html) with almost same APIs as `cuBLAS`.
- What caught my attention recently, is the Vulkan support in `llama.cpp`. The (buggy) support was initially started by Nomic through their kompute framework. The recent progress is a [pure implementation](https://github.com/ggerganov/llama.cpp#vulkan) in `ggml` using the Vulkan libs directly.

These backends allow developers to run LLMs that work across multiple platforms, from desktop computers to smartphones and beyond. Additionally, `llama.cpp` also provides native support for Linux (including Android Linux), Windows, macOS, and various other operating systems, such as iOS (see [whispher.cpp on iOS](https://github.com/ggerganov/whisper.cpp/tree/master/examples/whisper.objc)) and even WebAssembly ([whispher.wasm](https://github.com/ggerganov/whisper.cpp/tree/master/examples/whisper.wasm)).

Therefore, it should be very nature that `ollama` is born with the supports of the platforms and operating systems.

# Build system

Next, let's take a look at the build system to know how `ollama` plays with `llama.cpp`.

C or Cpp projects usually come up with `cmake` (although there are more choices now) to handle the compilation, linking, etc. So does `llama.cpp`: it uses compile definitions (or flags) to leverage different backends. For instance:

- `LLAMA_AVX`, `LLAMA_AVX2`, `LLAMA_AVX512` for the AVX supports;
- `LLAMA_METAL` for the Apple Metal support;
- `LLAMA_CUBLAS` for the NVIDIA CUDA support;
- and `LLAMA_HIPBLAS` for the AMD ROCm support.

However, `ollama` itself is a go project leveraging the build system provided by go. Both of the two build systems co-exist to build the different parts:

- `cmake` builds `llama.cpp` with a few files from `ollama.cpp`, to pilot and provide interfaces;
- go build systems compile, link and pack the rest parts to make an application and cli of `ollama`.

Aparts from pure go code, the go build systems need `cgo` to build some C-family code as well. There are examples in `llm` directory (`dyn_ext_server.c` file to load and provide interfaces) and `gpu` directory (`gpu_info_cuda.c`, `gpu_info_rocm.c` and `gpu_info_darwin.m` are C or Objective-C implementations to detect GPUs).

The go build system in `ollama` also run the commands to call `cmake` for the `llama.cpp` building, by leveraging [go generate](https://go.dev/blog/generate). This work lays in the `llm/generate` directory, e.g. on Linux:

```
package generate

//go:generate bash ./gen_linux.sh
```

`llm/generate/generate_darwin.go` tells go generate to run the `gen_linux.sh` script to build the `llama.cpp` part.

## Some scripts for different platforms

Currently, there are `gen_common.sh`, `gen_linux.sh` and `gen_darwin.sh` to build `llama.cpp` for `ollama` on Unix-like OS, such as macOS and Linux. Meanwhile, it's `gen_windows.ps1` PowerShell script on Windows.

Let's take an example to build `llama.cpp` with AVX support on Linux:

```shell
init_vars
CMAKE_DEFS="${COMMON_CPU_DEFS} -DLLAMA_AVX=on -DLLAMA_AVX2=off -DLLAMA_AVX512=off -DLLAMA_FMA=off -DLLAMA_F16C=off ${CMAKE_DEFS}"
BUILD_DIR="${LLAMACPP_DIR}/build/linux/${ARCH}/cpu_avx"
echo "Building AVX CPU"
build
compress_libs
```

The first three lines initialize the variables to prepare the build. The `init_vars` calls a sub-procedure in `gen_common.sh` to prepare common variables such as:

```shell
CMAKE_DEFS=""
CMAKE_TARGETS="--target ext_server"
```

where `CMAKE_TARGETS` will set the build target to `ext_server`. This target is a library to provide interfaces and functions from `llama.cpp` to `ollama`, we will talk about it in the next section.

In `CMAKE_DEFS`, only `LLAMA_AVX` is enabled. And `COMMON_CPU_DEFS` is defined as follows, to make dynamic library with position independent code (for gcc it will be converted to a `-fpic` flag):

```shell
COMMON_CPU_DEFS="-DCMAKE_POSITION_INDEPENDENT_CODE=on -DLLAMA_NATIVE=off"
```

It outputs "Building AVX CPU" in the terminal. The `build` sub-procedure then calls `cmake`:

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

After the build by `cmake`, it will make a `libext_server` dynamic library (`.dll` on Windows, `.so` on Linux/BSD, and `.dylib` on macOS). The library contains the compiled code from `examples/server` under `llama.cpp` (`examples/server/libext_server.a`), command and core code of `llama.cpp` - `common/libcommoa.a` and `libllama.a`.

Finally, it compresses the generated library:

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

# Pilot llama.cpp

Then, let us go back to the `llm` directory, to see the implementations in `ollama` built on top of `llama.cpp`.

The most important parts for `ollama` to pilot `llama.cpp` are:

1. In `ext_server`, the wrapper implementations provides the functions that `ollama` can call, such as `llama_server_init` to init an `llama.cpp` instance, `llama_server_completion` to complete a chat, or `llama_server_embedding` to compute the embeddings for texts.
2. An extra makefile (`CMakeLists`) is also contained in `ext_server`, to build the code with the `llama.cpp/examples/server` example as a library. It can then be loaded by `dyn_ext_server` code under `llm`, to serve with the `llama.cpp` instance.
3. The calls to the functions in `ext_server` carry the "payloads", which are defined in the `payload_*` files under `llm` directory. In general, the requests and responses are passed in JSON format, and contains more structural information. They are defined in such as `ggml.go` (decribing the models) and `llama.go` (describing the different requests and responses).
4. To dynamically manage the `llama.cpp` instances, `ollama` provides some patches to the original `llama.cpp`.

Let's study them one by one.

## 1. External server

We first take a look at `ext_server`.

We already know that the dynamic libraries are built during the generation. But how will they be used?

In `llm/dyn_ext_server.go`
Call `newDynExtServer`.

Call `dyn_init` to load the dynamic library

the exported functions that are needed to be found are

```c
// Initialize the server once per process
// err->id = 0 for success and err->msg[0] = NULL
// err->id != 0 for failure, and err->msg contains error message
void llama_server_init(ext_server_params_t *sparams, ext_server_resp_t *err);

// Run the main loop, called once per init
void llama_server_start();
// Stop the main loop and free up resources allocated in init and start.  Init
// must be called again to reuse
void llama_server_stop();

// json_req null terminated string, memory managed by caller
// resp->id >= 0 on success (task ID)
// resp->id < 0 on error, and resp->msg contains error message
void llama_server_completion(const char *json_req, ext_server_resp_t *resp);

// Caller must call llama_server_release_task_result to free resp->json_resp
void llama_server_completion_next_result(const int task_id,
                                         ext_server_task_result_t *result);
void llama_server_completion_cancel(const int task_id, ext_server_resp_t *err);
void llama_server_release_task_result(ext_server_task_result_t *result);

// Caller must call llama_server_releaes_json_resp to free json_resp if err.id <
// 0
void llama_server_tokenize(const char *json_req, char **json_resp,
                           ext_server_resp_t *err);
void llama_server_detokenize(const char *json_req, char **json_resp,
                             ext_server_resp_t *err);
void llama_server_embedding(const char *json_req, char **json_resp,
                            ext_server_resp_t *err);
void llama_server_release_json_resp(char **json_resp);
```

Call `dyn_llama_server_init` in the dynamic library

When predict

`Predict`

with a callback function

`dyn_llama_server_completion`

`dyn_llama_server_completion_next_result`

The other calls are similar. You can find them in `llm/dyn_ext_server.go` and `llm/dyn_ext_server.c`.

## 2. `llama.cpp` as a server for `ollama`

CMakeLists embed

when start

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

## 3. Payloads



## 4. Patches

For example, the following patch exports `ggml_free_cublas` and call it to release the instance:
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

# Decide where to run

How to choose the libraries

## Apple Metal

Apple

## Nvidia CUDA

NVIDIA

## AMD ROCm

AMD

# Web service and client

In `server`, `api`

# Other utilities

auth, cmd, format, parser, progress, readline

## `format` module

## OpenAI API wrapper

openai model

# Conclusion

At the end, I would end up with a simple figure for the `ollama` architecture:

{% asset_img ollama.drawio.svg ollama arch %}

I would say as well: `ollama` is a thin but smart enough wrapper of `llama.cpp`.
Although it still has a few drawbacks, we still need as many these kinds of wrappers as possible, to make the life easier for any end-users.
