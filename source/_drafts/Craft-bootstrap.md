---
title: Craft Bootstrap Script
date: 2019-05-10 16:41:40
tags:
- Craft
- System
categories:
- [System, Utility, Build tool]
---

Here we talk about `KDE Craft` buildtool, but not something like Minecraft, Warcraft or Starcraft.

To setup `Craft`, follow the steps on [Setup Craft](https://community.kde.org/Craft#Setting_up_Craft) on KDE Community Wiki.

If all is well, we can use `source CraftRoot/craft/craft.sh` to enter the build environment. But try to stop doing this, the subject is to study the bootstrap script.

# Environment

Firstly, we try to comprehend the bootstrap script `craft.sh`.


# Find Python 3 minor version

We are sure that `Craft` would like to use `Python3`. It recommends user the `Python 3.6`.

`Craft` bootstrap script uses `command -v python-<version>` to check if an appropriate version of Python exists.

```bash
if command -v python3.7 >/dev/null; then
    CRAFT_PYTHON_BIN=$(command -v python3.7)
elif command -v python3.6 >/dev/null; then
    CRAFT_PYTHON_BIN=$(command -v python3.6)
```

This section is to used to detect whether `Python 3.7` or `Python 3.6` exists.

By the way, in software distribution, we usually use [Semantic Versioning](https://semver.org/) to describe changes. It means: given a version number MAJOR.MINOR.PATCH, increment the:
- MAJOR version when you make incompatible API changes,
- MINOR version when you add functionality in a backwards-compatible manner, and
- PATCH version when you make backwards-compatible bug fixes.

So the difference is in the minor version. We can see the `Python 3.7` is also supported

```bash
if command -v python3.7 >/dev/null; then
    CRAFT_PYTHON_BIN=$(command -v python3.7)
elif command -v python3.6 >/dev/null; then
    CRAFT_PYTHON_BIN=$(command -v python3.6)
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

#!/usr/bin/env bash
${CRAFT_PYTHON_BIN:-python3.6} $craftRoot/bin/craft.py $@