---
title: 云输入在 ibus-libpinyin 中的实现 - 候选词解析
date: 2020-06-05 23:55:00
update: 2020-06-08 09:28:00
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

可以看出，两个源返回的都是 json 字符串。




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

异步模式下，返回的输入流并不一定包含完整的字符串，大部分情况下，当dai

## 通过字符串处理解析候选

对百度源的回复的解析：

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

是一个简易的字符串判断。这个代码在网关正常返回结果的时候可以运行，但网关返回错误信息时就会产生数组越界、非法访问，从而导致输入法崩溃。

对 Google 源的解析也一样：

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

# 20 版解析实现



## 类关系

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

```cpp
class GoogleCloudCandidatesResponseJsonParser : public CloudCandidatesResponseJsonParser
{
protected:
    guint parseJsonResponse (JsonNode *root);

public:
    GoogleCloudCandidatesResponseJsonParser () : CloudCandidatesResponseJsonParser () {}
};
```

```cpp
class BaiduCloudCandidatesResponseJsonParser : public CloudCandidatesResponseJsonParser
{
private:
    guint parseJsonResponse (JsonNode *root);

public:
    BaiduCloudCandidatesResponseJsonParser () : CloudCandidatesResponseJsonParser () {}
    ~BaiduCloudCandidatesResponseJsonParser () { if (m_annotation) g_free ((gpointer)m_annotation); }
};
```

# 两个源返回结果上的差异导致的不一致行为

两个源上返回的内容有不一致的地方，因此个别细节需要单独考虑。

其中比较重要的，也是引发一些其他问题的一个点就是，对用户输入的 echo。

## 用户的输入的 echo

在 20 版异步模式下，可能会有多个请求的回复陆续到达，而它们的顺序是无法保证的。为了解决这个问题，对返回结果对应的用户输入和当前的用户输入进行了比较，如果一致，说明是当前用户输入进行的请求，否则就丢弃这个结果对应的候选。

- Google 源在返回候选词结果时，不仅对候选词进行了拼音标注，还将请求时的用户输入返回；

- 百度源则没有返回请求时发送的用户输入，只有对候选词的拼音标注。

因此，对百度源返回的结果，目前是使用了
