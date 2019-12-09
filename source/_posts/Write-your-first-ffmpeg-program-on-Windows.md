---
title: Write your first FFmpeg program on Windows
date: 2019-12-09 22:48:00
tags:
- FFmpeg
- Windows
categories:
- FFmpeg
---

FFmpeg is a complete, cross-platform solution to record, convert and stream audio and video. It's not difficult to write your own simple video editor with it.

This post will give you a guide, how to write a program with FFmpeg on Windows, with Visual Studio.

# Create VS Project

Create a new Visual C++ project, do not use precompiled header file.

Then, right click on the project to open Property panel.

# DLL files

Add your `ffmpeg-<version>-win64-shared\bin` into your system PATH.

# Include files

Add your `ffmpeg-<version>-win64-dev\include` into VC++ Directory -> Include directory.

# Lib files

Add your `ffmpeg-<version>-win64-dev\lib` into VC++ Directory -> Reference directory.

Add `swscale.lib`, `avutil.lib`, `avformat.lib`, `avcodec.lib`, `avdevice.lib`, `avfilter.lib`, `swresample.lib` and `postproc.lib` into Linker -> Input -> Addons.

# Code

This code comes from FFmpeg samples, it works as a video decoder but it just gets and prints video meta information.

```c
#include <stdio.h>

#include <libavformat/avformat.h>
#include <libavutil/dict.h>

int main (int argc, char **argv)
{
    AVFormatContext *fmt_ctx = NULL;
    AVDictionaryEntry *tag = NULL;
    int ret;

    if (argc != 2) {
        printf("usage: %s <input_file>\n"
               "example program to demonstrate the use of the libavformat metadata API.\n"
               "\n", argv[0]);
        return 1;
    }

    if ((ret = avformat_open_input(&fmt_ctx, argv[1], NULL, NULL)))
        return ret;

    if ((ret = avformat_find_stream_info(fmt_ctx, NULL)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot find stream information\n");
        return ret;
    }

    while ((tag = av_dict_get(fmt_ctx->metadata, "", tag, AV_DICT_IGNORE_SUFFIX)))
        printf("%s=%s\n", tag->key, tag->value);

    avformat_close_input(&fmt_ctx);
    return 0;
}
```

# Launch

To run it in Visual Studio, in `debugging`, add the path of your video into command line arguments.

And right click on the green triangle.

In the terminal, you should be able to see the meta information like this:

```
major_brand=mp42
minor_version=0
compatible_brands=mp41isom
creation_time=2019-08-25T20:22:43.000000Z
```

Enjoy!
