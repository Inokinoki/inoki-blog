---
title: SDDM tips (1)
date: 2021-01-25 09:30:40
tags:
- KDE
- SDDM
categories:
- KDE
---

SDDM is the abbreviation of Simple Desktop Display Manager, which is a default display manager for LXQt and KDE Plasma.
It officially supports Linux and FreeBSD, but should also work well with other Unix-like system.

# User HOME

SDDM works under a special user in an UNIX-like system: `sddm`. Its HOME directory is set to `/var/lib/sddm`.

If we want to install it ourselves, an `sddm` user needs to be created, with its home set to `/var/lib/sddm` by default.

In this directory, a `state.conf` will be created. The content of it on my PC is:

```
[Last]
# Name of the last logged-in user.
# This user will be preselected when the login screen appears
User=inoki


# Name of the session for the last logged-in user.
# This session will be preselected when the login screen appears.
Session=/usr/share/xsessions/plasma.desktop
```

which notes the latest login user and the correspond session. This will accelerate the next login.

The file is declared in `src/common/configuration.h` and will be loaded later.

# Configurations

Like the other programs, SDDM also reads configuration from `/etc`. The file is `/etc/sddm.conf`, which contains several sections:

- General
- Theme
- Users
- Wayland
- X11

# Icons

User icons are stored in `$(DATADIR)/faces/` or `~/.face.icon` (for each user).

# Themes

Themes are stored in `$(DATADIR)/themes/`. SDDM loads `Main.qml` file in it to create an user interface.

# Scripts

Scripts to launch a specific session under an environment are stored in `$(DATADIR)/scripts/`. These scripts will start the desktop environment.

For example, for X11, the configuration items are:

```
[X11]
DisplayCommand=/usr/share/sddm/scripts/Xsetup
DisplayStopCommand=/usr/share/sddm/scripts/Xstop
EnableHiDPI=false
MinimumVT=1
ServerArguments=-nolisten tcp
ServerPath=/usr/bin/X
SessionCommand=/usr/share/sddm/scripts/Xsession
SessionDir=/usr/share/xsessions
SessionLogFile=.local/share/sddm/xorg-session.log
UserAuthFile=.Xauthority
XauthPath=/usr/bin/xauth
XephyrPath=/usr/bin/Xephyr
```

The script is `Xsetup`, `Xsession`, `Xstop`, etc. The desktop entries for desktop environments are placed in `/usr/share/xsessions`.

In my case, the `plasma.desktop` indicates the executable:

```
[Desktop Entry]
Type=XSession
Exec=/usr/bin/startplasma-x11
TryExec=/usr/bin/startplasma-x11
DesktopNames=KDE
Name=Plasma
...
```

# Conclusion

Unfinished. TBC...
