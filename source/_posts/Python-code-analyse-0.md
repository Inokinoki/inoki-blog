---
title: Python Source Code Analysis (0)
date: 2019-10-17 15:47:40
tags:
- Python
- Source Code
categories:
- [Programming Language, Python]
- [Source Code, Python]
---

In this post, we will take a dissecion of source code of Python.

To benefit the simplicity and meanwhile follow the most recent functionnalities, I choose `Python 3.6.9` to do the analysis.

The first step, is to build!

# Build Python

As other projects, Python uses `autoconf` toolset to configure and then `make` to build itself. If it doesn't make sense to you, just ignore it. What you really need is just a set of single commands to make it:
1. Run `./configure`, it will detect your environment along with the architecture, the dependencies, the features supported by your compiler
2. After that, if there is no error, a `Makefile` file should be generated and placed in the same directory
3. Run `make`, and you will get your own Python build!

Now we use default configurations to build, because we don't aim at building a Python binary. If you'd like to play with Python builds, you can find more information at [https://docs.python.org/3.6/using/unix.html#building-python](https://docs.python.org/3.6/using/unix.html#building-python).

# Project Structure

Before we configure the project, the structure of project is really clear and simple:

```
aclocal.m4     configure     Lib              Misc     Programs       python-config.py
build          configure.ac  LICENSE          Modules  pyconfig.h     python-gdb.py
config.guess   Doc           Mac              Objects  pyconfig.h.in  README.rst
config.log     Grammar       Makefile         Parser   python         setup.py
config.status  Include       Makefile.pre     PC       Python         Tools
config.sub     install-sh    Makefile.pre.in  PCbuild  python-config
```

`aclocal.m4`, `config.guess`, `config.sub`, `configure`, `configure.ac`, `install-sh`, `Makefile.pre.in`, `pyconfig.h.in` are files which concerns the configuration and the compilation. `LICENSE` is the license file.

## Doc/
This folder contains the documentation of Python.

## Grammar1/
In Grammar folder, there is only one file, which described the abstract grammar representation of Python.

## Include/
All Python headers used during Python compilation. Some of those will be intalled in your system for a further development.

## Lib/
All libraries written in Python.

## Mac/
Build tools for macOS build.

## Misc/
Other things, not so important.

## Modules/
Modules written in C.

## Objects/
Declarations and implementations of various Python Objects.

## Parser/
Python code parser.

## PC/
The code for Windows PC.

## PCbuild/
The Windows PC build files, such as Visual Studio Prject files.

## Programms/
**Main functions of Python**.

## Python/
**Python main implementation codes**.

## Tools/
Auxiliary tools and demo.

# Programm Entry, Programs/python.c

In the analysis, we start by the main entry of program.

At the beginning, `"Python.h"` and `<locale.h>` are imported.

Then, the main function has two branches:

## Windows

On Windows, the function `wmain` instead of `main` is used as the main entry.

```c
int
wmain(int argc, wchar_t **argv)
{
    return Py_Main(argc, argv);
}
```

This function is for the unicode environment, you can go to the doc page of Microsoft for further information:
[https://docs.microsoft.com/en-us/cpp/c-language/using-wmain?view=vs-2019](https://docs.microsoft.com/en-us/cpp/c-language/using-wmain?view=vs-2019).

In the main function, it calls the real Main Function of Python, `Py_Main` with command-line arguments.

## Other Unix-Like Systems

It's not so simple as the one for Windows.

```c
 wchar_t **argv_copy;
/* We need a second copy, as Python might modify the first one. */
wchar_t **argv_copy2;
int i, res;
char *oldloc;
```

In this code, some necessary variables are declared, regarding C89 or above. Then, to copy arguments, Python requests to use `malloc` to allocate memories by invoking `(void)_PyMem_SetupAllocators("malloc");`.

Then two memory spaces are allocated:

```c
argv_copy = (wchar_t **)PyMem_RawMalloc(sizeof(wchar_t*) * (argc+1));
argv_copy2 = (wchar_t **)PyMem_RawMalloc(sizeof(wchar_t*) * (argc+1));
if (!argv_copy || !argv_copy2) {
    fprintf(stderr, "out of memory\n");
    return 1;
}
```

Then, Python did one thing like this:

```c
oldloc = _PyMem_RawStrdup(setlocale(LC_ALL, NULL));
```

This line will return `C` locale and store it in `oldloc`.

Then Python tries to set locale with user-prefered one by `setlocale(LC_ALL, "")`, and to decode all command line arguments with new locale.

```c
setlocale(LC_ALL, "");
for (i = 0; i < argc; i++) {
    argv_copy[i] = Py_DecodeLocale(argv[i], NULL);
    if (!argv_copy[i]) {
        PyMem_RawFree(oldloc);
        fprintf(stderr, "Fatal Python error: "
                        "unable to decode the command line argument #%i\n",
                        i + 1);
        return 1;
    }
    argv_copy2[i] = argv_copy[i];
}
argv_copy2[argc] = argv_copy[argc] = NULL;
```

After decoding command line arguments with user-prefered locale, Python would like to use the old default `C` locale and do some clean things.

```c
setlocale(LC_ALL, oldloc);
PyMem_RawFree(oldloc);
```

After everything about decoding and copying arguments is ready, run Python main process:

```c
res = Py_Main(argc, argv_copy);
```

After finishing Python main process, all memory spaces which were allocated should be released properly with following code:

```c
/* Force again malloc() allocator to release memory blocks allocated
   before Py_Main() */
(void)_PyMem_SetupAllocators("malloc");

for (i = 0; i < argc; i++) {
    PyMem_RawFree(argv_copy2[i]);
}
PyMem_RawFree(argv_copy);
PyMem_RawFree(argv_copy2);
```

And then, return the result through `return res;`.

# Before the end

In this post, we tried to compile Python with all default configurations, and we explicited the main entry function.

In the next post, we'll [get involve with `Py_Main` function](https://blog.inoki.cc/2019/10/17/Python-code-analyse-0/), as well as some Python Objects or types if possible.

See you then!
