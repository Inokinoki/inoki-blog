---
title: 云输入在 ibus-libpinyin 中的实现 - 状态与错误处理
date: 2020-06-15 16:33:00
tags:
- IBus
- ibus-libpinyin
- Cloud Input
categories:
- ibus-libpinyin
---

上一篇文章描述了云输入部分发出请求，接收到回复之后对回复的验证、处理，以及对返回的候选词的提取。在取得候选之后，会将其加入到 parser 中的 `m_candidates` 列表中，并返回一个状态；若没有取得候选或者在验证过程中发现了问题，也会返回一个指出问题的错误状态。

这篇文章接着这个流程，叙述在代码中是如何对这些状态或错误进行一系列处理的。除此之外，在发送请求前和发送请求时也有相应的状态，这篇文章的最后也会对这个过程进行描述。

由于之前的版本并没有状态与错误处理的流程，因此在这篇文章中不再对 18 和 20 版进行区分，只描述最新版本中的做法。

# 状态指示字符串

在处理过程中，会使用一系列字符串被更新到候选列表中，用来替代最初的占位符，告诉用户云输入候选处理当前的状态：

```cpp
static const std::string CANDIDATE_CLOUD_PREFIX = "☁";

static const std::string CANDIDATE_PENDING_TEXT = CANDIDATE_CLOUD_PREFIX;
static const std::string CANDIDATE_LOADING_TEXT = CANDIDATE_CLOUD_PREFIX + "...";
static const std::string CANDIDATE_NO_CANDIDATE_TEXT = CANDIDATE_CLOUD_PREFIX + "[No Candidate]";
static const std::string CANDIDATE_INVALID_DATA_TEXT = CANDIDATE_CLOUD_PREFIX + "[Invalid Data]";
static const std::string CANDIDATE_BAD_FORMAT_TEXT = CANDIDATE_CLOUD_PREFIX + "[Bad Format]";
```

这些字符串带有一个 "☁" 的前缀，后面则是对应的状态字符串。

- `CANDIDATE_PENDING_TEXT` 用来指示请求还未发送；
- `CANDIDATE_LOADING_TEXT` 在请求已发送，但未收到有效回复时显示。

其他三个则是用来显示处理请求的回复时的错误状态。

# 处理回复时可能的错误/状态

在 `CloudCandidates.cpp` 中，定义了一系列可能的错误或状态：

```cpp
enum CandidateResponseParserError {
    PARSER_NOERR,
    PARSER_INVALID_DATA,
    PARSER_BAD_FORMAT,
    PARSER_NO_CANDIDATE,
    PARSER_NETWORK_ERROR,
    PARSER_UNKNOWN
};
```

其中 `PARSER_NOERR` 是没有发现处理过程中存在问题。

`PARSER_INVALID_DATA` 和 `PARSER_BAD_FORMAT` 是指在验证过程中发现返回的结构不同、或者返回的结果无效。

如果到最后，发现云输入源没有返回任何候选，那么就用 `PARSER_NO_CANDIDATE` 通知上层。

以上几个错误或状态都在上篇文章[《云输入在 ibus-libpinyin 中的实现 - 候选词解析》](/2020/06/05/IBus-libpinyin-cloud-input-candidate-parser/)中出现过。

而 `PARSER_NETWORK_ERROR` 比较特殊，它仅仅用在取得的回复的输入流/缓冲区无效时，它仅仅在 `CloudCandidatesResponseJsonParser` 被返回：

```cpp
guint CloudCandidatesResponseJsonParser::parse (GInputStream *stream)
{
    /* ... */
    if (!stream)
        return PARSER_NETWORK_ERROR;
    /* ... */
}
```

如果输入流或者缓冲区的读取没有问题，就交给具体实现的 `parseJsonResponse` 去解析，并返回它传回的错误（无错误则返回 `PARSER_NOERR`）。

最后一个 `PARSER_UNKNOWN` 仅作保留，没有使用。

# 错误/状态的处理

处理收到的回复时，是由 `CloudCandidates` 中的 `processCloudResponse` 方法来调用具体的 Parser 实现的 parse 方法的，返回的错误也就储存在 `processCloudResponse` 方法的 `ret_code` 变量中：

```cpp
ret_code = parser->parse (stream);
```

接下来会先对处理过程中一个重要的流程——如何替换候选列表中的云输入占位符，进行描述。然后是对各个错误类型的处理。

## 替换占位符、更新候选的方法

在处理时，很重要的一个操作是找到之前插入的云输入占位符的位置，以便更新占位符处的文本。

### 使用迭代器记录

最近的版本中，在插入占位符时，`m_cloud_candidates_first_pos` 和 `m_candidates_end_pos` 记录下来的了云输入占位符的开始位置和结束位置。这里的  `m_cloud_candidates_first_pos` 指向整句候选之后的第一个位置，而 `m_candidates_end_pos` 指向它之后第 N 个位置，其中 N 为配置的云输入候选词个数。

在进行更新占位符时，使用下面的循环即可，之后的章节中不再累述：

```cpp
for (std::vector<EnhancedCandidate>::iterator pos = m_cloud_candidates_first_pos; pos != m_candidates_end_pos; ++pos) {
    /* ... */
}
```

这种方法的确能提高更新速度，因为它减少了每次从头查找的多余操作。但有一个问题是，如果云输入插入占位符并记录下来之后，其他候选处理过程又添加了新的候选，这时这两个迭代器的指向可能就不对了。

比如，在云输入进行 `processCandidates` 之后， Lua 脚本候选又在相同位置（整句候选之后的第一个位置）进行了添加和处理，这时 `m_cloud_candidates_first_pos` 的指向实际上是 Lua 脚本候选词，于是在更新过程中，它（们）就会被云输入的候选覆盖掉。

我采用的解决方案是，将云输入的候选处理放到最后。

### 使用下标记录

而之前的版本是使用一个固定开始下标和固定的占位符个数来记录，这种记录方法可能会导致程序在特定情况下崩溃。比如，固定的开始下标为2时，假如只有一个匹配的候选，使用2这个下标访问候选词列表，就会发生越界的问题。

## 处理 PARSER_NETWORK_ERROR

首先进行处理的是最特殊的错误状态，即网络出错时。

```cpp
pos->m_display_string = CANDIDATE_INVALID_DATA_TEXT;
```

在输入或者缓冲区不可用时，会把所有的占位符都修改为显示最开始提到的一系列状态指示字符串中的 `CANDIDATE_INVALID_DATA_TEXT`。

## 处理 PARSER_NETWORK_ERROR 之后

如果没有发生网络错误，说明至少回复是被处理了的。考虑到异步请求无法保证先后顺序，在进行接下来的其他判断时，我们希望确定在处理的的确是最近一次请求的。也就是说，只有在这个判断确认是最近一次的请求时，才进一步判断之后的小节里描述的其他状态。

我的方法是判断 parser 中获取到的拼音是否与当前编辑器中的一致：

```cpp
else if (!g_strcmp0 (annotation, text) || !g_strcmp0 (annotation, double_pinyin_text))
{
    /* ... */
}
```

在上一篇中的章节 [两个源返回结果上的差异](/2020/06/05/IBus-libpinyin-cloud-input-candidate-parser/#两个源返回结果上的差异) 中，有提到从百度源解析出的拼音是进行了自动补全的，这种情况下就会导致这里的判断结果为假，从而导致结果被丢弃。

目前采用的方案是，对百度源不进行这一判断。因此，在新版本中这个条件添加了当前使用的是否是百度源的判断。

## 处理 PARSER_NOERR

这是无错误的情况。

```cpp
if (ret_code == PARSER_NOERR)
{
    /* update to the candidates list */
    std::vector<std::string> &updated_candidates = parser->getStringCandidates ();
```

首先，将获取到的储存在 parser 中的候选取出。

```cpp
    std::vector<EnhancedCandidate>::iterator pos = m_cloud_candidates_first_pos;
    std::vector<EnhancedCandidate>::iterator cached_candidate_pos = m_candidates.begin();
```

找到候选词列表中占位符的初始位置，获取在 `CloudCandidates` 缓存的占位符的迭代器。

```cpp
    for (guint i = 0; cached_candidate_pos != m_candidates.end() && pos != m_candidates_end_pos && i < updated_candidates.size ();
        ++i, ++pos, ++cached_candidate_pos)
    {
        /* display candidate with prefix in lookup table */
        EnhancedCandidate & enhanced = *pos;
        enhanced.m_candidate_id = i;
        enhanced.m_display_string = CANDIDATE_CLOUD_PREFIX + updated_candidates[i];

        /* cache candidate without prefix in m_candidates */
        EnhancedCandidate & cached = *cached_candidate_pos;
        cached.m_display_string = updated_candidates[i];
        cached.m_candidate_id = enhanced.m_candidate_id;
    }
}
```

紧接着对每个候选词列表中的占位符进行更新，将其修改为 `"☁"` + 候选词，同时将缓存的占位符修改为不带 `"☁"` 的候选词，并同步对应的候选在候选词列表中的 id。这样，当用户选择一个候选时，只需要遍历缓存在 `CloudCandidates` 中的候选，将传入的候选（为用户选中的）修改为缓存的对应的不带有 `"☁"` 的项并返回。

在之前的版本中，缓存的占位符没有被很好的使用，当用户选择时，会去遍历传入的选中的候选的字符内容，如果找到 `"☁"` 标记，则将其移除并返回。

新的实现更好一些，能够物尽其用，将缓存的候选最大程度利用上。

详细的用户选择后的操作在《云输入在 ibus-libpinyin 中的实现 - 概述》 [处理用户选择的候选](/2020/05/31/IBus-libpinyin-cloud-input-global-view/#处理用户选择的候选) 一章。

## 处理 PARSER_NO_CANDIDATE

这种情况是指结构正确、解析过程中没有出现问题，但没有解析出候选。

```cpp
pos->m_display_string = CANDIDATE_NO_CANDIDATE_TEXT;
```

我认为这应当是一个出现了错误的状态，而不是说是单纯的没有候选。因此，这里把所有的占位符都修改为状态指示字符串中的 `CANDIDATE_NO_CANDIDATE_TEXT`。

## 处理 PARSER_INVALID_DATA

这种情况告诉用户，请求时返回的数据无效。

```cpp
pos->m_display_string = CANDIDATE_INVALID_DATA_TEXT;
```

类似的，把所有的占位符都修改为状态指示字符串中的 `CANDIDATE_INVALID_DATA_TEXT`。

## 处理 PARSER_BAD_FORMAT

在处理时发现数据的格式有问题，就会返回这种错误状态，这种情况可能在输入流或缓冲区不完整时出现。比如这里的读取流并进行 Json 解析时：

```cpp
/* parse Json from input steam */
if (!json_parser_load_from_stream (m_parser, stream, NULL, error) || error != NULL)
{
    g_input_stream_close (stream, NULL, error);  /* Close stream to release libsoup connexion */
    return PARSER_BAD_FORMAT;
}
```

同样，这里把所有的占位符都修改为状态指示字符串中的 `CANDIDATE_BAD_FORMAT_TEXT`。

```cpp
pos->m_display_string = CANDIDATE_BAD_FORMAT_TEXT;
```

# 不同阶段下的状态

除了上述的对收到的回复的解析时的错误或状态的处理，在此之前，还有对延时请求和等待回复两个状态。这两个状态可以简化在出现错误时对错误的定位。

## 延迟请求状态

在候选词列表插入占位符时，占位符的初始显示为 `CANDIDATE_PENDING_TEXT`。插入占位符之后，即进入延期等待状态。

## 等待回复状态

在延时等待结束之后，`cloudAsyncRequest` 方法会被调用用来发送请求。

```cpp
void
CloudCandidates::cloudAsyncRequest (const gchar* requestStr)
{
    /* ... */
    SoupMessage *msg = soup_message_new ("GET", queryRequest);
    soup_session_send_async (m_session, msg, NULL, cloudResponseCallBack, static_cast<gpointer> (this));
    m_message = msg;

    /* update loading text to replace pending text */
    for (std::vector<EnhancedCandidate>::iterator pos = m_cloud_candidates_first_pos; pos != m_candidates_end_pos; ++pos) {
        if (CANDIDATE_CLOUD_INPUT == pos->m_candidate_type) {
            if (CANDIDATE_PENDING_TEXT == pos->m_display_string) {
                pos->m_display_string = CANDIDATE_LOADING_TEXT;
            }
        } else
            break;
    }
    /* ... */
}
```

在这个方法中，请求发送完成之后，会将占位符更新为 `CANDIDATE_LOADING_TEXT`。

# 总结

这篇文章讲述了云输入的不同阶段下对状态的处理，以及解析请求的回复之后、对解析成功与否的状态和错误的处理。

它们都将特定的字符串更新到了候选词列表中，但这个列表是存在在 ibus-libpinyin 中的，真正显示在用户眼前，则是通过 ibus-libpinyin 通知 ibus 有新的候选列表完成的。这一过程在《云输入在 ibus-libpinyin 中的实现 - 概述》[20-版异步请求](/2020/05/31/IBus-libpinyin-cloud-input-global-view/#20-版异步请求)中有相关解释。

下一篇文章会重点讨论一下与云输入有关的配置项。到这里，云输入的整体流程应当已经比较清楚了，我还会继续跟着开发过程更新这几篇文章中相关的内容。

不出意外，在云输入合并之后，下一步就是实现双拼形码相关的功能了。
