---
title: Uninstall docker in WSL Ubuntu
date: 2018-10-21 18:48:15
tags:
- Ubuntu
- WSL
- Docker
- Bug
categories:
- [Bug, WSL]
- [Bug, Docker]
---
After my installation of docker in Windows Sous-System Linux by the command following:
```bash
sudo apt-get install docker.io
```
I regret and I'd like to uninstall it immediately.

The error occured !

``dpkg`` told me that he can't work well with the command ``sudo apt-get remove --purge docker.io``.

```
Removing docker.io (17.03.2-0ubuntu2~16.04.1) ...
invoke-rc.d: could not determine current runlevel
 * Stopping Docker: docker                                                                                              No process in pidfile '/var/run/docker-ssd.pid' found running; none killed.
invoke-rc.d: initscript docker, action "stop" failed.
dpkg: error processing package docker.io (--purge):
 subprocess installed pre-removal script returned error exit status 1
dmesg: read kernel buffer failed: Function not implemented
                                                          dpkg: error while cleaning up:
 subprocess installed post-installation script returned error exit status 1
Errors were encountered while processing:
 docker.io
E: Sub-process /usr/bin/dpkg returned an error code (1)
```

Obviously, the error is from the process of stopping the docker itself.

We can show the content of ``docker-ssd.pid``. It told us the ``pid`` of docker daemon is ``22391``.

Normally, as the docker daemon hasn't been booted, the docker daemon process will not be in the process table. So the error is that: ``We cannot stop a process with a pid which has never been booted.``

So the uninstallation script stopped when it cannot stop the docker daemon.

To avoid the error and then uninstall the docker, we can modify the ``pid`` in ``docker-ssd.pid`` with a ``pid`` of a process which is not so important.

Okay, we can launch ``sleep 200``.

In 200 seconds, we can run ``ps -ef | grep sleep`` to obtain the pid of process of ``sleep``.

```bash
> ps -ef | grep sleep
inoki    25219 21212  0 19:01 tty1     00:00:00 sleep 200
inoki    25221 24653  0 19:01 tty2     00:00:00 grep --color=auto sleep
```

We fill ``docker-ssd.pid`` with such pid.

Okay, we uninstall ``docker.io``.

```
> sudo apt-get remove docker.io
Reading package lists... Done
Building dependency tree
Reading state information... Done
The following packages were automatically installed and are no longer required:
  bridge-utils cgroupfs-mount ubuntu-fan
Use 'sudo apt autoremove' to remove them.
The following packages will be REMOVED:
  docker.io
0 upgraded, 0 newly installed, 1 to remove and 0 not upgraded.
1 not fully installed or removed.
After this operation, 90.2 MB disk space will be freed.
Do you want to continue? [Y/n]
(Reading database ... 76380 files and directories currently installed.)
Removing docker.io (17.03.2-0ubuntu2~16.04.1) ...
'/usr/share/docker.io/contrib/nuke-graph-directory.sh' -> '/var/lib/docker/nuke-graph-directory.sh'
invoke-rc.d: could not determine current runlevel
 * Stopping Docker: docker                                                                                       [ OK ]
Processing triggers for man-db (2.7.5-1) ...
```

All goes well and tout va bien!
