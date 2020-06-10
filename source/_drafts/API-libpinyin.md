---
title: 关于完全看不懂 libpinyin 在干什么的事
date: 2020-06-07 12:13:00
tags:
- IBus
- libpinyin
categories:
- ibus-libpinyin
---

最近在写 ibus-libpinyin 云输入过程中，了解到它的另一个部分，libbopomofo 这个注音输入法，理论上也存在可以直接用云输入的可能性。但需要一个注音到全拼拼音的转换，根据 [@epico](https://github.com/epico) 的评论，这个功能 libpinyin 应该可以完成。

这篇文章尝试解读 ibus-libpinyin 背后的 libpinyn 的 API，为实现 libbopomofo 的云输入功能做准备。（PS：之后也想尝试给 MacOS 写一个基于 libpinyin 的输入法）

# 简介

在 libpinyin 的仓库页面，有这么一段话总结了 libpinyin 的功能：

    Library to deal with pinyin.

    The libpinyin project aims to provide the algorithms core for intelligent sentence-based Chinese pinyin input methods.

也就是说，它的功能就是处理拼音，从而提供一个实现一个智能的中文拼音输入法所需的算法核心。

这个项目的主要维护者是 [@epico](https://github.com/epico)，代码托管在：https://github.com/libpinyin/libpinyin

# 编译安装

它的依赖只有 `glib-2.0` 和 `Berkeley DB`（或 `Kyoto Cabinet`），安装好对应的依赖项之后，就可以编译安装了。

配置阶段有两种方法：

1. 一种是执行 `autogen.sh`，这个脚本会检测环境并自动调用 `autoconf` 来生成 Makefile；
2. 另一种是使用 CMake 来配置，这种方法需要在一个独立的构建目录，最终也是生成 Makefile。

之后 `make` 和 `make install` 两步到位就行啦。

如果不需要修改（比如刚开始我只对 ibus-libpinyin 添加功能），也可以直接从包管理器安装。

注意 libpinyin 只是一个库，它不提供任何输入法的功能。做这些事情的是 ibus-libpinyin、fcitx-libpinyin 等项目。

# 使用

安装之后，比较重要的几个文件是：

```
include/libpinyin-2.3.0/novel_types.h
include/libpinyin-2.3.0/pinyin.h
include/libpinyin-2.3.0/pinyin_custom2.h
include/libpinyin-2.3.0/zhuyin.h
include/libpinyin-2.3.0/zhuyin_custom2.h
lib/libpinyin.so
lib/libzhuyin.so
lib/pkgconfig/libpinyin.pc
lib/pkgconfig/libzhuyin.pc
```

其中 `.h` 为头文件，声明了导出函数；`.so` 就是具体实现的库文件；`.pc` 则是 Package Config 的文件，能够帮助找到头文件和库文件的位置。使用的话，包含头文件、链接库文件即可。

在 ibus-libpinyin 中，只使用了 `pinyin.h` 这个头文件：

```c
#include <pinyin.h>
```

尽管有 ibus-libbomopofo 注音输入法的功能，注音转候选仍是通过这个头文件中定义的一系列函数来完成的。

# 编程接口

头文件 `pinyin.h` 里的 API 都包含了完善的文档。

## 上下文管理

```c
pinyin_context_t * pinyin_init(const char * systemdir, const char * userdir);
```

用 `systemdir` 作为系统中的模型储存路径、`userdir` 作为用户特定的模型储存路径来创建一个上下文。

这个方法在 ibus-libpinyin 中的 `LibPinyinBackEnd::initPinyinContext` 和 `LibPinyinBackEnd::initChewingContext` 被调用，用来初始化拼音和注音（Chewing）模式下的上下文。

```c
void pinyin_fini(pinyin_context_t * context);
```

负责销毁一个上下文。

## 管理词库

```c
bool pinyin_load_phrase_library(pinyin_context_t * context,
                                guint8 index);
```

加载词库。这个方法实际调用的是 `_load_phrase_library`，而 `_load_phrase_library` 也会在 `pinyin_init` 中被调用。因此，`pinyin_load_phrase_library` 实际上并没有出现在 ibus-libpinyin 中。

```c
bool pinyin_unload_phrase_library(pinyin_context_t * context,
                                  guint8 index);
```

这个方法负责卸载词库。

```c
bool pinyin_load_addon_phrase_library(pinyin_context_t * context,
                                      guint8 index);

bool pinyin_unload_addon_phrase_library(pinyin_context_t * context,
                                        guint8 index);
```

加载/卸载附加词库。在 ibus-libpinyin 中的 `LibPinyinBackEnd::initPinyinContext` 和 `LibPinyinBackEnd::initChewingContext` 被调用，用来加载额外的词库。

## 添加/获取词语/句子

```c
import_iterator_t * pinyin_begin_add_phrases(pinyin_context_t * context,
                                             guint8 index);

bool pinyin_iterator_add_phrase(import_iterator_t * iter,
                                const char * phrase,
                                const char * pinyin,
                                gint count);

void pinyin_end_add_phrases(import_iterator_t * iter);
```

迭代器模式下的，在指定位置添加词语或句子。

```c
export_iterator_t * pinyin_begin_get_phrases(pinyin_context_t * context,
                                             guint index);

bool pinyin_iterator_has_next_phrase(export_iterator_t * iter);

bool pinyin_iterator_get_next_phrase(export_iterator_t * iter,
                                     gchar ** phrase,
                                     gchar ** pinyin,
                                     gint * count);

void pinyin_end_get_phrases(export_iterator_t * iter);
```

迭代器模式下的，从指定位置获取词语或句子。

## 用户习惯相关


```c
bool pinyin_save(pinyin_context_t * context);
```


## 按键方案

```c
bool pinyin_set_full_pinyin_scheme(pinyin_context_t * context,
                                   FullPinyinScheme scheme);

bool pinyin_set_double_pinyin_scheme(pinyin_context_t * context,
                                     DoublePinyinScheme scheme);

bool pinyin_set_zhuyin_scheme(pinyin_context_t * context,
                              ZhuyinScheme scheme);
```

分别是设置全拼、双拼、注音模式下的方案。后两个在 `LibPinyinBackEnd` 中用来设置用户选择的方案。

```c
gboolean
LibPinyinBackEnd::setPinyinOptions (Config *config)
{
    /* ... */
    DoublePinyinScheme scheme = config->doublePinyinSchema ();
    pinyin_set_double_pinyin_scheme (m_pinyin_context, scheme);
     /* ... */
}

gboolean
LibPinyinBackEnd::setChewingOptions (Config *config)
{
    /* ... */
    ZhuyinScheme scheme = config->bopomofoKeyboardMapping ();
    pinyin_set_zhuyin_scheme (m_chewing_context, scheme);
    /* ... */
}
```

## 配置选项

```c
bool pinyin_set_options(pinyin_context_t * context,
                        pinyin_option_t options);
```

设置配置项，在上个章节提到的设置方案之后调用，把从 gsettings 中读到的配置项内容传入。

## 拼音实例管理

```c
pinyin_instance_t * pinyin_alloc_instance(pinyin_context_t * context);

void pinyin_free_instance(pinyin_instance_t * instance);
```

从上下文创建一个拼音实例，或释放一个实例。在 `LibPinyinBackEnd` 调用来管理拼音实例。

```c
pinyin_context_t * pinyin_get_context (pinyin_instance_t * instance);
```

从拼音实例获取它所属的上下文。

## 获取句子/词组

```c
bool pinyin_guess_sentence(pinyin_instance_t * instance);

bool pinyin_guess_sentence_with_prefix(pinyin_instance_t * instance,
                                       const char * prefix);

bool pinyin_guess_predicted_candidates(pinyin_instance_t * instance,
                                       const char * prefix);

bool pinyin_guess_candidates(pinyin_instance_t * instance,
                             size_t offset,
                             sort_option_t sort_option);
```

分别是从拼音实例猜句子、猜词汇，暂不返回，保存在相关的拼音实例中。然后可以通过 `pinyin_get_sentence` 获取到：

```c
bool pinyin_get_sentence(pinyin_instance_t * instance,
                         guint8 index,
                         char ** sentence);
```

注意，这里的 sentence 需要在用完后手动释放。

## 解析用户输入

```c
bool pinyin_parse_full_pinyin(pinyin_instance_t * instance,
                              const char * onepinyin,
                              ChewingKey * onekey);

size_t pinyin_parse_more_full_pinyins(pinyin_instance_t * instance,
                                      const char * pinyins);

bool pinyin_parse_double_pinyin(pinyin_instance_t * instance,
                                const char * onepinyin,
                                ChewingKey * onekey);

size_t pinyin_parse_more_double_pinyins(pinyin_instance_t * instance,
                                        const char * pinyins);

bool pinyin_parse_chewing(pinyin_instance_t * instance,
                          const char * onechewing,
                          ChewingKey * onekey);

size_t pinyin_parse_more_chewings(pinyin_instance_t * instance,
                                  const char * chewings);
```

解析用户输入

## 其他

```c
bool pinyin_phrase_segment(pinyin_instance_t * instance,
                           const char * sentence);
```

size_t pinyin_get_parsed_input_length(pinyin_instance_t * instance);

bool pinyin_in_chewing_keyboard(pinyin_instance_t * instance,
                                const char key, gchar *** symbols);
