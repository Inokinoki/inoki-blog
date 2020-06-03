---
title: 云输入在 ibus-libpinyin 中的实现 - 概述
date: 2020-05-31 23:55:00
update: 2020-06-03 08:35:00
tags:
- IBus
- ibus-libpinyin
- Cloud Input
categories:
- ibus-libpinyin
---

在 2018 年的 Google Summer of Code (GSoC)中，ibus-libpinyin 的云输入功能由 Linyu Xu 首次引入。该版本并没有被合并入主分支中，本文将其称为 18 版云输入。

18 版采用了同步请求候选词的模式，也就是说，发送请求、解析请求的过程会阻塞 ibus-libpinyin 的行为，在网络情况不好时，就会让人感觉到十分卡顿，出现未响应的现象。同时，由于返回结果解析采用了比较简易的字符串提取，导致取出候选的实现健壮性不高。一系列原因导致 18 版云输入并不能作为一个生产环境可用的功能。

今年（2020）我的 GSoC 项目目标之一就是优化该功能，并将其合并入 ibus-libpinyin 的主分支中。

目前正在迭代的一系列版本在改文中被统称为 20 版云输入，本文将对云输入按照时间顺序进行一个简要介绍，让读者对云输入功能有一个概览。

# 当用户按下键盘

在 ibus-libpinyin 中，用户进行输入之后，编辑器的实例 `PhoneticEditor` 会调用 `updateCandidates` 方法。在该方法中，每一种候选词实例的 `processCandidates` 方法都会被调用，修改候选词列表。

云输入部分的候选词处理由 `PYPCloudCandidates` 中的 `CloudCandidates` 完成。但这时，我们还没有云输入候选的结果，因此需要先插入占位符，方便之后进行替换，从而将云输入返回的结果加入候选词列表中。

# 添加候选词占位符

首先，`CloudCandidates` 会找到指定的位置，从该位置开始插入预先设定个数的候选词占位符。目前使用了一个云的符号☁（在 18 版中为省略号），用来提示用户该位置是一个云输入的候选词，将会被云输入请求返回的候选词取代。

这个位置在 18 版云输入是由 `m_first_cloud_candidate_position` 属性指定的，作为一个整数表示的下标，它给定了一个固定位置来插入、修改占位符。这样可能会在候选词较少时导致用数组下标访问越界的问题。

20 版云输入中，则将其放在 1-3 个整句候选词的后面。并把该位置用一个迭代器记录下来，方便取到候选词之后对占位符进行快速的修改。

在这两个版本的云输入中，`m_cloud_candidates_number` 都用来指定候选词的个数。

一切处理结束后，若拼音长度大于 `m_min_cloud_trigger_length`，即最小的触发云输入请求的拼音长度（18 版中可配置，20 版中由 `CLOUD_MINIMUM_TRIGGER_LENGTH` 宏定义），`CloudCandidates` 会去调用对应的方法来请求云输入的候选，以便之后对占位符进行替换。

## 占位符个数的处理

18 版云输入中，虽然在配置页面有调整占位符个数的配置项，在　gsetting　中也有对应的数据项，但在　`CloudCandidates`　中，仍使用了

```c
m_cloud_candidates_number = 1;
```

将其配制成了一个常值。

在 20 版云输入的改进过程当中，我首先将这个常值改为从配置中读取。在后来的测试中，我发现在百度的云输入源中，无论传入的希望返回候选词的个数是多少（查询字符串中的 ed 字段），它都只返回**一个**候选词；而 Google 源可以返回预期个数的候选词。

{% asset_img baidu.png 向百度源请求多个候选词 %}

为了保持行为的一致性，目前已将其从配置界面中移出，并固定这一配置项的值为1。用户依然可通过 gsetting 对其进行修改。

# 发送请求

在文章开头提到过，18 版云输入使用了同步的机制来请求候选词，这样会阻塞进程；当时的异步请求模式并没有完成。

在 20 版云输入中，异步请求模式有了一个可用的实现，后来，在优化用户体验、减少无用的请求的目标下，我又实现了延时的异步请求，也就是在认为用户完成输入后才发起网络请求获取云输入候选词。

## 同步请求

同步请求模式下，`cloudSyncRequest` 方法会在插入占位符完成后被调用。

该方法使用 `libsoup` 的 API 发送请求，并把结果储存在一个缓冲区中进行解析。结果处理部分在之后的文章中详细解释。

取到候选词之后，它把占位符替换为对应的候选词并返回。

这之后，ibus-libpinyin 才可以响应接下来的其他事件。发送请求是一个耗时操作，也就是这个过程导致同步请求模式下卡顿。异步模式就是为了解决这种无响应状态而生。

## 异步请求

异步请求在 18 版云输入中其实已经有了一个雏形了，即 `cloudAsyncRequest` 方法。

这个方法调用 `soup_session_send_async` 来发送请求，`cloudResponseCallBack` 被作为回调函数参数传入，完成时会被调用来处理结果。

从这里开始，18 版和 20 版开始有实现上的差别。

### 18 版的实现尝试

异步模式下，最后取到的结果是一个输入流，该版本里把这个输入流中的字符全部读出，放到一个缓冲区中：

```cpp
g_input_stream_read (stream, buffer, BUFFERLENGTH, NULL, error);
```

但对于流来说，在该时刻返回的字符并不一定是完整的结果，用这个函数读出来大部分情况下是不完整的字符串，从而导致候选词不能被正常找到并取出。

在 20 版中，由于加入了 JSON 解析的过程，读取流中字符并解析的操作交给了 json-glib 库，它会一直尝试读取流中的字符，直到完成 JSON 字符串的解析，这样取出的结果通常情况下都是完整的，极大的增强了其健壮性。

这里，我们假定返回结果被完整取出了，之后使用相同的结果处理过程，将返回的候选词更新到候选词列表中。

最后，这个方法尝试调用 `cloudCandidates->m_editor->update ()` 来将更新后的候选词刷新到输入法面板上。

```cpp
void
PhoneticEditor::update (void)
{
    guint lookup_cursor = getLookupCursor ();
    pinyin_guess_candidates (m_instance, lookup_cursor,
                             m_config.sortOption ());

    updateLookupTable ();
    updatePreeditText ();
    updateAuxiliaryText ();
}
```

这个方法会重新调用 `updateLookupTable` 方法：

```cpp
void
PhoneticEditor::updateLookupTable (void)
{
    m_lookup_table.clear ();

    updateCandidates ();
    fillLookupTable ();
    if (m_lookup_table.size()) {
        Editor::updateLookupTable (m_lookup_table, TRUE);
    } else {
        hideLookupTable ();
    }
}
```

进而调用 `updateCandidates` 方法：

```cpp
gboolean
PhoneticEditor::updateCandidates (void)
{
    m_candidates.clear ();

    m_libpinyin_candidates.processCandidates (m_candidates);

    if (m_config.emojiCandidate ())
        m_emoji_candidates.processCandidates (m_candidates);
    
#ifdef ENABLE_CLOUD_INPUT_MODE
    if(m_cloud_candidates.m_cloud_state)
        m_cloud_candidates.processCandidates (m_candidates);
#endif
    
    /* ... */

    return TRUE;
}
```

可以看到在这里，所有候选词被清除又重新生成了，也就是说，这一操作并不能正常完成，将云输入的候选词更新到输入法面板的操作。

### 20 版异步请求

在 `cloudResponseCallBack` 获取到返回的结果的输入流之后，`processCloudResponse` 被调用来处理和解析结果，结果会被更新到候选词列表中，替换原来的占位符。这个过程在之后的文章会详细描述。

之后就是将候选更新到输入法面板了，为了避免和 18 版一样的问题，这里我没有再直接调用 `update` 方法，而是选择性的调用一些操作：

```cpp
/* regenerate lookup table */
cloudCandidates->m_editor->m_lookup_table.clear ();
cloudCandidates->m_editor->fillLookupTable ();
cloudCandidates->m_editor->updateLookupTableFast ();
```

1. 清除查询表；
2. 用新的候选词列表重新填充查询表；
3. 快速更新查询表。

这里的过程是否可以简化，还需要进一步的研究和讨论。

### 延时异步

异步请求会在每一次 `processCloudResponse` 时发出一个新的异步请求，在进行长句的输入时，之前发送的请求返回的结果会被丢弃，这造成了大量请求的浪费。为了解决这个问题，进一步的改进加入了延时请求行为。

延时请求使用了 glib 中的 `g_timeout_add_full` 函数，该函数的原型为：

```c
guint
g_timeout_add_full (gint priority,
                    guint interval,
                    GSourceFunc function,
                    gpointer data,
                    GDestroyNotify notify);
```

它的简化版函数原型是：

```c
guint
g_timeout_add (guint interval,
               GSourceFunc function,
               gpointer data);
```

该函数会在 glib 的事件循环中添加一个被周期调用的函数，每隔给定的毫秒数之后，这个函数都会被调用一次，直到这个函数返回 `FALSE`。

间隔的毫秒数由 `interval` 给定，调用的函数是传入的 `function` 参数，而 `data` 变量可以携带任何开发者想传入到 `function` 函数中的用户数据。此外，完整版的函数还允许指定调用的优先级，以便事件循环合理安排调用顺序；并且允许传入一个销毁前的通知，方便开发者进行一些清理工作。

在 20 版的实现中，为了传入足够的数据，我创建了一个结构体来储存一些必要信息：

```cpp
typedef struct
{
    guint thread_id;
    const gchar request_str[MAX_PINYIN_LEN + 1];
    CloudCandidates *cloud_candidates;
} DelayedCloudAsyncRequestCallbackUserData;
```

其中，`thread_id` 是当前的用户数据对应的事件 id，`request_str` 是当前延时希望发出请求所用的拼音，而`cloud_candidates` 则是对云输入候选进行处理的实例的引用，也就是延时的发送者。

在创建延时之前，会首先分配、创建一个 `DelayedCloudAsyncRequestCallbackUserData` 的实例，并把对应的数据填入。

然后，创建延时事件并在当前 `CloudCandidates` 实例中记录其 id：

```cpp
thread_id = m_source_thread_id = g_timeout_add_full(G_PRIORITY_DEFAULT, m_delayed_time, delayedCloudAsyncRequestCallBack, user_data, delayedCloudAsyncRequestDestroyCallBack);
```

函数 `delayedCloudAsyncRequestCallBack` 会在延时结束后被调用，`delayedCloudAsyncRequestDestroyCallBack` 则会在 `delayedCloudAsyncRequestCallBack` 返回 `FALSE`，事件循环决定结束延时事件后被调用。

第二个函数 `delayedCloudAsyncRequestDestroyCallBack` 比较简单，这里先行介绍：

```cpp
void
CloudCandidates::delayedCloudAsyncRequestDestroyCallBack (gpointer user_data)
{
    /* clean up */
    if (user_data)
        g_free (user_data);
}
```

即将之前创建的用户数据所占用的内存释放，避免内存泄漏。

而在 `delayedCloudAsyncRequestCallBack` 中，除了一开始对数据进行检查外，最重要的是这段代码：

```cpp
/* only send with a latest timer */
if (data->thread_id == cloudCandidates->m_source_thread_id)
{
    cloudCandidates->m_source_thread_id = 0;
    cloudCandidates->cloudAsyncRequest(data->request_str);
}
```

首先，对当前用户数据中的事件 id 和 `CloudCandidates` 实例中记录的 id 进行比较，如果一致，说明我们当前事件的确是最近一次发出的延时事件，则调用对应的函数，开始发送异步请求。

最后，无论在哪种情况下，都会返回 `FALSE`，以便让事件循环开始清理，而非继续循环执行该事件。

目前的延时时长为 600ms，也可以在 gsetting 中配置。

# 处理用户选择的候选

除去中间的处理云输入请求返回结果的过程（另起一篇来讲），和用户交互的最后一步就是用户对候选进行选择的过程。

在这一过程中，`CloudCandidates` 实例中的 `selectCandidate` 会被调用，被选中的候选会作为参数传入。

首先对其进行一个判断，确定这个候选词已经是否仍是占位符，若是占位符，则暂时不做出反应。若不是占位符，就进行进一步的处理。

在最新的版本中，传入的候选是带有云输入前缀 ☁ 的，而在 `CloudCandidates` 实例的 `m_candidates` 中缓存了不带有前缀的候选，因此，我们尝试找到对应 id 的候选，将传入的候选修改为无前缀的云输入候选词并返回。这时候选词就会上屏。

```cpp
/* take the cached candidate with the same candidate id */
for (std::vector<EnhancedCandidate>::iterator pos = m_candidates.begin(); pos != m_candidates.end(); ++pos) {
    if (pos->m_candidate_id == enhanced.m_candidate_id) {
        enhanced.m_display_string = pos->m_display_string;
        return SELECT_CANDIDATE_COMMIT;
    }
}
```

在上一版中，`CloudCandidates` 实例的 `m_candidates` 没有被很好的利用。去除云输入前缀 ☁ 的处理是通过迭代器修改传入的候选来完成的。不过也能达到相同的目的。

# 总结

本文按照事件发生的时间顺序粗略描述了云输入功能背后发生了什么，其中中间的一些部分会放在其他的相关文章中详细描述。

而随着版本的迭代，整体流程可能还是会发生一些微小的变化，这篇文章也会跟着更新。
