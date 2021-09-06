---
title: 【译】从头开始构建 Wayland 合成器 —— 1. Hello wlroots
date: 2021-09-05 20:47:40
tags:
- 中文
- 翻译
categories:
- [Translation, Chinese]
- [Linux, Wayland]
---

原文链接：[Writing a Wayland Compositor, Part 1: Hello wlroots](https://drewdevault.com/2018/02/17/Writing-a-Wayland-compositor-1.html)

**译者注：这个系列文章中使用的为早期 wlroots 版本，大约在 0.3 到 0.4.1 之间，请注意安装的版本**

这是一系列文章中的第一篇。

我正在写一篇关于从头开始构建一个 Wayland 合成器的文章。你可能知道，我（原作者）是 Sway 的主要维护者，这是一个相当受欢迎的 Wayland 合成器。在过去的几个月里，我们和许多其他优秀的开发者一起，一直在开发 wlroots。这是一个用于创建新的 Wayland 合成器的强大工具，但它非常复杂难以理解。不要感到绝望！这篇文章的目的是让大家了解 Wayland 合成器。这些文章的目的是让你理解并自如地使用它。

在我们深入讨论之前，请注意：wlroots 团队今天开始了一项众筹活动，以资助我们每个核心贡献者的旅行，让他们亲自会面并在黑客马拉松上工作两周。请考虑为该活动做出贡献!

在试图理解这一系列博文之前，你必须阅读并理解我之前的文章《Wayland 介绍》，因为我将依靠那里介绍的概念和术语来加快事情的进展。一些 OpenGL 的背景是有帮助的，但不是必须的。对 C 语言的良好理解是必须的。如果你对这个系列的任何文章有任何问题，请通过 sir@cmpwn.com 直接联系我，或者联系 irc.freenode.net 上的 #sway-devel 的 wlroots 团队。

在这一系列的文章中，我们正在构建的合成器将托管在 GitHub 上——Wayland McWayface。本系列文章中的每篇文章都会对从零到功能齐全的 Wayland 合成器之间的一次提交进行分解，这篇文章的提交是 f89092e。我只解释重要的部分--我建议你单独查看整个提交。

让我们开始吧。

# 第一步

首先，我将定义一个结构来保存我们的合成器的状态：

```c
struct mcw_server {
    struct wl_display *wl_display;
    struct wl_event_loop *wl_event_loop;
};
```

注意：mcw 是 McWayface 的简称。我们将在整个系列文章中使用这个缩写。我们将把其中一个放在一边，并为它初始化一个 Wayland 的 display（注意：我们完全可以利用 wlroots 后端来制作非 Wayland 合成器的应用程序。然而，我们还是需要一个 Wayland 的 display，因为事件循环对于很多 wlroots 的内部程序来说是必要的）：

```c
int main(int argc, char **argv) {
    struct mcw_server server;

    server.wl_display = wl_display_create();
    assert(server.wl_display);
    server.wl_event_loop = wl_display_get_event_loop(server.wl_display);
    assert(server.wl_event_loop);
    return 0;
}
```

Wayland 的 display 给了我们很多东西，但现在我们关心的是事件循环。这个事件循环被深深地整合到了 wlroots 中，它被用来在整个应用程序中分配信号，当各种文件描述符上的数据可用时被通知，等等。

# 创建后端

接下来，我们需要创建后端：

```c
struct mcw_server {
    struct wl_display *wl_display;
    struct wl_event_loop *wl_event_loop;
 
    struct wlr_backend *backend;
};
```

后端是我们第一个 wlroots 概念，它负责从你那里抽象出低层次的输入和输出实现。每个后端可以生成零个或多个输入设备（如鼠标、键盘等）和零个或多个输出设备（如你桌上的显示器）。后端与 Wayland 无关--它们的目的是帮助你使用你作为 Wayland 合成器所需的其他 API。有各种不同目的的后端：

- drm 后端利用 Linux 的 DRM 子系统直接渲染到你的物理显示器
- libinput 后端利用 libinput 来枚举和控制物理输入设备
- Wayland 后端在另一个运行 Wayland 合成器的窗口上创建 "输出"，允许你对合成器进行嵌套。这对调试很有用
- X11 后端与 Wayland 后端类似，但在 X11 服务器上打开一个 X11 窗口，而不是在 Wayland 服务器上打开一个 Wayland 窗口

另一个重要的后端是多后端，它允许你同时初始化几个后端并聚合它们的输入和输出设备。例如，这对于同时利用 drm 和 libinput 是必要的。

我们的库 wlroots 提供了一个辅助函数，用于根据用户的环境自动选择最合适的后端：

```c
    server.wl_event_loop = wl_display_get_event_loop(server.wl_display);
    assert(server.wl_event_loop);
 
    server.backend = wlr_backend_autocreate(server.wl_display);
    assert(server.backend);
    return 0;
}
```

我一般建议在开发过程中使用 Wayland 或 X11 后端，特别是在我们有办法退出合成器之前。如果你在运行中的 Wayland 或 X11 会话中调用 `wlr_backend_autocreate`，相应的后端会被自动选择。

我们现在可以启动后端并进入 Wayland 事件循环：

```c
    if (!wlr_backend_start(server.backend)) {
        fprintf(stderr, "Failed to start backend\n");
        return 1;
    }
    
    wl_display_run(server.wl_display);
    wl_display_destroy(server.wl_display);
    return 0;
```

如果你在这时运行你的合成器，你应该看到后端启动，然后......什么都不做。如果你从运行中的 Wayland 或 X11 服务器上运行，它会打开一个窗口。如果你在 DRM 上运行它，它可能会做得很少，你甚至不能切换到另一个 TTY 来杀死它。

# 添加事件监听函数

为了渲染东西，我们需要知道我们可以在哪些输出上渲染。后台提供了一个 `wl_signal`，当它得到一个新的输出时通知我们。这将发生在启动时，以及任何输出在运行时被热插拔时。

让我们把它添加到我们的服务器结构体中：

```c
struct mcw_server {
    struct wl_display *wl_display;
    struct wl_event_loop *wl_event_loop;
    struct wlr_backend *backend;

    struct wl_listener new_output;
    struct wl_list outputs; // mcw_output::link
};
```

这增加了一个 `wl_listeners`，当新的输出被添加时，它就会被通知。我们还添加了一个 `wl_list`（这只是一个由 `libwayland-server` 提供的链接列表），我们以后会在其中存储一些状态。为了得到通知，我们必须使用 `wl_signal_add`：

```c
    assert(server.backend);

    wl_list_init(&server.outputs);
    server.new_output.notify = new_output_notify;
    wl_signal_add(&server.backend->events.new_output, &server.new_output);
 
    if (!wlr_backend_start(server.backend)) {
```

我们在这里指定被通知的函数 `new_output_notify`：

```c
static void new_output_notify(struct wl_listener *listener, void *data) {
    struct mcw_server *server = wl_container_of(
        listener, server, new_output);
    struct wlr_output *wlr_output = data;

    if (!wl_list_empty(&wlr_output->modes)) {
        struct wlr_output_mode *mode =
            wl_container_of(wlr_output->modes.prev, mode, link);
        wlr_output_set_mode(wlr_output, mode);
    }

    struct mcw_output *output = calloc(1, sizeof(struct mcw_output));
    clock_gettime(CLOCK_MONOTONIC, &output->last_frame);
    output->server = server;
    output->wlr_output = wlr_output;
    wl_list_insert(&server->outputs, &output->link);
}
```

这有点复杂! 这个函数在处理传入的 `wlr_output` 时有几个作用。`wl_container_of` 使用一些基于 `offsetof` 的魔法，从监听器的指针中得到 `mcw_server` 的引用，然后我们将数据投到实际的类型，即 `wlr_output`。

# 设置输出

我们要做的下一件事是设置输出模式。一些后端（特别是 X11 和 Wayland）不支持设置模式，但它们对于 DRM 是必要的。输出模式指定了输出所支持的尺寸和刷新率，例如 1920x1080@60Hz。这个 if 语句的主体只是选择了最后一个（通常是最高的分辨率和刷新率），并通过 `wlr_output_set_mode` 将其应用于输出。我们必须设置输出模式，以便对其进行渲染。

然后，我们设置了一些状态，让我们在合成器中跟踪这些输出。我在文件的顶部添加了这个结构定义：

```c
struct mcw_output {
    struct wlr_output *wlr_output;
    struct mcw_server *server;
    struct timespec last_frame;

    struct wl_list link;
};
```

这将是我们用来存储我们对这个输出的任何状态的结构，这些状态是特定于我们的合成器需求的。我们包括一个对 `wlr_output` 的引用，一个对拥有这个输出的 `mcw_server` 的引用，以及最后一帧的时间，这在后面会有用。我们还预留了一个 `wl_list`，它被 `libwayland` 用于链接列表。

最后，我们将这个输出添加到服务器的输出列表中。

我们现在可以使用了，但它会泄露内存。我们还需要处理输出的移除，用一个由 `wlr_output` 提供的信号。我们将监听器添加到 `mcw_output` 结构中：

```c
struct mcw_output {
    struct wlr_output *wlr_output;
    struct mcw_server *server;
    struct timespec last_frame;

    struct wl_listener destroy;
 
    struct wl_list link;
};
```

然后我们在增加输出的时候把它加进来：

```c
    wl_list_insert(&server->outputs, &output->link);

    output->destroy.notify = output_destroy_notify;
    wl_signal_add(&wlr_output->events.destroy, &output->destroy);
}
```

这将调用我们的 `output_destroy_notify` 函数来处理当输出被拔掉或以其他方式从 `wlroots` 移除时的清理工作。我们的处理程序看起来像这样：

```c
static void output_destroy_notify(struct wl_listener *listener, void *data) {
    struct mcw_output *output = wl_container_of(listener, output, destroy);
    wl_list_remove(&output->link);
    wl_list_remove(&output->destroy.link);
    wl_list_remove(&output->frame.link);
    free(output);
}
```

这些代码应该能够自解释的。我们现在有一个对输出的引用。然而，我们仍然没有渲染任何东西--如果你再次运行合成器，你会发现同样的行为。

# 监听帧的更新信号

为了渲染东西，我们必须监听帧的信号。根据选择的模式，输出只能以一定的速率接收新的帧。我们在 `wlroots` 中为你跟踪这一点，并在绘制新帧的时候发出帧信号。

让我们为此目的在 `mcw_output` 结构中添加一个监听器。

```c
struct mcw_output {
    struct wlr_output *wlr_output;
    struct mcw_server *server;
 
    struct wl_listener destroy;
    struct wl_listener frame;
 
    struct wl_list link;
};
```

然后，我们可以扩展 `new_output_notify` 来注册帧信号的监听器。

```c
    output->destroy.notify = output_destroy_notify;
    wl_signal_add(&wlr_output->events.destroy, &output->destroy);
    output->frame.notify = output_frame_notify;
    wl_signal_add(&wlr_output->events.frame, &output->frame);
}
```

现在，每当输出准备好了一个新的帧，`output_frame_notify` 就会被调用。不过，我们仍然需要编写这个函数。让我们从最基本的开始。

```c
static void output_frame_notify(struct wl_listener *listener, void *data) {
    struct mcw_output *output = wl_container_of(listener, output, frame);
    struct wlr_output *wlr_output = data;
}
```

# 渲染一些内容

为了在这里渲染任何东西，我们需要首先获得一个 `wlr_renderer2`。我们可以从后端获得一个。

```c
static void output_frame_notify(struct wl_listener *listener, void *data) {
    struct mcw_output *output = wl_container_of(listener, output, frame);
    struct wlr_output *wlr_output = data;
    struct wlr_renderer *renderer = wlr_backend_get_renderer(wlr_output->backend);
}
```

现在我们可以利用这个渲染器，在输出端画一些东西：

```c
static void output_frame_notify(struct wl_listener *listener, void *data) {
    struct mcw_output *output = wl_container_of(listener, output, frame);
    struct wlr_output *wlr_output = data;
    struct wlr_renderer *renderer = wlr_backend_get_renderer(wlr_output->backend);

    wlr_output_make_current(wlr_output, NULL);
    wlr_renderer_begin(renderer, wlr_output);

    float color[4] = {1.0, 0, 0, 1.0};
    wlr_renderer_clear(renderer, color);

    wlr_output_swap_buffers(wlr_output, NULL, NULL);
    wlr_renderer_end(renderer);
}
```

调用 `wlr_output_make_current` 使输出的 OpenGL 上下文成为 "当前"，从这里你可以使用 OpenGL 调用来渲染到输出的缓冲区。我们调用 `wlr_renderer_begin` 来为我们配置一些合理的OpenGL默认值。

在这一点上，我们可以开始渲染了。我们将在后面详细介绍你能用 `wlr_renderer` 做什么，但现在我们将满足于把输出清除为纯红色。

当我们完成渲染后，我们调用 `wlr_output_swap_buffers` 来交换输出的前后缓冲区，将我们所渲染的内容提交到实际的屏幕上。我们调用 `wlr_renderer_end` 来清理 OpenGL 上下文，我们就完成了。现在运行我们的合成器应该可以看到一个纯红色的屏幕

# 总结

今天的文章到此结束。如果你看一下本文所描述的提交，你会发现我用一些代码更进一步，每一帧都把显示器清除成不同颜色。请随意尝试类似的变化吧

在接下来的两篇文章中，我们将完成 Wayland 服务器的连接，并在屏幕上呈现一个 Wayland 客户端。请期待吧!

本文及原文使用 CC-BY-SA 协议开放。
