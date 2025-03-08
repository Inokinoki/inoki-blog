---
title: 在 Proxy 环境中使用 GitHub SSH 的 git 操作 
date: 2025-03-08 06:02:23
tags:
- GitHub
- SSH
- git
- Proxy
categories:
- [Network, Proxy]
- Protocol
---

上次回国，发现墙又高了：GitHub 的 SSH 端口（22）现在会完全被阻断，导致无法正常使用 SSH 协议进行 `git clone`、`git pull` 等操作。

事实上，封禁 22 端口在公司网络环境中也可能是一个很普遍的操作，用于禁止员工随意使用 ssh 登录不受控的机器。

这种情况下，GitHub 官方是推荐使用 HTTPS 协议进行克隆的，但是需要配置 GitHub 的 login 集成或者是使用 token 来进行私有仓库的操作。但如果仍然希望使用 SSH，可以参考本文的做法，仅此记录一下。


# 问题现象

首先可以测试一下 SSH 是不是被阻断了，当你尝试使用 SSH 连接 GitHub 时，执行以下命令：

```sh
$ ssh -T git@github.com
```

如果遇到连接超时或被拒绝的情况，那么就是被阻断了，同时 `HTTP_PROXY`、`HTTPS_PROXY` 和 `ALL_PROXY` 仅对 HTTPS 协议的 git 操作有效，并不会对 SSH 协议的 git 操作生效。

在这种情况下，GitHub 提供了[基于 HTTPS（443）端口的 SSH 协议的连接方式](https://docs.github.com/en/authentication/troubleshooting-ssh/using-ssh-over-the-https-port)，可以绕开针对 SSH 22 端口的封禁。

如果改用 443 端口上的 SSH 连接可以成功的话（说明不是基于协议识别封禁的）：

```sh
$ ssh -T -p 443 git@ssh.github.com
# Hi USERNAME! You've successfully authenticated, but GitHub does not
# provide shell access.
```

那么就可以采用这种方式。

## 方案 1：手动更改 SSH 命令

在 `git clone` 或 `git pull` 等命令中手动使用 `ssh.github.com` 并指定 SSH 端口为 443。例如：

```sh
git clone ssh://git@ssh.github.com:443/your-repo.git
```

或者在已有的仓库中修改远程 URL：

```sh
git remote set-url origin ssh://git@ssh.github.com:443/your-repo.git
```

但这就需要对所用到的仓库都进行修改，太麻烦了。

## 方案 2：修改 SSH 配置文件

你也可以直接修改 SSH 配置文件（`~/.ssh/config`），让 SSH 将 `github.com` 直接当作 `ssh.github.com` 的别名来连接 GitHub，并自动使用 443 端口。

编辑 `~/.ssh/config`（如果文件不存在，可以手动创建）：

```sh
echo "
Host github.com
  Hostname ssh.github.com
  Port 443
  User git
" >> ~/.ssh/config
```

然后测试 SSH 连接：

```sh
$ ssh -T git@github.com
```

如果输出如下信息，说明配置成功：

```
# Hi USERNAME! You've successfully authenticated, but GitHub does not
# provide shell access
```

## 方案 3：强制使用 SOCKS5 代理进行 SSH 连接

如果你不想使用 `ssh.github.com`，并且已经在本地配置了 SOCKS5 代理，可以让 git SSH 通过代理连接 GitHub。

在 `~/.ssh/config` 文件中添加以下内容：

```sh
Host github.com
  Hostname github.com
  ProxyCommand nc -X 5 -x 127.0.0.1:1080 %h %p
```

其中 `127.0.0.1:1080` 是本地 SOCKS5 代理的地址，根据你的代理工具调整。

也可以使用 `GIT_SSH_COMMAND` 环境变量来修改默认 SSH 连接命令，详情可参考 [git 的文档](https://github.com/git/git/blob/master/Documentation/config/ssh.adoc)。

# 结论

如果当前网络封禁了 22 端口时，你可以通过以下三种方法绕过针对 GitHub 的封锁：

1. 直接使用 `ssh://git@ssh.github.com:443/your-repo.git` 进行 Git 操作。
2. 修改 `~/.ssh/config`，让 GitHub 连接自动走 `ssh.github.com` 的 443 端口。
3. 使用 SOCKS5 代理，让 SSH 通过代理访问 GitHub。

你可以根据自己的网络环境选择最适合的方法，确保顺畅地访问 GitHub。
