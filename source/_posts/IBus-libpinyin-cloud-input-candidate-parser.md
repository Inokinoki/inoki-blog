---
title: 云输入在 ibus-libpinyin 中的实现 - 候选词解析
date: 2020-06-05 23:55:00
update: 2020-06-10 16:57:00
tags:
- IBus
- ibus-libpinyin
- Cloud Input
categories:
- ibus-libpinyin
---

上一篇文章粗略地介绍了目前在 ibus-libpinyin 的云输入实现的整个流程，其中对请求返回结果的解析没有提及。这篇文章会重点阐述返回结果的解析是如何实现的，之后的过程，包括在候选列表中更新占位符、错误处理，会在下一篇中详细讲解。

注：同上一篇文章一样，之前的版本称为 18 版云输入，现在的一系列版本称为 20 版。

# 返回结果的示例

目前，云输入功能可选的有 Google 和百度两个源，可能是为了让墙内外的用户都能使用吧。

其中，一个典型的 Google 源返回结果如下：

```json
["SUCCESS",[["ceshi",["测试"],[],{"annotation":["ce shi"],"candidate_type":[0],"lc":["16 16"]}]]]
```

关键的请求参数为：

| 参数名 | 参数值 |
|-------|-------|
| text  | ceshi |
| num   | 1     |

其中 text 是请求的拼音，num 是期望返回的候选个数。

百度源的返回结果及其对应的请求参数是：

```json
{"errmsg":"","errno":"0","result":[[["百度",5,{"pinyin":"bai'du","type":"IMEDICT"}]],"bai'du"],"status":"T"}
```

| 参数名 | 参数值 |
|-------|-------|
| input | baidu |
| ed    | 1     |

这里，input 是请求的拼音，而 ed 是请求的候选词个数。

可以看出，两个源返回的都是 json 字符串，并且格式还算是清晰。接下来就是把候选（比如 Google 源的示例中的“测试”和百度源的示例中的“百度”）解析提取出来的过程。

# 18 版解析实现

18 版的云输入使用了一个非常简易的解析方式：将回复存入字符串，通过截取子串的方式处理字符串来提取候选。在此之前，首先要将回复放入一个字符串中。

## 将回复放入字符串

在 18 版中，无论是同步模式还是异步模式，结果最终都被储存在叫做 `res` 的字符串中。

### 同步

同步模式下，在请求完全结束后，把消息取出并置入 `buffer` 缓冲区，最后放入 `res` 中。

```cpp
SoupMessageBody *msgBody =soup_message_body_new ();
soup_message_body_truncate (msgBody);
msgBody = msg->response_body;
/* clear useless characters */
soup_message_body_flatten(msgBody);
SoupBuffer *bufferBody= soup_message_body_get_chunk(msgBody, 0);

const gchar *buffer= bufferBody->data;
String res;
res.clear ();
res.append (buffer);
```

### 异步

异步模式下，在请求完成后可以获取到回复的输入流。

```cpp
GError **error = NULL;
GInputStream *stream = soup_session_send_finish (SOUP_SESSION(source_object), result, error);
```

然后从输入流中读取字符到 `buffer` 变量中，最后将其放入 `res` 字符串中。

```cpp
gchar buffer[BUFFERLENGTH];
error = NULL;
g_input_stream_read (stream, buffer, BUFFERLENGTH, NULL, error);
CloudCandidates *cloudCandidates = static_cast<CloudCandidates *> (user_data);

String res;
res.clear ();
res.append (buffer);
```

异步模式下，返回的输入流并不一定包含完整的字符串，大部分延迟较高的情况下，当执行到上面代码中的 `g_input_stream_read` 时，流中的内容都不是完整的，从而导致 `res` 中只储存了前几个字符，这会导致下面字符串处理时程序崩溃。

## 通过字符串处理解析候选

对百度源的回复的解析是一个简易的字符串判断与提取：

```cpp
/*BAIDU */
if (res[11]=='T')
{
    if (res[49] !=']')
    {   
        /*respond true , with results*/
        gchar **resultsArr = g_strsplit(res.data()+49, "],", 0);
        guint resultsArrLength = g_strv_length(resultsArr);
        for(int i = 0; i != resultsArrLength-1; ++i)
        {
            int end =strcspn(resultsArr[i], ",");
            std::string tmp = g_strndup(resultsArr[i]+2,end-3);
            cloudCandidates->m_candidates[i].m_display_string = tmp;
        }
    }
}
```

代码中多处出现了硬编码 `res` 数组下标的情况。虽然这里的代码在网关正常返回结果的时候的确可以运行，但网关返回错误信息时、或者异步模式下 `res` 中储存的不是完整的流中的字符串时，就会产生数组越界、非法访问，从而导致输入法崩溃。

对 Google 源的解析也一样是字符串的判断和提取：

```cpp
/*GOOGLE */
const gchar *tmp_res = res;
const gchar *prefix = "[\"SUCCESS\"";
if (g_str_has_prefix (tmp_res, prefix))
{
    gchar **prefix_arr = g_strsplit (tmp_res, "\",[\"", -1);
    gchar *prefix_str = prefix_arr[1];
    gchar **suffix_arr = g_strsplit (prefix_str, "\"],", -1);
    std::string tmp = suffix_arr[0];
    cloudCandidates->m_candidates[0].m_display_string = tmp;
    g_strfreev (prefix_arr);
    g_strfreev (suffix_arr);
}
```

这里的代码没有硬编码的下标，但如果 `res` 中没能取到回复输入流中的所有字符，会导致没有候选的情况出现。

# 20 版解析实现

在 20 版中，为了验证数据，也为了解析这一过程的健壮性，我选择移除 18 版中的字符串判断与提取这一方法，转而使用完整的 json 解析。

其中，考虑到 ibus-libpinyin 整体依赖于 glib，直接使用 `JSON-GLib` 会更加方便，于是添加了它作为一个依赖。

## 类关系

为了可拓展性，参考了导师的意见，我创建了 `CloudCandidatesResponseParser` 类作为所有解析类的基类。

```cpp
class CloudCandidatesResponseParser
{
public:
    CloudCandidatesResponseParser () : m_annotation (NULL) {}
    virtual ~CloudCandidatesResponseParser () {}

    virtual guint parse (GInputStream *stream) = 0;
    virtual guint parse (const gchar *data) = 0;

    virtual std::vector<std::string> &getStringCandidates () { return m_candidates; }
    virtual std::vector<EnhancedCandidate> getCandidates ();
    virtual const gchar *getAnnotation () { return m_annotation; }

protected:
    std::vector<std::string> m_candidates;
    const gchar *m_annotation;
};
```

它包含了两个私有（保护）属性和它们的 getter：

- `m_candidates` 是解析出的候选列表，每个元素是一个字符串；
- `m_annotation` 是解析出的结果中返回的拼音的值。

```cpp
virtual guint parse (GInputStream *stream) = 0;
virtual guint parse (const gchar *data) = 0;
```

这是两个未实现的方法，需要在具体的类中实现，用来负责解析流中或者缓冲区中的数据。

```cpp
class CloudCandidatesResponseJsonParser : public CloudCandidatesResponseParser
{
public:
    CloudCandidatesResponseJsonParser ();
    virtual ~CloudCandidatesResponseJsonParser ();

    guint parse (GInputStream *stream);
    guint parse (const gchar *data);

protected:
    JsonParser *m_parser;

    virtual guint parseJsonResponse (JsonNode *root) = 0;
};
```

接下来，`CloudCandidatesResponseJsonParser` 类继承了 `CloudCandidatesResponseParser` 类，并实现了上述的两个方法。

```cpp
guint CloudCandidatesResponseJsonParser::parse (GInputStream *stream)
{
    GError **error = NULL;

    if (!stream)
        return PARSER_NETWORK_ERROR;

    /* parse Json from input steam */
    if (!json_parser_load_from_stream (m_parser, stream, NULL, error) || error != NULL)
    {
        g_input_stream_close (stream, NULL, error);  // Close stream to release libsoup connexion
        return PARSER_BAD_FORMAT;
    }
    g_input_stream_close (stream, NULL, error);  // Close stream to release libsoup connexion

    return parseJsonResponse (json_parser_get_root (m_parser));
}

guint CloudCandidatesResponseJsonParser::parse (const gchar *data)
{
    GError **error = NULL;

    if (!data)
        return PARSER_NETWORK_ERROR;

    /* parse Json from data */
    if (!json_parser_load_from_data (m_parser, data, strlen (data), error) || error != NULL)
        return PARSER_BAD_FORMAT;

    return parseJsonResponse (json_parser_get_root (m_parser));
}
```

它们都是用一个 `JSON-GLib` 中的 `JsonParser` 示例去解析，并把解析的对象传给 `CloudCandidatesResponseJsonParser` 中定义的 `parseJsonResponse` 来进行具体的处理。

这个方法在当前类中也是未实现的状态，具体的处理行为是和云输入的源有关的，因此，交给下面在 `GoogleCloudCandidatesResponseJsonParser` 和 `BaiduCloudCandidatesResponseJsonParser` 中实现的 `parseJsonResponse` 分别进行 Google 源和百度源返回结果的处理。

```cpp
class GoogleCloudCandidatesResponseJsonParser : public CloudCandidatesResponseJsonParser
{
protected:
    guint parseJsonResponse (JsonNode *root);

public:
    GoogleCloudCandidatesResponseJsonParser () : CloudCandidatesResponseJsonParser () {}
};

class BaiduCloudCandidatesResponseJsonParser : public CloudCandidatesResponseJsonParser
{
private:
    guint parseJsonResponse (JsonNode *root);

public:
    BaiduCloudCandidatesResponseJsonParser () : CloudCandidatesResponseJsonParser () {}
    ~BaiduCloudCandidatesResponseJsonParser () { if (m_annotation) g_free ((gpointer)m_annotation); }
};
```

下面的小节就来描述一下在这两个类中 `parseJsonResponse` 做了什么。

# 候选词提取处理

这一步的目的，是将候选词和拼音解析出来，分别放入 `m_candidates` 列表和 `m_annotation` 中。为了方便理解，下面结合之前提到的两个具体例子来辅助理解。

## Google 源的返回结果处理

```json
["SUCCESS",[["ceshi",["测试"],[],{"annotation":["ce shi"],"candidate_type":[0],"lc":["16 16"]}]]]
```

我们使用最初的那个 Google 源的回复举例，Google 源的处理实现如下，其中的参数 `JsonNode *root` 为 `JSON-GLib` 解析出的一个实例：

```cpp
guint GoogleCloudCandidatesResponseJsonParser::parseJsonResponse (JsonNode *root)
{
    if (!JSON_NODE_HOLDS_ARRAY (root))
        return PARSER_BAD_FORMAT;
```

首先先检查格式，最外层应当是一个数组，若格式有问题，就返回一个 `PARSER_BAD_FORMAT` 的状态。

```cpp
/* validate Google source and the structure of response */
JsonArray *google_root_array = json_node_get_array (root);

const gchar *google_response_status;
JsonArray *google_response_array;
JsonArray *google_result_array;
const gchar *google_candidate_annotation;
JsonArray *google_candidate_array;
guint result_counter;

if (json_array_get_length (google_root_array) <= 1)
    return PARSER_INVALID_DATA;
```

紧接着获取到这个数组实例，并准备一些变量方便之后对元素的描述。

然后检测数组的大小是否至少为2，以免之后获取元素时出现越界。若元素数量符合期待，紧接着就可以做进一步的元素取出。否则返回一个 `PARSER_INVALID_DATA` 状态。

```cpp
google_response_status = json_array_get_string_element (google_root_array, 0);

if (g_strcmp0 (google_response_status, "SUCCESS"))
    return PARSER_INVALID_DATA;

google_response_array = json_array_get_array_element (google_root_array, 1);

if (json_array_get_length (google_response_array) < 1)
    return PARSER_INVALID_DATA;

google_result_array = json_array_get_array_element (google_response_array, 0);
```

紧接着，取出数组中的元素：

1. 第一个元素（下标为0），应当是一个字符串，描述这次请求是否是成功的，若不成功，则返回一个 `PARSER_INVALID_DATA` 状态。
2. 第二个元素是接下来要处理的 `google_response_array` 这个数组结构，长度至少为1，对应的 json 部分为：

```json
[["ceshi",["测试"],[],{"annotation":["ce shi"],"candidate_type":[0],"lc":["16 16"]}]]
```

然后进一步的取到它的内层数组 `google_result_array`，从这里开始，就有了真正需要的数据。

```cpp
    google_candidate_annotation = json_array_get_string_element (google_result_array, 0);

    if (!google_candidate_annotation)
        return PARSER_INVALID_DATA;

    /* update annotation with the returned annotation */
    m_annotation = google_candidate_annotation;
```

第一个取出的是 `google_result_array` 的第一个元素，这个元素应当是一个字符串，表示的是用户的输入，在上述例子中为 `"ceshi"` 这个元素。并把它存到当前实例的 `m_annotation` 属性中。

```cpp
    google_candidate_array = json_array_get_array_element (google_result_array, 1);

    result_counter = json_array_get_length (google_candidate_array);

    if (result_counter < 1)
        return PARSER_NO_CANDIDATE;

    for (guint i = 0; i < result_counter; ++i)
    {
        std::string candidate = json_array_get_string_element (google_candidate_array, i);
        m_candidates.push_back (candidate);
    }

    return PARSER_NOERR;
}
```

第二个取出的是 `google_result_array` 的第二个元素，是一个包含了候选词的数组，取名为 `google_candidate_array`。

先判断它的长度，若不包含任何元素，则返回 `PARSER_NO_CANDIDATE` 状态。

有元素的话就把所有元素取出，添加到 `m_candidates` 这个属性对应的候选词列表中。然后返回 `PARSER_NOERR` 状态。

## 百度源的返回结果处理

```json
{"errmsg":"","errno":"0","result":[[["百度",5,{"pinyin":"bai'du","type":"IMEDICT"}]],"bai'du"],"status":"T"}
```

同样的，对于百度，我们也使用最初的例子，其中的参数 `JsonNode *root` 也是 `JSON-GLib` 解析出的一个实例：

```cpp
guint BaiduCloudCandidatesResponseJsonParser::parseJsonResponse (JsonNode *root)
{
    if (!JSON_NODE_HOLDS_OBJECT (root))
        return PARSER_BAD_FORMAT;
```

先检查格式，最外层应当是一个对应，在格式不匹配的情况下就返回一个 `PARSER_BAD_FORMAT` 的状态。

```cpp
/* validate Baidu source and the structure of response */
JsonObject *baidu_root_object = json_node_get_object (root);
const gchar *baidu_response_status;
JsonArray *baidu_result_array;
JsonArray *baidu_candidate_array;
const gchar *baidu_candidate_annotation;
guint result_counter;
```

类似但却不同的，这里是获取到这个 json 对象的实例，并创建一系列变量用来接收之后的元素。

```cpp
if (!json_object_has_member (baidu_root_object, "status"))
    return PARSER_INVALID_DATA;

baidu_response_status = json_object_get_string_member (baidu_root_object, "status");

if (g_strcmp0 (baidu_response_status, "T"))
    return PARSER_INVALID_DATA;
```

首先先看 `status` 元素存在且是否为 `T`，如果不存在或者为其他值，这次请求的应当已经是失败的了，就不需要进行下一步的操作，直接返回 `PARSER_INVALID_DATA` 状态。

```cpp
if (!json_object_has_member (baidu_root_object, "result"))
    return PARSER_INVALID_DATA;

baidu_result_array = json_object_get_array_member (baidu_root_object, "result");

baidu_candidate_array = json_array_get_array_element (baidu_result_array, 0);
```

然后则是对 `result` 元素存在性的检测，这个元素是存放有结果的一个数组。这个数组的第一个元素是存放有候选词信息的数组，将其取出，用 `baidu_candidate_array` 指向它。这是之后取候选词时主要要操作的对象。

```cpp
baidu_candidate_annotation = json_array_get_string_element (baidu_result_array, 1);

if (!baidu_candidate_annotation)
    return PARSER_INVALID_DATA;

/* update annotation with the returned annotation */
m_annotation = NULL;
gchar **words = g_strsplit (baidu_candidate_annotation, "'", -1);
m_annotation = g_strjoinv ("", words);
g_strfreev (words);
```

第二个元素则是返回回来的匹配到的拼音，它是一个字符串，这个表示拼音的字符串使用了单引号 `'` 作为分割，而我们所希望的是一个没有分隔符的连续的拼音串（方便与当前编辑器中的用户输入），因此需要对其进行分割与合并的处理。

进行处理后，存放在 `m_annotation` 中。由于是通过 `g_strjoinv` 创建出来的，这个字符串是需要手动释放的。于是，在上面展示的 `BaiduCloudCandidatesResponseJsonParser` 类的析构函数中完成了这一释放过程：

```cpp
~BaiduCloudCandidatesResponseJsonParser () { if (m_annotation) g_free ((gpointer)m_annotation); }
```

处理完了拼音，接下来就可以拿起之前取出的 `baidu_candidate_array` 候选词数组了。整体流程和 Google 源的十分相似，唯一不同的是更内层的处理。

```cpp
    result_counter = json_array_get_length (baidu_candidate_array);

    if (result_counter < 1)
        return PARSER_NO_CANDIDATE;
```

首先是看候选数组的长度，判断有无可用的候选词。

而数组内的每一个候选词，都有以下结构：

```json
["百度",5,{"pinyin":"bai'du","type":"IMEDICT"}]
```

第一个元素是候选词的字符串，紧跟着的应当是候选在 UTF-8 编码情况下的长度，之后是这个候选对应，包含拼音和类型的一个 json 对象。

```cpp
    for (guint i = 0; i < result_counter; ++i)
    {
        std::string candidate;
        JsonArray *baidu_candidate = json_array_get_array_element (baidu_candidate_array, i);

        if (json_array_get_length (baidu_candidate) < 1)
            candidate = CANDIDATE_INVALID_DATA_TEXT;
        else
            candidate = json_array_get_string_element (baidu_candidate, 0);

        m_candidates.push_back (candidate);
    }

    return PARSER_NOERR;
}
```

这里我们只取候选数组里的第一个元素，也就是候选词的字符串，并将其加入到 `m_candidates` 候选数组中。如果没有这个元素，就添加一个 `CANDIDATE_INVALID_DATA_TEXT` 作为提示。

最后，返回 `PARSER_NOERR`。

# 两个源返回结果上的差异

两个源上返回的内容有不一致的地方，因此个别细节需要单独考虑。

其中比较重要的，也是引发一些其他问题的一个点就是，对用户输入的 echo。

在 20 版异步模式下，可能会有多个请求的回复陆续到达，而它们的顺序是无法保证的。为了解决这个问题，对返回结果对应的用户输入和当前的用户输入进行了比较，如果一致，说明是当前用户输入进行的请求，否则就丢弃这个结果对应的候选。

- Google 源在返回候选词结果时，不仅对候选词进行了拼音标注，还将请求时的用户输入返回；
- 百度源则没有返回请求时发送的原始的用户输入，有对候选词的拼音标注，和自动补全拼音后的用户输入。

因此，对百度源返回的结果，目前无法找回原始的用户输入，也就无法和当前编辑器中的用户输入进行成功匹配。在输入拼音不完全的时候会有候选词被丢弃的情况出现。

对此，有以下几种方案：

1. 导师提出了在有不完整拼音（模糊拼音）的情况下不给百度源发送请求；
2. 写一个字符串相似程度的算法，为百度源的返回结果设定一个相似度阈值，达到阈值之后就允许显示；
3. 无论是否匹配，在百度源的情况下都允许显示。

具体采用哪一种比较好，还需要进一步的讨论。目前采用的是第三种方案。

# 总结

这篇文章讲述了对从请求的回复中提取候选的过程，提取出候选后，会根据状态处理提取出来的候选，这部分会在下篇文章叙述。最后交由在 [云输入在 ibus-libpinyin 中的实现 - 概述 ](/2020/05/31/IBus-libpinyin-cloud-input-global-view/) 一文中描述的过程，更新替换候选词的占位符，完成整个云输入的过程。
