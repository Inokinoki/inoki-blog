---
title: Python Source Code Analysis (2) Python Object
date: 2019-10-28 12:10:40
tags:
- Python
- Source Code
categories:
- [Programming Language, Python]
- [Source Code, Python]
---

In this post, we will take a dissecion of source code of Python.

To benefit the simplicity and meanwhile follow the most recent functionnalities, I choose `Python 3.6.9` to do the analysis.

In the last post, the entry of Python is found, so it's time to look at it!

# Py_Main - the Python Main function

According to C89 standard, in a C function, all the variables should be declared at the beginning. So, we can take a look at those variables.

# Variables

The variables are listed below, though we'll not explicite them at the moment.

```c
    int c;
    int sts;
    wchar_t *command = NULL;
    wchar_t *filename = NULL;
    wchar_t *module = NULL;
    FILE *fp = stdin;
    char *p;
#ifdef MS_WINDOWS
    wchar_t *wp;
#endif
    int skipfirstline = 0;
    int stdin_is_interactive = 0;
    int help = 0;
    int version = 0;
    int saw_unbuffered_flag = 0;
    char *opt;
    PyCompilerFlags cf;
    PyObject *main_importer_path = NULL;
    PyObject *warning_option = NULL;
    PyObject *warning_options = NULL;
```

# Arguments

Then, after listing and initializing all variables, Python will try to find flags in the arguments.

First, Python tries to find some options which are needed by some initializations.

```c
/* Hash randomization needed early for all string operations
   (including -W and -X options). */
while ((c = _PyOS_GetOpt(argc, argv, PROGRAM_OPTS)) != EOF) {
    if (c == 'm' || c == 'c') {
        /* -c / -m is the last option: following arguments are
            not interpreter options. */
        break;
    }
    if (c == 'E') {
        Py_IgnoreEnvironmentFlag++;
        break;
    }
}
```

`PROGRAM_OPTS` is defined as `BASE_OPTS`, and `#define BASE_OPTS L"bBc:dEhiIJm:OqRsStuvVW:xX:?"` is at the header of `main.c`.

`_PyOS_GetOpt` is implemented in `Python/getopt.c`, which validates and returns argument option. If an option is not in `PROGRAM_OPTS`, a `_` will be returned. It will not accept `--argument` and returns a -1 if an argument with that form is found.

In these lines, only options `E`, `m`, `c` are detected:
- if `E` is detected, the flag which leads to the negligence of `PYTHONPATH`, `PYTHONHOME` environment variables.
- once `m` or `c` is detected, following parameters should be the name of module(for `m` option) or the command that will be executed(for `c` option). So we terminated this loop.

Then, Python gets the `PYTHONMALLOC` variables and tries to use it to setup allocators.

```c
opt = Py_GETENV("PYTHONMALLOC");
if (_PyMem_SetupAllocators(opt) < 0) {
    fprintf(stderr,
            "Error in PYTHONMALLOC: unknown allocator \"%s\"!\n", opt);
    exit(1);
}
```

Valid allocators are `pymalloc`, `pymalloc_debug`, `malloc`, `malloc_debug` and `debug`. If you'd like to get more about them, `Objects/obmalloc.c` is a good place.

And then Python does an initialization of Random module. In this module, `PYTHONHASHSEED` can be used to initialize random module. And it resets warning options, resets option parsing process to process all options.

```c
_PyRandom_Init();

PySys_ResetWarnOptions();
_PyOS_ResetGetOpt();

while ((c = _PyOS_GetOpt(argc, argv, PROGRAM_OPTS)) != EOF) {
    // ...
}
```

We finally enter the period to parse all arguments. They will be explicited in order.

## Option c

**-c cmd : program passed in as string (terminates option list)`**

```c
if (c == 'c') {
    size_t len;
    /* -c is the last option; following arguments
        that look like options are left for the
        command to interpret. */

    len = wcslen(_PyOS_optarg) + 1 + 1;
    command = (wchar_t *)PyMem_RawMalloc(sizeof(wchar_t) * len);
    if (command == NULL)
        Py_FatalError(
            "not enough memory to copy -c argument");
    wcscpy(command, _PyOS_optarg);
    command[len - 2] = '\n';
    command[len - 1] = 0;
    break;
}
```

If we encounter an `c` option, all other arguments will be neglected. The following argument will be parsed as the commands to be run.

## Option m

**-m mod : run library module as a script (terminates option list)**

```c
if (c == 'm') {
    /* -m is the last option; following arguments
        that look like options are left for the
        module to interpret. */
    module = _PyOS_optarg;
    break;
}
```

If we encounter an `m` option, all other arguments will be neglected. The following argument will be parsed as the module to be run.

## Other options

```
-B     : don't write .py[co] files on import; also PYTHONDONTWRITEBYTECODE=x
-d     : debug output from parser; also PYTHONDEBUG=x
-E     : ignore PYTHON* environment variables (such as PYTHONPATH)
-h     : print this help message and exit (also --help)
-i     : inspect interactively after running script; forces a prompt even
         if stdin does not appear to be a terminal; also PYTHONINSPECT=x
-O     : optimize generated bytecode slightly; also PYTHONOPTIMIZE=x
-OO    : remove doc-strings in addition to the -O optimizations
-R     : use a pseudo-random salt to make hash() values of various types be
         unpredictable between separate invocations of the interpreter, as
         a defense against denial-of-service attacks
-Q arg : division options: -Qold (default), -Qwarn, -Qwarnall, -Qnew
-s     : don't add user site directory to sys.path; also PYTHONNOUSERSITE
-S     : don't imply 'import site' on initialization
-t     : issue warnings about inconsistent tab usage (-tt: issue errors)
-u     : unbuffered binary stdout and stderr; also PYTHONUNBUFFERED=x
         see man page for details on internal buffering relating to '-u'
-v     : verbose (trace import statements); also PYTHONVERBOSE=x
         can be supplied multiple times to increase verbosity
-V     : print the Python version number and exit (also --version)
-W arg : warning control; arg is action:message:category:module:lineno
         also PYTHONWARNINGS=arg
-x     : skip first line of source, allowing use of non-Unix forms of #!cmd
```

```c
switch (c) {
case 'b':
    Py_BytesWarningFlag++;
    break;

case 'd':
    Py_DebugFlag++;
    break;

case 'i':
    Py_InspectFlag++;
    Py_InteractiveFlag++;
    break;

case 'I':
    Py_IsolatedFlag++;
    Py_NoUserSiteDirectory++;
    Py_IgnoreEnvironmentFlag++;
    break;

/* case 'J': reserved for Jython */

case 'O':
    Py_OptimizeFlag++;
    break;

case 'B':
    Py_DontWriteBytecodeFlag++;
    break;

case 's':
    Py_NoUserSiteDirectory++;
    break;

case 'S':
    Py_NoSiteFlag++;
    break;

case 'E':
    /* Already handled above */
    break;

case 't':
    /* ignored for backwards compatibility */
    break;

case 'u':
    Py_UnbufferedStdioFlag = 1;
    saw_unbuffered_flag = 1;
    break;

case 'v':
    Py_VerboseFlag++;
    break;

case 'x':
    skipfirstline = 1;
    break;

case 'h':
case '?':
    help++;
    break;

case 'V':
    version++;
    break;

case 'W':
    if (warning_options == NULL)
        warning_options = PyList_New(0);
    if (warning_options == NULL)
        Py_FatalError("failure in handling of -W argument");
    warning_option = PyUnicode_FromWideChar(_PyOS_optarg, -1);
    if (warning_option == NULL)
        Py_FatalError("failure in handling of -W argument");
    if (PyList_Append(warning_options, warning_option) == -1)
        Py_FatalError("failure in handling of -W argument");
    Py_DECREF(warning_option);
    break;

case 'X':
    PySys_AddXOption(_PyOS_optarg);
    break;

case 'q':
    Py_QuietFlag++;
    break;

case 'R':
    /* Ignored */
    break;

/* This space reserved for other options */

default:
    return usage(2, argv[0]);
    /*NOTREACHED*/

}
```

# Actions and behaviors

After recording all options in specified flags, Python can handle them with a determined order or a determined prority (if actions are incompatible).

## Help, Version

```c
if (help)
    return usage(0, argv[0]);

if (version) {
    printf("Python %s\n", version >= 2 ? Py_GetVersion() : PY_VERSION);
    return 0;
}
```

The option for help has the highest priority, then the option for the version. If they occured, Python will directly terminate after executing their proper actions.

## Sync with env

Then, Python tries to get env

```c
if (!Py_InspectFlag &&
    (p = Py_GETENV("PYTHONINSPECT")) && *p != '\0')
    Py_InspectFlag = 1;
if (!saw_unbuffered_flag &&
    (p = Py_GETENV("PYTHONUNBUFFERED")) && *p != '\0')
    Py_UnbufferedStdioFlag = 1;

if (!Py_NoUserSiteDirectory &&
    (p = Py_GETENV("PYTHONNOUSERSITE")) && *p != '\0')
    Py_NoUserSiteDirectory = 1;
```

One thing should be noticed is that, `Py_GETENV` is a macro like this:

```c
#define Py_GETENV(s) (Py_IgnoreEnvironmentFlag ? NULL : getenv(s))
```

which will actually return NULL if the flag `Py_IgnoreEnvironmentFlag` is not zero. The flag is set by `-E` option. I think this is a good design.

## Parse warning option

Python then uses the code below to parse warning option in different systems, since they might have different default character sets.

```c
#ifdef MS_WINDOWS
// ...
#else
// ...
#endif

if (warning_options != NULL) {
    Py_ssize_t i;
    for (i = 0; i < PyList_GET_SIZE(warning_options); i++) {
        PySys_AddWarnOptionUnicode(PyList_GET_ITEM(warning_options, i));
    }
}
```

At the end, add them to Python warning option list.

## Get script file name

Get filename if no command, no module, the arguments are not all read, and the current argument is not `-`.

```c
if (command == NULL && module == NULL && _PyOS_optind < argc &&
    wcscmp(argv[_PyOS_optind], L"-") != 0)
{
    filename = argv[_PyOS_optind];
}
```

## Check interactivity of current terminal

```c
stdin_is_interactive = Py_FdIsInteractive(stdin, (char *)0);

// Python/pylifecycle.c
/*
 * The file descriptor fd is considered ``interactive'' if either
 *   a) isatty(fd) is TRUE, or
 *   b) the -i flag was given, and the filename associated with
 *      the descriptor is NULL or "<stdin>" or "???".
 */
int
Py_FdIsInteractive(FILE *fp, const char *filename)
{
    if (isatty((int)fileno(fp)))
        return 1;
    if (!Py_InteractiveFlag)
        return 0;
    return (filename == NULL) ||
           (strcmp(filename, "<stdin>") == 0) ||
           (strcmp(filename, "???") == 0);
}
```

So, stdin is always interactive.

## Play with buffers

Use `-u` option to disable input/ouput buffer in Python. This can resolve some problem if you'd like to use pipe as the input or the output of a Python program.

```c
if (Py_UnbufferedStdioFlag) {
#ifdef HAVE_SETVBUF
    setvbuf(stdin,  (char *)NULL, _IONBF, BUFSIZ);
    setvbuf(stdout, (char *)NULL, _IONBF, BUFSIZ);
    setvbuf(stderr, (char *)NULL, _IONBF, BUFSIZ);
#else /* !HAVE_SETVBUF */
    setbuf(stdin,  (char *)NULL);
    setbuf(stdout, (char *)NULL);
    setbuf(stderr, (char *)NULL);
#endif /* !HAVE_SETVBUF */
}
```

If `Py_UnbufferedStdioFlag` is not set, but we'll enter the interactive mode, do not either use the input/output buffer.

```c
else if (Py_InteractiveFlag) {
#ifdef MS_WINDOWS
    /* Doesn't have to have line-buffered -- use unbuffered */
    /* Any set[v]buf(stdin, ...) screws up Tkinter :-( */
    setvbuf(stdout, (char *)NULL, _IONBF, BUFSIZ);
#else /* !MS_WINDOWS */
#ifdef HAVE_SETVBUF
    setvbuf(stdin,  (char *)NULL, _IOLBF, BUFSIZ);
    setvbuf(stdout, (char *)NULL, _IOLBF, BUFSIZ);
#endif /* HAVE_SETVBUF */
#endif /* !MS_WINDOWS */
    /* Leave stderr alone - it should be unbuffered anyway. */
}
```

## Play with program name 

Python wants to set itself as the program name through `Py_SetProgramName` function. It's a simple function, but on macOS, the Python interpreter can be in an App package rather than a bare environment. So, it requires lots of lines to retrieve the program name.

```c
#ifdef __APPLE__
    /* On MacOS X, when the Python interpreter is embedded in an
       application bundle, it gets executed by a bootstrapping script
       that does os.execve() with an argv[0] that's different from the
       actual Python executable. This is needed to keep the Finder happy,
       or rather, to work around Apple's overly strict requirements of
       the process name. However, we still need a usable sys.executable,
       so the actual executable path is passed in an environment variable.
       See Lib/plat-mac/bundlebuiler.py for details about the bootstrap
       script. */
    if ((p = Py_GETENV("PYTHONEXECUTABLE")) && *p != '\0') {
        wchar_t* buffer;
        size_t len = strlen(p) + 1;

        buffer = PyMem_RawMalloc(len * sizeof(wchar_t));
        if (buffer == NULL) {
            Py_FatalError(
               "not enough memory to copy PYTHONEXECUTABLE");
        }

        mbstowcs(buffer, p, len);
        Py_SetProgramName(buffer);
        /* buffer is now handed off - do not free */
    } else {
#ifdef WITH_NEXT_FRAMEWORK
        char* pyvenv_launcher = getenv("__PYVENV_LAUNCHER__");

        if (pyvenv_launcher && *pyvenv_launcher) {
            /* Used by Mac/Tools/pythonw.c to forward
             * the argv0 of the stub executable
             */
            wchar_t* wbuf = Py_DecodeLocale(pyvenv_launcher, NULL);

            if (wbuf == NULL) {
                Py_FatalError("Cannot decode __PYVENV_LAUNCHER__");
            }
            Py_SetProgramName(wbuf);

            /* Don't free wbuf, the argument to Py_SetProgramName
             * must remain valid until Py_FinalizeEx is called.
             */
        } else {
            Py_SetProgramName(argv[0]);
        }
#else
        Py_SetProgramName(argv[0]);
#endif
    }
#else
    Py_SetProgramName(argv[0]);
#endif
```

Otherwise, we can see that, `argv[0]` is passed in.

## Initialize Python

This function will call `Py_InitializeEx(1);` and then `_Py_InitializeEx_Private(install_sigs, 1);`.

```c
Py_Initialize();
```

The function `_Py_InitializeEx_Private` will establish the entire environment. **In the next post, we can get deeper in it**.

## Print Python version in interactive mode

Python will then print Python version if we want to directly enter into interactive mode, i.e, run `python` without any other arguments.

```c
if (!Py_QuietFlag && (Py_VerboseFlag ||
                    (command == NULL && filename == NULL &&
                        module == NULL && stdin_is_interactive))) {
    fprintf(stderr, "Python %s on %s\n",
        Py_GetVersion(), Py_GetPlatform());
    if (!Py_NoSiteFlag)
        fprintf(stderr, "%s\n", COPYRIGHT);
}
```

## Prepare argv for Python os.argv

Use `-m` or `-c` as premier argument.

```c
if (command != NULL) {
    /* Backup _PyOS_optind and force sys.argv[0] = '-c' */
    _PyOS_optind--;
    argv[_PyOS_optind] = L"-c";
}

if (module != NULL) {
    /* Backup _PyOS_optind and force sys.argv[0] = '-m'*/
    _PyOS_optind--;
    argv[_PyOS_optind] = L"-m";
}
```

## Prepare main importer path

Main importer path is exactly the module in which Python will run as `__main__`. So, to launch Python with a file in the arguments, it's to use the file as the main importer path.

```c
if (filename != NULL) {
    main_importer_path = AsImportPathEntry(filename);
}
```

If there is no file name provided, `main_importer_path` will not be set, either. So we do not know which we should use as the first parameter in `sys.argv`. Python chooses to treat it after.

```
if (main_importer_path != NULL) {
    /* Let RunMainFromImporter adjust sys.path[0] later */
    PySys_SetArgvEx(argc-_PyOS_optind, argv+_PyOS_optind, 0);
} else {
    /* Use config settings to decide whether or not to update sys.path[0] */
    PySys_SetArgv(argc-_PyOS_optind, argv+_PyOS_optind);
}
```

## Prepare for interactive mode

If we are going to use interactive/inspect mode, we'll need the library `readline`. So, import it and decrease the reference count of it, to delete it later.

```c
if ((Py_InspectFlag || (command == NULL && filename == NULL && module == NULL)) &&
    isatty(fileno(stdin)) &&
    !Py_IsolatedFlag) {
    PyObject *v;
    v = PyImport_ImportModule("readline");
    if (v == NULL)
        PyErr_Clear();
    else
        Py_DECREF(v);
}
```

## Run command if conform
```c
if (command) {
    sts = run_command(command, &cf);
    PyMem_RawFree(command);
}
```

## Run module if conform
```c
else if (module) {
    sts = (RunModule(module, 1) != 0);
}
```

## Run interactive or run files

If neither command nor module conforms, Python will try to find other way to launch.

Firstly, it tries to run interactive mode, while filename is not set.

This action is what happens in the background when we launch `python` without arguments from our terminal.

But it is not where the program begins. Here, we've just launched a hook to mark that we need interactive mode.

```c
if (filename == NULL && stdin_is_interactive) {
    Py_InspectFlag = 0; /* do exit on SystemExit */
    RunStartupFile(&cf);
    RunInteractiveHook();
}
```

Then, if `main_importer_path` is set(previously by the file), the main program will run with the file as the main importer. As you know, import all things in the module and set `__name__` to `__main__`.

```c
sts = -1;               /* keep track of whether we've already run __main__ */

if (main_importer_path != NULL) {
    sts = RunMainFromImporter(main_importer_path);
}
```

But what will happen if file name is set, but main importer is not found, or the file doesn't exist?

Python tries to open the file and read it line by line, then executes it.

```c
if (sts==-1 && filename != NULL) {
    fp = _Py_wfopen(filename, L"r");
    if (fp == NULL) {
        char *cfilename_buffer;
        const char *cfilename;
        int err = errno;
        cfilename_buffer = Py_EncodeLocale(filename, NULL);
        if (cfilename_buffer != NULL)
            cfilename = cfilename_buffer;
        else
            cfilename = "<unprintable file name>";
        fprintf(stderr, "%ls: can't open file '%s': [Errno %d] %s\n",
            argv[0], cfilename, err, strerror(err));
        if (cfilename_buffer)
            PyMem_Free(cfilename_buffer);
        return 2;
    }
    else if (skipfirstline) {
        int ch;
        /* Push back first newline so line numbers
            remain the same */
        while ((ch = getc(fp)) != EOF) {
            if (ch == '\n') {
                (void)ungetc(ch, fp);
                break;
            }
        }
    }
    {
        struct _Py_stat_struct sb;
        if (_Py_fstat_noraise(fileno(fp), &sb) == 0 &&
            S_ISDIR(sb.st_mode)) {
            fprintf(stderr,
                    "%ls: '%ls' is a directory, cannot continue\n",
                    argv[0], filename);
            fclose(fp);
            return 1;
        }
    }
}
```

`sts` will be set to another value, so the following lines will only be executed if there is no file name given.

```c
if (sts == -1)
    sts = run_file(fp, filename, &cf);
```

From here, the **Python main program is over**. Except some small things will be executed after the running.

## Re-run Interactive

```c
if (Py_InspectFlag && stdin_is_interactive &&
    (filename != NULL || command != NULL || module != NULL)) {
    Py_InspectFlag = 0;
    RunInteractiveHook();
    /* XXX */
    sts = PyRun_AnyFileFlags(stdin, "<stdin>", &cf) != 0;
}
```

As we see above, we need `Py_InspectFlag`, `stdin_is_interactive` are both true, and set at least a file name, a command or a module to run interactive mode. Which means, probably there was one script which has been executed.

```c
/* Check this environment variable at the end, to give programs the
 * opportunity to set it from Python.
 */
if (!Py_InspectFlag &&
    (p = Py_GETENV("PYTHONINSPECT")) && *p != '\0')
{
    Py_InspectFlag = 1;
}
```

Thus, run `python -c "import os; os.environ['PYTHONINSPECT']='1'"` can also help enter interactive mode :)

But notice that, it will be executed if `Py_InspectFlag` is not set. That means previously we are not in the interactive mode. Thus, run `python` and `"import os; os.environ['PYTHONINSPECT']='1'"` in it, then exit, this will not help to re-enter the interactive mode.

## Clear and end up

```c
if (Py_FinalizeEx() < 0) {
    /* Value unlikely to be confused with a non-error exit status or
    other special meaning */
    sts = 120;
}

return sts;
```

# Conclusion

Up to now, a Python interpreter/program has been launched and finished.

In the next post, we'll look deeper into `_Py_InitializeEx_Private`, to see how Python Main function builds Python env through this function. But at the beginning, we'll talk about other functions in `Python/main.c`, they are small functions but really vital.

See you then!
