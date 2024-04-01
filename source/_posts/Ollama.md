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

To me, `ollama` is a thin but smart enough wrapper to [llama.cpp](https://github.com/ggerganov/llama.cpp). **It is really end-user friendly, and provides a web interface and a cli interface, in order to run and interact with a lot of Large Language Models (LLMs).** Indeed, in most cases, it's `llama.cpp` who loads and runs the models, and `ollama` just "pilots" (yes, I use a term that AI generations are famaliar with) the `llama.cpp`. I will give a discussion about this part later.

This post assumes that you are able to read golang code or some other C-like code. For special points in the code, I would give some brief descriptions or metaphores for better understanding.

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

After the build by `cmake`, it will make a `libext_server` dynamic library (`.dll` on Windows, `.so` on Linux/BSD, and `.dylib` on macOS). The library contains the compiled code from `examples/server` under `llama.cpp` (`examples/server/libext_server.a`), command and core code of `llama.cpp` - `common/libcommoa.a` and `libllama.a`. They will be embedded into the main go program to facilite the distribution, as "payloads" of the executable.

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
4. Besides, the calls to the functions in `ext_server` carry the some parameters defined in `llm` directory. In general, the requests and responses are passed in JSON format, and contains more structural information. They are defined in such as `ggml.go` (decribing the models) and `llama.go` (describing the different requests and responses).
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

A really good design in this part is the stream-like response, thanks to the `fn func(PredictResult)` argument in the `Predict` function. It is a callback function, which allows to send continously the responses as soon as it gets:

```go
if p.Content != "" {
  fn(PredictResult{
    Content: p.Content,
  })
}
```

It also relies on the convenient call to `dyn_llama_server_completion_next_result` (althoug it's also a direct call to a loaded C function `llama_server_completion_next_result` from a dynamic library based on `llama.cpp`).

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

Their impementations are located in `llm/ext_server/ext_server.cpp`, which is set as a library target named by `ext_server` in `llm/ext_server/CMakeLists.txt`. During the building the target, this file will be compiled with `llama.cpp` example server together. The compiled result is one of the dynamic libraries that we mentioned.

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

For example, it calls `llama_backend_init` to initalize the backend (could be AVX, CUDA, etc), and `llama_numa_init` to initilize the NUMA (if exists). Then it calls the `load_model` function in the server context with the given parameters to load the model and finilize the initialization with `initialize` function.

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

## 5. Patches

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

Let's go back to
`libPath`
How to choose the libraries

There is a call in `newDynExtServer` to `gpu.UpdatePath(filepath.Dir(library))`

```go
// getDynLibs returns an ordered list of LLM libraries to try, starting with the best
func getDynLibs(gpuInfo gpu.GpuInfo) []string {
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

	// Finally, if we didn't find any matches, LCD CPU FTW
	if len(dynLibs) == 0 {
		dynLibs = []string{availableDynLibs["cpu"]}
	}
	slog.Debug(fmt.Sprintf("ordered list of LLM libraries to try %v", dynLibs))
	return dynLibs
}
```

```go
func nativeInit() error {
	payloadsDir, err := gpu.PayloadsDir()
	if err != nil {
		return err
	}

	slog.Info(fmt.Sprintf("Extracting dynamic libraries to %s ...", payloadsDir))

	libs, err := extractDynamicLibs(payloadsDir, "llama.cpp/build/*/*/*/lib/*")
	if err != nil {
		if errors.Is(err, payloadMissing) {
			slog.Info(fmt.Sprintf("%s", payloadMissing))
			return nil
		}
		return err
	}
	for _, lib := range libs {
		// The last dir component is the variant name
		variant := filepath.Base(filepath.Dir(lib))
		availableDynLibs[variant] = lib
	}

	if err := verifyDriverAccess(); err != nil {
		return err
	}

	// Report which dynamic libraries we have loaded to assist troubleshooting
	variants := make([]string, len(availableDynLibs))
	i := 0
	for variant := range availableDynLibs {
		variants[i] = variant
		i++
	}
	slog.Info(fmt.Sprintf("Dynamic LLM libraries %v", variants))
	slog.Debug("Override detection logic by setting OLLAMA_LLM_LIBRARY")

	return nil
}
```



## Apple Metal

Apple

## Nvidia CUDA

NVIDIA

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
	} else if gpuHandles.cudart != nil && (cpuVariant != "" || runtime.GOARCH != "amd64") {
		C.cudart_check_vram(*gpuHandles.cudart, &memInfo)
		if memInfo.err != nil {
			slog.Info(fmt.Sprintf("[cudart] error looking up CUDART GPU memory: %s", C.GoString(memInfo.err)))
			C.free(unsafe.Pointer(memInfo.err))
		} else if memInfo.count > 0 {
			// Verify minimum compute capability
			var cc C.cudart_compute_capability_t
			C.cudart_compute_capability(*gpuHandles.cudart, &cc)
			if cc.err != nil {
				slog.Info(fmt.Sprintf("[cudart] error looking up CUDA compute capability: %s", C.GoString(cc.err)))
				C.free(unsafe.Pointer(cc.err))
			} else if cc.major > CudaComputeMin[0] || (cc.major == CudaComputeMin[0] && cc.minor >= CudaComputeMin[1]) {
				slog.Info(fmt.Sprintf("[cudart] CUDART CUDA Compute Capability detected: %d.%d", cc.major, cc.minor))
				resp.Library = "cuda"
			} else {
				slog.Info(fmt.Sprintf("[cudart] CUDA GPU is too old. Falling back to CPU mode. Compute Capability detected: %d.%d", cc.major, cc.minor))
			}
		}
	} else {
		AMDGetGPUInfo(&resp)
		if resp.Library != "" {
			return resp
		}
	}
	if resp.Library == "" {
		C.cpu_check_ram(&memInfo)
		resp.Library = "cpu"
		resp.Variant = cpuVariant
	}
	if memInfo.err != nil {
		slog.Info(fmt.Sprintf("error looking up CPU memory: %s", C.GoString(memInfo.err)))
		C.free(unsafe.Pointer(memInfo.err))
		return resp
	}

	resp.DeviceCount = uint32(memInfo.count)
	resp.FreeMemory = uint64(memInfo.free)
	resp.TotalMemory = uint64(memInfo.total)
	return resp
}
```

## AMD ROCm

AMD

```go
func rocmDynLibPresent() bool {
	for dynLibName := range availableDynLibs {
		if strings.HasPrefix(dynLibName, "rocm") {
			return true
		}
	}
	return false
}
```

# Web service and client

In `server`, `api`

## OpenAI API wrapper

openai model

# Other utilities

auth, cmd, format, parser, progress, readline

## `format` module

# Conclusion

At the end, I would end up with a simple figure for the `ollama` architecture:

{% asset_img ollama.drawio.svg ollama arch %}

I would say as well: `ollama` is a thin but smart enough wrapper of `llama.cpp`.
Although it still has a few drawbacks, we still need as many these kinds of wrappers as possible, to make the life easier for any end-users.
