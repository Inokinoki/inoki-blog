---
title: 【译】从零开始的 Wayland 合成器 —— 2. 装配服务器
date: 2021-09-06 20:47:40
tags:
- 中文
- 翻译
categories:
- [Translation, Chinese]
- [Linux, Wayland]
---

原文链接：[Writing a Wayland Compositor, Part 2: Rigging up the server ](https://drewdevault.com/2018/02/22/Writing-a-wayland-compositor-part-2.html)

**译者注：这个系列文章中使用的为早期 wlroots 版本，大约在 0.3 到 0.4.1 之间，请注意安装的版本**

这是关于使用 wlroots 从头开始编写 Wayland 合成器的系列文章中的第二篇。如果你还没有看过第一篇文章，可以看看。上一次，我们最终得到了一个应用程序，它启动了 wlroots 后端，枚举了输出设备，并在屏幕上绘制了一些漂亮的颜色。今天，我们将开始接受 Wayland 客户端的连接，尽管我们还不打算对它们做什么。

本文剖析的提交是b45c651。

关于这些博客文章的性质，我想说的是：我们将需要大量的文章来充实我们的合成器。我将会比平时更频繁地发布这些文章，大概每周1-2篇，并继续以通常的速度发布我的文章。好吗？很好。

所以我们已经启动了后端，并且正在渲染一些有趣的东西，但是我们仍然没有运行Wayland服务器--Wayland客户端没有连接到我们的应用程序。添加这个其实很容易：

```diff
@@ -113,12 +113,18 @@ int main(int argc, char **argv) {
        server.new_output.notify = new_output_notify;
        wl_signal_add(&server.backend->events.new_output, &server.new_output);
 
+       const char *socket = wl_display_add_socket_auto(server.wl_display);
+       assert(socket);
+
        if (!wlr_backend_start(server.backend)) {
                fprintf(stderr, "Failed to start backend\n");
                wl_display_destroy(server.wl_display);
                return 1;
        }
 
+       printf("Running compositor on wayland display '%s'\n", socket);
+       setenv("WAYLAND_DISPLAY", socket, true);
+
        wl_display_run(server.wl_display);
        wl_display_destroy(server.wl_display);
        return 0;
```

这就是了! 如果你再次运行 McWayface，它将打印出这样的东西：

```
Running compositor on wayland display 'wayland-1'
```

Weston 是 Wayland 的参考合成器，包括一些简单的参考客户端。我们可以使用 `weston-info` 连接到我们的服务器并列出全局变量：

```
$ WAYLAND_DISPLAY=wayland-1 weston-info
interface: 'wl_drm', version: 2, name: 1
```

如果你还记得我的《Wayland 简介》，Wayland 服务器通过 Wayland 注册表向客户端输出了一个全局变量列表。这些全局变量提供了客户端可以用来与服务器互动的接口。我们通过 wlroots 获得了 wl_drm，但我们实际上还没有连接上任何有用的东西。wlroots提供了许多 "类型"，其中大部分是像这样的 Wayland 全局接口的实现。

一些 wlroots 的实现需要你进行一些操纵，但其中有几个是自动搞定的。装配这些东西很容易：

```diff
        printf("Running compositor on wayland display '%s'\n", socket);
        setenv("WAYLAND_DISPLAY", socket, true);
+
+       wl_display_init_shm(server.wl_display);
+       wlr_gamma_control_manager_create(server.wl_display);
+       wlr_screenshooter_create(server.wl_display);
+       wlr_primary_selection_device_manager_create(server.wl_display);
+       wlr_idle_create(server.wl_display);
 
        wl_display_run(server.wl_display);
        wl_display_destroy(server.wl_display);
```

请注意，这些接口中的一些并不一定是你通常想要暴露给所有 Wayland 客户端的接口--例如，screenshooter 是应该被保护起来的东西。我们将在后面的文章中讨论安全问题。现在，如果我们再次运行 weston-info，我们会看到更多的全局变量已经出现：

```
$ WAYLAND_DISPLAY=wayland-1 weston-info
interface: 'wl_shm', version: 1, name: 3
	formats: XRGB8888 ARGB8888
interface: 'wl_drm', version: 2, name: 1
interface: 'gamma_control_manager', version: 1, name: 2
interface: 'orbital_screenshooter', version: 1, name: 3
interface: 'gtk_primary_selection_device_manager', version: 1, name: 4
interface: 'org_kde_kwin_idle', version: 1, name: 5
```

你会发现 wlroots 实现了各种不同来源的协议--在这里我们看到 Orbital、GTK 和 KDE的 协议。wlroots 包括一个 Orbital 屏幕截图的客户端实例--我们现在可以用它来给我们的合成器截个图：

```
$ WAYLAND_DISPLAY=wayland-1 ./examples/screenshot
cannot set buffer size
```

啊，这是个问题--你可能已经注意到，我们没有任何 wl_output 的全局变量，屏幕截图客户端依靠它来计算屏幕截图缓冲区的分辨率。我们也可以添加这些：

```diff
@@ -95,6 +99,8 @@ static void new_output_notify(struct wl_listener *listener, void *data) {
        wl_signal_add(&wlr_output->events.destroy, &output->destroy);
        output->frame.notify = output_frame_notify;
        wl_signal_add(&wlr_output->events.frame, &output->frame);
+
+       wlr_output_create_global(wlr_output);
 }
```

再次运行 weston-info 会给我们提供一些关于我们现在的 output 的信息：

```
$ WAYLAND_DISPLAY=wayland-1 weston-info
interface: 'wl_drm', version: 2, name: 1
interface: 'wl_output', version: 3, name: 2
	x: 0, y: 0, scale: 1,
	physical_width: 0 mm, physical_height: 0 mm,
	make: 'wayland', model: 'wayland',
	subpixel_orientation: unknown, output_transform: normal,
	mode:
		width: 952 px, height: 521 px, refresh: 0.000 Hz,
		flags: current
interface: 'wl_shm', version: 1, name: 3
	formats: XRGB8888 ARGB8888
interface: 'gamma_control_manager', version: 1, name: 4
interface: 'orbital_screenshooter', version: 1, name: 5
interface: 'gtk_primary_selection_device_manager', version: 1, name: 6
interface: 'org_kde_kwin_idle', version: 1, name: 7
```

现在我们可以拍下那张截图了! 给它一个机会（wwwwww）!

我们现在已经接近完成了。下一篇文章将介绍 Surface 的概念，我们将用它们来渲染我们的第一个窗口。如果你在这篇文章中遇到任何问题，请联系我，sir@cmpwn.com，或者联系 wlroots 团队，#sway-devel。

本文及原文使用 CC-BY-SA 协议开放。
