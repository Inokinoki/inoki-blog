---
title: FFmpeg Decoding
date: 2019-12-16 18:42:00
tags:
- FFmpeg
categories:
- FFmpeg
---

`FFmpeg` is a complete, cross-platform solution to record, convert and stream audio and video.

But on the Internet, almost all tutorials only tell you how to use the `FFmpeg` with its executables.

Although the origin tool `ffmpeg` executable is good enough, it's still good to know how `FFmpeg` works behind. This serie of posts will explore and build encoders, decoders, filters and other utilities with `FFmpeg` libraries for you and for myself.

In this post, we aim at building a video decoder from scratch.

# Target

To make it simple, we're going to build a program:

1. which accepts an argument, as the path of video
2. and the second argument, as the frame index of frames in the video

So, we just need a simple `main` function:

```c
int main(int argc, char *argv[])
{
    // argc == 3
    // argv[1] - file path
    // argv[2] - frame index
    if (argc < 3) {
        printf("Please provide file path and frame index");
        return -1;
    }

    return 0;
}
```

# Read arguments

For the file path, we should be able to directly use it to open the file. As a result, we do not need to handle with it.

```c
int frameIndex = 0;

frameIndex = atoi(argv[2]);
if (frameIndex <= 0) {
    printf("Please provide a positive frame index");
    return -1;
}
```

Here we just read the second argument and transfer it to an integer.

# Read file

We have already got the file path, so we can use the function `avformat_open_input`, defined in `libavformat/avformat.h` and implemented in `libavformat/utils.c`, to open and store it into a `FFmpeg` readable and operatable format.

```c
int avformat_open_input(AVFormatContext **ps, const char *url, ff_const59 AVInputFormat *fmt, AVDictionary **options);
```

To call it, we need an `AVFormatContext` instance. For the last two parameters, we just let them `NULL`.

```c
AVFormatContext   *pFormatCtx = NULL;

// Open video file
if (avformat_open_input(&pFormatCtx, argv[1], NULL, NULL) != 0)
    return -1; // Couldn't open file
```

Up to now, we have the handle(context) to the file.

# Find video stream

There are several streams in one video file, for example, there is video stream, audio stream. Some has also subtitle stream.

We firstly get the stream information, and it will be filled into `pFormatCtx->nb_streams`.

```c
// Retrieve stream information
if (avformat_find_stream_info(pFormatCtx, NULL) < 0)
    return -1; // Couldn't find stream information

// Find the first video stream
videoStream = -1;
printf("Stream counter: %d\n", pFormatCtx->nb_streams);
for (i = 0; i < pFormatCtx->nb_streams; i++) {
    if (pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
        videoStream = i;
        break;
    }
}
```

Then we try to find out which is the video stream.

# Codec context

As not to destroy the information in the origin video, it's better to make a copy to the video.

```c
AVCodecContext    *pCodecCtxOrig = NULL;
AVCodecContext    *pCodecCtx = NULL;
AVCodec           *pCodec = NULL;

AVCodecParameters *par = NULL;

// Allocate memory to store it
par = avcodec_parameters_alloc();

// Get a pointer to the codec context for the video stream
pCodecCtxOrig = pFormatCtx->streams[videoStream]->codec;
// Find the decoder for the video stream
pCodec = avcodec_find_decoder(pCodecCtxOrig->codec_id);
if (pCodec == NULL) {
    fprintf(stderr, "Unsupported codec!\n");
    return -1; // Codec not found
}
else {
    printf("Codec: %s!\n", pCodec->long_name);
}

// Copy context
pCodecCtx = avcodec_alloc_context3(pCodec);

if (avcodec_parameters_from_context(par, pCodecCtxOrig) < 0) {
    fprintf(stderr, "Copy param from origin context failed!\n");
    return -1; // Codec not found
}

if (avcodec_parameters_to_context(pCodecCtx, par) < 0) {
    fprintf(stderr, "Copy param to context failed!\n");
    return -1; // Codec not found
}

// Open codec
if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0)
    return -1; // Could not open codec
```

# Read frame

The core functionnality is here:

```c
AVFrame           *pFrame = NULL;
AVPacket          packet;

// Allocate video frame
pFrame = av_frame_alloc();

// Read frames and save first five frames to disk
i = 0;
while (av_read_frame(pFormatCtx, &packet) >= 0) {
    // Is this a packet from the video stream?
    if (packet.stream_index == videoStream) {
        // Decode video frame
        // avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, &packet);
        avcodec_send_packet(pCodecCtx, &packet);
        avcodec_receive_frame(pCodecCtx, pFrame);

        // Frame got
        if (++i == frameIndex)
            printf("Frame \t%d: width - %d height - %d\n", i, pFrame->width, pFrame->height);
    }

    // Free the packet that was allocated by av_read_frame
    // av_free_packet(&packet);
    av_packet_unref(&packet);
}
```

In this code, we use `av_read_frame` to read a frame until there is no more frame.

Then, `avcodec_send_packet(pCodecCtx, &packet);` and `avcodec_receive_frame(pCodecCtx, pFrame);` are called to use the codec context to retrieve the frame in this packet. Then, we can get the frame information and the origin bytes stream in the `AVFrame` structure.

# Free memory

Finally, do not forget to free all momeries which have been allocated.

```c
avcodec_parameters_free(&par);

// Free the YUV frame
av_frame_free(&pFrame);

// Close the codecs
avcodec_close(pCodecCtx);
avcodec_close(pCodecCtxOrig);

// Close the video file
avformat_close_input(&pFormatCtx);
```

# Conclusion

Up to here, we have been abled to retrieve all frames in a video, and may do some processing on it :)

You should know how we can do a decoding of video using `FFmpeg` API.

You can find the full code here:

```c
#include <stdio.h>

#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>

int main(int argc, char *argv[])
{
	// Initalizing these to NULL prevents segfaults!
	AVFormatContext   *pFormatCtx = NULL;
	int               i, videoStream;
	AVCodecContext    *pCodecCtxOrig = NULL;
	AVCodecContext    *pCodecCtx = NULL;
	AVCodec           *pCodec = NULL;
	AVFrame           *pFrame = NULL;
	AVPacket          packet;

	AVCodecParameters *par = NULL;

	int frameIndex = 0;

	if (argc < 3) {
		printf("Please provide file path and frame index");
		return -1;
	}

	frameIndex = atoi(argv[2]);
	if (frameIndex <= 0) {
		printf("Please provide a positive frame index");
		return -1;
	}
	
	par = avcodec_parameters_alloc();

	// Do not need
	// av_register_all();

	// Open video file
	if (avformat_open_input(&pFormatCtx, argv[1], NULL, NULL) != 0)
		return -1; // Couldn't open file

	// Retrieve stream information
	if (avformat_find_stream_info(pFormatCtx, NULL) < 0)
		return -1; // Couldn't find stream information

	// Dump information about file onto standard error
	av_dump_format(pFormatCtx, 0, argv[1], 0);

	// Find the first video stream
	videoStream = -1;
	printf("Stream counter: %d\n", pFormatCtx->nb_streams);
	for (i = 0; i < pFormatCtx->nb_streams; i++) {
		if (pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
			videoStream = i;
			break;
		}
	}
	if (videoStream == -1)
		return -1; // Didn't find a video stream

	printf("Stream %d is the video stream\n", videoStream);

	// Get a pointer to the codec context for the video stream
	pCodecCtxOrig = pFormatCtx->streams[videoStream]->codec;
	// Find the decoder for the video stream
	pCodec = avcodec_find_decoder(pCodecCtxOrig->codec_id);
	if (pCodec == NULL) {
		fprintf(stderr, "Unsupported codec!\n");
		return -1; // Codec not found
	}
	else {
		printf("Codec: %s!\n", pCodec->long_name);
	}

	// Copy context
	pCodecCtx = avcodec_alloc_context3(pCodec);

	if (avcodec_parameters_from_context(par, pCodecCtxOrig) < 0) {
		fprintf(stderr, "Copy param from origin context failed!\n");
		return -1; // Codec not found
	}

	if (avcodec_parameters_to_context(pCodecCtx, par) < 0) {
		fprintf(stderr, "Copy param to context failed!\n");
		return -1; // Codec not found
	}

	// Open codec
	if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0)
		return -1; // Could not open codec

	// Allocate video frame
	pFrame = av_frame_alloc();

	// Read frames and save first five frames to disk
	i = 0;
	while (av_read_frame(pFormatCtx, &packet) >= 0) {
		// Is this a packet from the video stream?
		if (packet.stream_index == videoStream) {
			// Decode video frame
			// avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, &packet);
			avcodec_send_packet(pCodecCtx, &packet);
			avcodec_receive_frame(pCodecCtx, pFrame);

			// Frame got
			if (++i == frameIndex)
				printf("Frame \t%d: width - %d height - %d\n", i, pFrame->width, pFrame->height);
		}

		// Free the packet that was allocated by av_read_frame
		// av_free_packet(&packet);
		av_packet_unref(&packet);
	}

	avcodec_parameters_free(&par);

	// Free the YUV frame
	av_frame_free(&pFrame);

	// Close the codecs
	avcodec_close(pCodecCtx);
	avcodec_close(pCodecCtxOrig);

	// Close the video file
	avformat_close_input(&pFormatCtx);

	return 0;
}
```
