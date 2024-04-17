---
title: On the architecture of ollama
date: 2024-04-15 15:34:00
tags:
- LLM
- ollama
categories:
- [AI, LLM]
---

Recently, I took a chance to explore `ollama` project, because I want to enable the support of my AMD graphic card (with a not bad VRAM - 32G!) on Windows. There is already the support on Linux, based on AMD ROCm. It should be kind of out-of-box on Windows, thanks to the release of ROCm on Windows. But `ollama` prevents me from using it. So, I tried both ZLUDA and modified the code of `ollama` to get what I wanted.

This feature is already merged and released in [ollama v0.1.29](https://github.com/ollama/ollama/releases/tag/v0.1.29). To avoid missing the details and the things I 've learnt, this blog is in charge of noting the architecture of `ollama` for myself. 

To me, `ollama` is a thin but smart enough wrapper to [llama.cpp](https://github.com/ggerganov/llama.cpp). **It is really end-user friendly, and provides a web interface and a cli interface, in order to run and interact with a lot of Large Language Models (LLMs).** Indeed, in most cases, it's `llama.cpp` who loads and runs the models, and `ollama` just "pilots" (yes, I use a term that AI generations are familiar with) the `llama.cpp`. I will give a discussion about this part later.

This post assumes that you are able to read golang code or some other C-like code. For special points in the code, I would give some brief descriptions or metaphors for better understanding.

<!-- ToC -->
In this post, I will first give the project structure of `ollama`. Then, the core architecture and implementations around `llama.cpp` along with the build systems will be described. Next, I will describe how `ollama` chooses the device (hardware in general) to run an LLM. Finally, the web service, client and the utilities along with the other parts will be introduced, to finish the post.

# Project structure

You can get [the source code of ollama on GitHub](https://github.com/ollama/ollama). The project is mainly written in Golang. Here is a table of brief descriptions for each directory:

<!-- Dir structure -->
| Dir name    | Description                          |
| ----------- | ------------------------------------ |
| api         | Client API lib in go                 |
| app         | Desktop application (mainly a tray)  |
| auth        | Authentication                       |
| cmd         | Commands and handlers                |
| docs        | Documentations                       |
| examples    | Examples to use ollama               |
| format      | Utility to format units and time     |
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

The `llama.cpp` project [itself](https://github.com/ggerganov/llama.cpp) is an Open Source library for the inference of Meta's LLaMA model in pure C/C++, at very first. And it is extended to run more models, such as Mistral, and Google Gemma (supported very recently). It leverages the capability of [ggml](https://github.com/ggerganov/ggml), another project created by the same author, to run it natively on different platforms (compared to Python project).

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

Apart from pure go code, the go build systems need `cgo` to build some C-family code as well. There are examples in `llm` directory (`dyn_ext_server.c` file to load and provide interfaces) and `gpu` directory (`gpu_info_cuda.c`, `gpu_info_rocm.c` and `gpu_info_darwin.m` are C or Objective-C implementations to detect GPUs).

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

After the build by `cmake`, it will make a `libext_server` dynamic library (`.dll` on Windows, `.so` on Linux/BSD, and `.dylib` on macOS). The library contains the compiled code from `examples/server` under `llama.cpp` (`examples/server/libext_server.a`), command and core code of `llama.cpp` - `common/libcommoa.a` and `libllama.a`. They will be embedded into the main go program to facilitate the distribution, as "payloads" of the executable.

Finally, it compresses the payloads to make the executable smaller:

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
3. The libraries are embedded into the go program using [go embed package](https://pkg.go.dev/embed), and extract during the runtime.
4. Besides, the calls to the functions in `ext_server` carry the some parameters defined in `llm` directory. In general, the requests and responses are passed in JSON format, and contains more structural information. They are defined in such as `ggml.go` (describing the models) and `llama.go` (describing the different requests and responses).
5. To dynamically manage the `llama.cpp` instances, `ollama` provides some patches to the original `llama.cpp`.

Let's study them one by one.

## 1. External server

We first take a look at `ext_server`. We already know that the dynamic libraries are built during the generation. But how will they be used?

In `llm/dyn_ext_server.go`, the `newDynExtServer` is in charge of loading the dynamic libraries, initialize a `llama.cpp` instance and start the event loop to receive any requests and generate the responses.

### Dynamic library loading and server starting

In `newDynExtServer`, the go function calls a C function named by `dyn_init` to load the dynamic library. The description and the needed functions are loaded into a `struct_dynamic_llama_server` description, and wrapped in `dynExtServer`, a go struct.

They are then used in a another C function, `dyn_llama_server_init`, with the parameters to run a `llama.cpp` server, for the server instance initialization.

Without issue, `newDynExtServer` will call the last C function during the initialization, `dyn_llama_server_start`. The server will be running and is then able to receive requests from `ollama`.

The aforementioned C functions are in `llm/dyn_ext_server.c` and declared in `llm/dyn_ext_server.h`. Let's take a quick look at `dyn_init`:

```c
void dyn_init(const char *libPath, struct dynamic_llama_server *s,
                       ext_server_resp_t *err);
```

It accepts a library path `libPath` as argument, and returns a `dynamic_llama_server` instance or an error through the C pointers (or memory address to those who are not familiar with C, go is able to handle them like go struct, store them and pass to the other C functions).

The `dynamic_llama_server` struct is capable of storing the address of necessary C functions, and the reference to the loaded dynamic library. Its definition is as below:

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

The core functionality of `dyn_init` is to load a dynamic library indicated by `libPath`, read the symbol tables, find the addresses of needed C functions, and store them into an instance of `dynamic_llama_server` structure. The `libPath` could be the path of one of the built dynamic libraries with the `libext_server` prefix. So that the built libraries based on `llama.cpp` can be used by `ollama`.

Once loaded, the calls to `dyn_llama_server_start` and `dyn_llama_server_start` are indeed direct calls to the C functions from the dynamic libraries:

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

After calling `dyn_llama_server_start`, the `llama.cpp` server created from a dynamic library is ready to make predictions.

### Prediction

When `ollama` receives a prediction request, it calls `Predict` on a `dynExtServer` instance. This function is able to formats the request (will see this later), and calls a C function, `dyn_llama_server_completion`, for start the prediction:

```c
inline void dyn_llama_server_completion(struct dynamic_llama_server s,
                                                 const char *json_req,
                                                 ext_server_resp_t *resp) {
  s.llama_server_completion(json_req, resp);
}
```

As you see, it's also a direct call to the function loaded from one of the dynamic libraries built on top of `llama.cpp`.

A really good design in this part is the stream-like response, thanks to the `fn func(PredictResult)` argument in the `Predict` function. It is a callback function, which allows to send continuously the responses as soon as it gets:

```go
if p.Content != "" {
  fn(PredictResult{
    Content: p.Content,
  })
}
```

It also relies on the convenient call to `dyn_llama_server_completion_next_result` (although it's also a direct call to a loaded C function `llama_server_completion_next_result` from a dynamic library based on `llama.cpp`).

### Others

The other calls are similar as well. You can find them in `llm/dyn_ext_server.go` and `llm/dyn_ext_server.c`, such as `dyn_llama_server_tokenize`, `dyn_llama_server_detokenize` for tokenization or detokenization, and `dyn_llama_server_embedding` for computing the embeddings.

## 2. `llama.cpp` as a server for `ollama`

Let's next check the C parts: how `ollama` uses `llama.cpp` as an LLM server.

In the beginning of `llm/dyn_ext_server.go`, there are a bench of build instructions in the comments for cgo:

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

They are able to set different build and link flags for different platforms (`darwin` for macOS, and of course `linux` for Linux while `windows` for Windows). So that cgo is able to find the C header files (declarations of the existing types and functions) to compile and link `llm/dyn_ext_server.c` with the go parts.

Let's then go to check the C functions used in `ollama`, from the dynamic library. As two examples, we start with `llama_server_init` and `llama_server_start`.

Their implementations are located in `llm/ext_server/ext_server.cpp`, which is set as a library target named by `ext_server` in `llm/ext_server/CMakeLists.txt`. During the building the target, this file will be compiled with `llama.cpp` example server together. The compiled result is one of the dynamic libraries that we mentioned.

As a result, the C functions in `ext_server.cpp` can be called from `ollama`, and are able to leverage the functions in `llama.cpp`. It actually acts as a bridge between the two projects, and **makes the example server in `llama.cpp` a server for `ollama`**.

During the initialization, `llama_server_init` parses the parameters to create a context for the server, and calls the functions provided by `llama.cpp`:

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

For example, it calls `llama_backend_init` to initialize the backend (could be AVX, CUDA, etc), and `llama_numa_init` to initialize the NUMA (if exists). Then it calls the `load_model` function in the server context with the given parameters to load the model and finalize the initialization with `initialize` function.

In case of error, the error messages are formatted to the `err` argument to return and be processed in go parts.

Meanwhile in `llama_server_start`:

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

It sets some callbacks for the task processing, and starts an event loop in a new thread. The event loop is in charge of the predictions. So that the call to `llama_server_start` is returned immediately.

More detailed implementations of such C functions can be found in the same file, i.e. `llm/ext_server/ext_server.cpp`.

## 3. Embed libraries as payloads

Then, let's explore how the payloads are done.

In the go files with `payload_*` prefix, we can see the choice of `ollama`. For instance, there is two lines to embed every `ext_server` libraries with different variants in `llm/payload_linux.go`:

```go
//go:embed llama.cpp/build/linux/*/*/lib/*
var libEmbed embed.FS
```

All the built libraries under `llama.cpp/build/linux/*/*/lib/` are embedded as payloads using a [filesystem like interface](https://pkg.go.dev/embed#hdr-File_Systems). So that `ollama` can access them like reading and writing in a filesystem.

During the initialization of `ollama`, `Init` in `llm/payload_common.go` will call `nativeInit`:

```go
func Init() error {
	return nativeInit()
}
```

It mainly works on extracting the dynamic libraries from the file system to a temporary location, and check driver access permission if applicable:

```go
libs, err := extractDynamicLibs(payloadsDir, "llama.cpp/build/*/*/*/lib/*")
/* ... */
err := verifyDriverAccess()
```

After the extraction, `ollama` is able to format the library path (`libPath` used in the `dyn_init` function in the [External server](#1-external-server) subsection). The way to choose the running environment and the matching library will be presented in the [Decide where to run](#decide-where-to-run) section.

## 4. Formatted request and response

Let's then go back to the function arguments used in the C functions.

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

In their function signatures, we can see the function arguments they use: `ext_server_params_t` in `dyn_llama_server_init`, and a `json_req` byte array in `dyn_llama_server_completion`.

The `ext_server_params_t` argument is a C struct carrying the configurations to launch the llama server, which will be interpreted later in `llm/ext_server/server.cpp`(We do not expand this part due to shortage of pages).

Meanwhile, the `json_req` for the completion call is used as follows, in `llm/ext_server/ext_server.cpp`:

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

Indeed, it contains the completion request in json format, including the prompt, temperature, etc. We can see that `llama_server_completion` creates a task for it and return the task ID through `resp` in the normal path. Otherwise, it formats the error information for returning.

If you are interested in its detailed format, please check `llm/dyn_ext_server.go` file.

## 5. Patches

There are a few extra modifications on the original version of `llama.cpp`, to adapt the usage of multiple llama servers in `ollama`.

For example, the following patch exports `ggml_free_cublas` and call it to release an instance of llama server:
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

## Wrap them up

With all the extra modules and modifications on `llama.cpp`, `ollama` is thus able to start a llama server as needed, dynamically choosing the hardware with the supports of different hardware in the different compiled dynamic libraries (see [Build system](#build-system)). After running the llama server, the extra modules provided by `ollama` allow to send the completion request, and retrieve the replies later.

Til now, it should be clear with a global view on the `ollama` architecture behind (or we can call it backend, as usual). For the details in the backend, readers can check the source code since they are subjective to be changed very often. After all, `ollama` is under active development.

There are still a few mysteries:

- backend side: how `ollama` knows which hardware and which dynamic libraries to choose?
- frontend side: which kind of frontend does it provide?

The following sections might be the answers for these questions.

# Decide where to run

Let's go back to the dynamic libraries and `libPath` argument in the `dyn_init`, mentioned in [Dynamic library loading and server starting](#dynamic-library-loading-and-server-starting). We have already known in [Embed libraries as payloads](#3-embed-libraries-as-payloads), that `ollama` will extract the embedded dynamic libraries to a temporary directory, and load them by formatting and passing `libPath` to `dyn_init`.

The question is: how `ollama` chooses the libraries by passing the different `libPath` argument?

The `libPath` is passed as the first argument `library` in the `newDynExtServer` function implemented in `llm/dyn_ext_server.go`. It is updated on Windows by a call to `gpu.UpdatePath(filepath.Dir(library))`, in order to add the parent directory to the `PATH`. So that the dynamic libraries can be loaded seamlessly. However, it's not necessary to do so on Linux or macOS.

Therefore, we can know that the `libPath` here is already a full path to the dynamic library files. Let's then check where the `libPath` is generated.

A simple search gives a response in the `newLlmServer` function under `llm/llm.go`:

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

It iterates the `dynLibs` to call `newDynExtServer` function. Once there is one successful loading, it returns the llama server instance.

At the beginning of `newLlmServer`, the `dynLibs` are generally retrieved in `getDynLibs` function, which is an ordered list of dynamic libraries to try:

```go
func newLlmServer(gpuInfo gpu.GpuInfo, model string, adapters, projectors []string, opts api.Options) (LLM, error) {
	dynLibs := getDynLibs(gpuInfo)
	/* ... */
}
```

The order is a preference, which takes the GPU information from `gpuInfo gpu.GpuInfo`. It is not forced to be the "GPU information", it can also indicate to use a certain CPU variant. I think `ollama` team may change it very soon.

In general, the returned `dynLibs` are from a key-value mapping `availableDynLibs` in `llm/payload_common.go`. It is generated in `nativeInit`, after the extraction of all the dynamic libraries:

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

The key is the last component of the full path, except the library file name. For example, it is be `cpu`, `cpu_avx`, `cpu_avx2`, `cuda_v11.3` and `rocm_v5.7` on my PC. And the values are certainly the full path.

We can first take a look at the general processing in `getDynLibs` function(which is implemented in `llm/payload_common.go`), by ignoring some platform-specific cases.

The first step is to find the exact match of the requested one from the "GPU information":

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

It makes a `requested` string by `Library` with an appended `Variant` from the "GPU information". If there is one matched exactly to the `requested` string, the first library path in `dynLibs` would be the path to the requested library. The first library path will also be the first to try during the loading.

It then tries GPU libraries with not exact matches (where there could be some version mismatches, etc.):

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

Next, it tries to prioritize the fastest (maybe) CPU variant by calling another utility function `GetCPUVariant`:

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

This utility is defined in `gpu/cpu_common.go`. It detects the CPU extensions on x86 platform:

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

The order will give `avx2` as the highest preference, then `avx`, and finally the pure CPU variant.

Finally, it fallbacks to CPU variant if none of the above methods work:

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

The `dynLibs` are then returned for the loading tries.

We can now explore how the "GPU information" `gpuInfo` is generated to make the preference possible. The `New` function in `llm/llm.go` calls `newLlmServer` with the "GPU information" as the first argument. It completes many important works:

1. Open, load and detect the parameters of an LLM.
2. Load "GPU information": `info := gpu.GetGPUInfo()`.
3. Check the VRAM and the compatibility of the model to the hardware.

The initial detection is performed in 2. However, it is also possible that the model is marked as incompatible to the model. In this case, it will fallback to the CPU with the fastest variant:

```go
info.Library = "cpu"
info.Variant = gpu.GetCPUVariant()
```

Let's only concentrate on 2, to see what happened in the `GetGPUInfo` function.

## Apple Metal

Let's start with the most special platform. Apple macOS platform, including the XNU kernel and the userspace, is usually called `darwin`.

In the aforementioned `getDynLibs`, the Darwin detection is very simple:

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

We can see that, it gets the memory information and detects whether `ollama` is running on the Intel x86_64/amd64 platform. If so, it just uses the CPU with the fastest extension. Otherwise, only ARM Mac can leverage the Metal API to accelerate.

From my best know, the AMD graphic cards on Intel Mac should also have Metal support. But it will not be used on Intel Mac by `ollama`. Probably, it's just due to the outdated drivers or the outdated graphic cards itself.

## Nvidia CUDA and AMD ROCm

We then check the general detection of Nvidia and AMD GPUs, since they are kind of coupled together in `ollama`.

The implementation is in `gpu/gpu.go`:

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

The first block calls `initGPUHandles` to define the GPU libraries to search, in order to use them to get the GPU information. For Nvidia, it detects `nvml.dll` for discrete graphic cards on Windows, `libnvidia-ml.so` on Linux, and `libcudart.so*` on some special devices, such as [Jetson family](https://www.nvidia.com/fr-fr/autonomous-machines/embedded-systems/) (thanks to [a recent PR](https://github.com/ollama/ollama/pull/2279)).

The second block detects the CPU variant, it somehow requires at least `AVX` variant from the CPU to enable the GPU support.

It then checks the handles and uses the libraries to lookup GPUs accordingly.

For Nvidia discrete GPUs:

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

It calls a C function `nvml_check_vram` implemented in `gpu/gpu_info_nvml.c` to get the VRAM. If found one usable device, it will also check the compute capability through `nvml_compute_capability`, to make sure that the device is usable.

This design has prevented me from using ZLUDA to run an LLM through `ollama` on my AMD graphic card on Windows. Because ZLUDA was marking this function as unimplemented at that time. However, there is already the support to my AMD graphic card. I do not need the ZLUDA anymore now.

I just would just skip the `Cudart` support because it's not a common case. Let's go through the recent exciting AMD support now!

The code in `GetGPUInfo` for AMD is very short:

```go
else {
	AMDGetGPUInfo(&resp)
	if resp.Library != "" {
		return resp
	}
}
```

You may notice that it is an "else". So, along with the "if" clause, AMD will be tried, only if Nvidia handle is not detected. This would cause an issue: when there are Nvidia GPU libraries installed, however no GPU detected or the detected GPUs are not compatible, AMD graphic cards would never be detected as well. I opened an [issue for this](https://github.com/ollama/ollama/issues/3172).

OK, let go back to the `GetGPUInfo`. If Nvidia graphic card is detected, the `Library` in the "GPU information" will be set to `cuda`. For AMD, it will be `rocm`.

So, if the detection succeeded, the "GPU information" will work with the `availableDynLibs` to prioritize the library paths for `cuda_*` or `rocm_*` variants.
That unveils how the GPUs are detected and potentially used when creating the llama servers from a bunch of dynamic libraries.

# Web service and client

Let's then take a look at the "frontend"! There is indeed no so-called frontend in `ollama`. Instead, it provides a bench of Web APIs, just like most of the other LLM services.

The basic Web APIs are implemented in `server`, mostly in the `server/routes.go` module. The full API endpoints are available at [GitHub](https://github.com/ollama/ollama/blob/main/docs/api.md). Here, we also just take the chat completion endpoint as a quick example to build the view from the API endpoint to what we have seen above. The endpoint is defined as:

```
r.POST("/api/chat", ChatHandler)
```

where `ChatHandler` is a callback to handle the request. It creates and parses the request in a `var req api.ChatRequest` struct. The handler will do a lot of things such as loading the model, to make sure that the prediction is possible.

When everything is ready, the most important thing is here:

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

It prepares the prediction request with the prompt (user inputs, prompts, etc.), images, and other options. Then it calls the `Prediction` function of runner, where the runner needs to implement the `LLM` interface under the `llm` module:

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

The `LLM` interface is:

```go
type LLM interface {
	Predict(context.Context, PredictOpts, func(PredictResult)) error
	Embedding(context.Context, string) ([]float64, error)
	Encode(context.Context, string) ([]int, error)
	Decode(context.Context, []int) (string, error)
	Close()
}
```

And the implementation of `Predict` is from `dynExtServer` described in [Prediction](#prediction) section. It will then call `dyn_llama_server_completion` and thus request the started llama server from one of the dynamic libraries.

So, we have the link now.

## Go API of Ollama

Intrinsically, `ollama` provides a wrapper in Go under `api`. Users can leverage it to call the Web APIs easier. Indeed, `ollama` itself also uses the Go wrapper to provide the actual frontend - a terminal UI.

There are also Python and JavaScript/TypeScript bindings:
- [https://github.com/ollama/ollama-python](https://github.com/ollama/ollama-python)
- [https://github.com/ollama/ollama-js](https://github.com/ollama/ollama-js)

## OpenAI API wrapper

Despite of the native API endpoints, `ollama` also provides an OpenAI API-compatible (well, partially compatible) endpoint in `server/routes.go`:

```
// Compatibility endpoints
r.POST("/v1/chat/completions", openai.Middleware(), ChatHandler)
```

It's indeed a convertor from OpenAI requests to `ollama` native requests, and vice-versa for responses. You can check `openai/openai.go` if it's interesting to you.

# Other utilities

The terminal UI leverages the Go wrapper of the Web API endpoints to provide a terminal-based conversations. It needs some utilities such as `readline` to interact with the user inputs in the terminal, and `progress` to show the progress.

There are also the `auth` for API endpoint authentication, `cmd` for cli commands provider, `format` for unit conversion, `parser` for model file parsing, etc. Check them in detail as your wish. This post has been long enough and just concentrate on the overall architecture of `ollama`. I am also eager to seeing the other posts about it ;)

# Conclusion

Finally, I would end up with a simple figure for the `ollama` architecture before runtime:

{% asset_img ollama.drawio.svg ollama arch %}

I would say as well: `ollama` is a thin (maybe not so thin) but smart enough wrapper of `llama.cpp`.
Although it still has a few drawbacks, we really need as many these kinds of wrappers as possible, to make the life easier for any end-users.
