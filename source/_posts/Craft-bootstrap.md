---
title: Craft Bootstrap Script
date: 2019-05-10 16:41:40
tags:
- Craft
- System
categories:
- [System, Utility, Build tool]
---

Here we talk about `KDE Craft` buildtool, rather than something like Minecraft, Warcraft or Starcraft.

`Craft` is an open source meta build system and package manager written in `Python`. It manages dependencies and builds libraries and applications from source, on Windows, Mac, Linux and FreeBSD. Please go to [https://community.kde.org/Craft](https://community.kde.org/Craft) for more information.

To setup `Craft`, follow the steps on [Setup Craft](https://community.kde.org/Craft#Setting_up_Craft) on KDE Community Wiki. Here I use `Craft`in Unix/Linux environment. So, if all is well, we should use `source CraftRoot/craft/craftenv.sh` to enter the build environment. But try to stop doing this, the subject of the post is to study the bootstrap script.

The most important stuffs for bootstrapping of `Craft` is the `craftenv.sh` script, which script is used for preparing `Craft` environment.

We try to comprehend the environment configuration script `craftenv.sh`. What does it happen when we execute `source craftenv.sh`?

# Find `craftenv.sh` directory

There is no assumption of interpreter at the beginning of this script. For the compatibility, the script firstly try to get `BASH_SOURCE[0]`. If nothing is contained in the variable, at least we can infer the interpreter is not a `bash` Bourne-Again shell. And then for others, if none of `${BASH_SOURCE[0]}`, `$0` and `$_` works, we may use an interpreter which is not supported by this script. We just stop trying to continue the work.

Meanwhile, the script store the relative path into `$craftRoot`.

```bash
craftRoot="${BASH_SOURCE[0]}"
if [[ -z "$craftRoot" ]];then
    craftRoot="$0"
fi
if [[ -z "$craftRoot" ]];then
    craftRoot="$_"
fi
if [[ -z "$craftRoot" ]];then
    echo "Failed to determine interpreter"
    exit 1
fi
```

In fact, after the detection, the shell is not important anymore. Which we concerned is just the `$craftRoot`.

# Find compatible Python 3 with appropriate minor version

It's confirmed that `Craft` would like to use `Python 3`. It recommends user `Python 3.6`.

`Craft` bootstrap script uses `command -v python-<version>` to check if an appropriate version of Python exists.

```bash
if command -v python3.7 >/dev/null; then
    CRAFT_PYTHON_BIN=$(command -v python3.7)
elif command -v python3.6 >/dev/null; then
    CRAFT_PYTHON_BIN=$(command -v python3.6)
```

This section is to used to detect whether `Python 3.7` or `Python 3.6` exists in your system path.

By the way, I'd like to introduce something about versions in software distribution. If this is useful, it will be my pleasure. We usually use [Semantic Versioning](https://semver.org/) to describe changes. It means: given a version number MAJOR.MINOR.PATCH, increment the:
- MAJOR version when you make incompatible API changes,
- MINOR version when you add functionality in a backwards-compatible manner, and
- PATCH version when you make backwards-compatible bug fixes.

So the difference is in the minor version. We can see the `Python 3.7` is also supported by `Craft`. And the preference is `Python 3.7` according to the priority of instruction.

Then, the script tries to find other potentially compitable Python version. But at least, it should be `Python 3.6`. Otherwise it will not continue.

```bash
...
else
    # could not find python 3.6, try python3
    if ! command -v python3 >/dev/null; then
        echo "Failed to python Python 3.6+"
        exit 1
    fi
    # check if python3 is at least version 3.6:
    python_version=$(python3 --version)
    # sort and use . as separator and then check if the --version output is sorted later
    # Note: this is just a sanity check. craft.py should check sys.version
    comparison=$(printf '%s\nPython 3.6.0\n' "$python_version" | sort -t.)
    if [ "$(echo "${comparison}" | head -n1)" != "Python 3.6.0" ]; then
        echo "Found Python3 version ${python_version} is too old. Need at least 3.6"
        exit 1
    fi
    CRAFT_PYTHON_BIN=$(command -v python3)
fi
export CRAFT_PYTHON_BIN
```

So if Python is ok, its path will be stored in `$CRAFT_PYTHON_BIN` and exported.

As we already have `Python`, the script uses it immediately, to correct the `$craftRoot`. If the variable is not a directory, we get its parent directory and replace the `$craftRoot`.

```bash
if [[ ! -d "$craftRoot" ]]; then
    craftRoot=$(${CRAFT_PYTHON_BIN} -c "import os; import sys; print(os.path.dirname(os.path.abspath(sys.argv[1])));" "$craftRoot")
fi
```

For now, `$craftRoot` should be `craft/` in your Craft install directory. 

# Generating and exporting `$CRAFT_ENV`

The following single line is used for acquiring some environment variables for `Craft`.

```bash
CRAFT_ENV=$(${CRAFT_PYTHON_BIN} "$craftRoot/bin/CraftSetupHelper.py" --setup)
```

In fact, it called `bin/CraftSetupHelper.py` with `--setup` option, it does have done many things.

```python
    def run(self):
        parser = argparse.ArgumentParser()
        parser.add_argument("--get", action="store_true")
        parser.add_argument("--print-banner", action="store_true")
        parser.add_argument("--getenv", action="store_true")
        parser.add_argument("--setup", action="store_true")
        parser.add_argument("rest", nargs=argparse.REMAINDER)
        args = parser.parse_args()

        if args.get:
            default = ""
            if len(args.rest) == 3:
                default = args.rest[2]
                CraftCore.log.info(CraftCore.settings.get(args.rest[0], args.rest[1], default))
        elif args.print_banner:
            self.printBanner()
        elif args.getenv:
            self.printEnv()
        elif args.setup:
            self.printEnv()
            self.printBanner()

# ...

helper = SetupHelper()
if __name__ == '__main__':
    helper.run()
```

We can see that `printEnv` and `printBanner` are invoked, all their ouputs will be filled into `$CRAFT_ENV` in shell. The generated env variables are too many, here we only talk about the bootstrapping. Maybe there will be an article about those.

```bash
# Split the CraftSetupHelper.py output by newlines instead of any whitespace
# to also handled environment variables containing spaces (e.g. $PS1)
# See https://stackoverflow.com/q/24628076/894271
function export_lines() {
    local IFS=$'\n'
    local lines=($1)
    local i
    for (( i=0; i<${#lines[@]}; i++ )) ; do
        local line=${lines[$i]}
        if [[ "$line"  =~ "=" ]] && [[ $line != _=* ]] ; then
            export "$line" || true
        fi
    done
}
export_lines "$CRAFT_ENV"
```

Then with `export_lines`, all the lines can be exported seperatly without confusion.

# Exporting other necessary variables and functions

If the prompt exists in `$PS1`, which means the interpreter is using the strings in `$PS1` as its prompt, then the script add `CRAFT:` before it. This would be realy useful because it could remind user that we're in the `Craft` environment.

```bash
if [ -n "$PS1" ]; then
    export PS1="CRAFT: $PS1"
fi
```

Then just some useful functions:

```bash
craft() {
    ${CRAFT_PYTHON_BIN} "$craftRoot/bin/craft.py" $@
}
```

The main entry of `Craft`. It will invoke `bin/craft.py`. All other things will be done in it.

```bash
cs() {
    dir=$(craft -q --ci-mode --get "sourceDir()" $1)
    if (($? > 0));then
        echo $dir
    else
        cd "$dir"
    fi
}
```

Change current work directory to source directory in `Craft`.

```bash
cb() {
    dir=$(craft -q --ci-mode --get "buildDir()" $1)
    if (($? > 0));then
        echo $dir
    else
        cd "$dir"
    fi
}
```

Change current work directory to build directory in `Craft`.

```bash
cr() {
    cd "$KDEROOT"
}
```

Change current work directory to root in `Craft`.

And export them

```bash
declare -x -F cs cb cr
```

# Conclusion

With all environment variables prepared, and some useful function exported, we can begin our trip in building everything with `Craft`.

# References

1. KDE Craft wiki, [https://community.kde.org/Craft](https://community.kde.org/Craft)
2. Utilisation de la variable BASH_SOURCE[0], [https://logd.fr/utilisation-variable-bash_source/](https://logd.fr/utilisation-variable-bash_source/)