---
title: 云输入在 ibus-libpinyin 中的实现 - 配置项
date: 2020-07-16 20:20:00
tags:
- IBus
- ibus-libpinyin
- Cloud Input
categories:
- ibus-libpinyin
---

前几篇文章描述了云输入请求的全过程。其中，和云输入有关的参数（比如：需要请求几个云输入结果，延时发送请求需要延时多久等）是由 `GLib` 中的 `GSettings` 模块负责储存与读取的。

大多数情况下，这个模块都可以通过读取项目中的配置描述文件，生成对应的配置项（实际上，也可以通过命令行创建、读取、修改配置项，这里不做累述）。

# 配置描述文件

`GSettings` 通过读取一个以 `.gschema.xml` 结尾、XML 格式的配置描述文件生成对应配置项。一个典型的配置描述文件如下：

```xml
<?xml version="1.0" encoding="utf-8"?>
<schemalist>

  <schema path="/org/example/myapp/" id="org.example.myapp">

    <key name='automatic-updates' type='b'>
      <default>true</default>
      <summary>Automatically install updates</summary>
      <description>
        If enabled, updates will automatically be downloaded and installed.
        If disabled, updates will still be downloaded, but the user will be
        asked to install them manually.
      </description>
    </key>

  </schema>

</schemalist>
```

每个 `<schema>` 标签对应一个应用程序；每个 `<key>` 对应一个配置项，`name` 属性指定了配置项的名称，`type` 属性指定了值的类型，示例中的 `automatic-updates` 属性为一个布尔值，默认值为 `true`。

创建好一个配置项描述文件了之后，在 `Makefile.am` 中将文件名传给 `gsettings_SCHEMAS`，`GLib` 中 automake 相关的操作会进行之后的操作。比如，在 ibus-libpinyin 中的 `data/Makefile.am` 这一行就声明了项目中的配置描述文件：

```Makefile
gsettings_SCHEMAS = com.github.libpinyin.ibus-libpinyin.gschema.xml
```

在这个文件中，声明了两个“应用程序”的配置项，因为实际上 `ibus-libpinyin` 包含了一个拼音输入法 `libpinyin` 和一个注音输入法 `libbopomofo`。

```xml
<schema path="/com/github/libpinyin/ibus-libpinyin/libpinyin/" id="com.github.libpinyin.ibus-libpinyin.libpinyin"></schema>

<schema path="/com/github/libpinyin/ibus-libpinyin/libbopomofo/" id="com.github.libpinyin.ibus-libpinyin.libbopomofo"></schema>
```

# 云输入相关配置项

在这两组配置项中，与云输入有关的配置项如下：

```xml
<key name="enable-cloud-input" type="b">
    <default>false</default>
    <summary>Enable Cloud Input</summary>
</key>
<key name="cloud-input-source" type="i">
    <default>0</default>
    <summary>Cloud Input Source</summary>
</key>
<key name="cloud-candidates-number" type="i">
    <default>1</default>
    <summary>Cloud Candidates Number</summary>
</key>
<key name="cloud-request-delay-time" type="i">
    <default>600</default>
    <summary>Sending Cloud request with delay</summary>
</key>
```

其中，`enable-cloud-input` 为是否启用云输入，`cloud-input-source` 为云输入源的选择，`cloud-candidates-number` 是期望返回的云输入候选个数，`cloud-request-delay-time` 是延时发送云输入请求的时间，单位为毫秒。

现在版本中的配置项是从 18 版精简之后的，精简之前的配置项更加繁琐，如图所示：

{% asset_img old-configuration.png 旧配置项 %}

# 配置界面

现在出现在配置页面中的配置项只有两个了，于是将之前 18 版中单独的配置页面移除，配置项放入 pinyin 配置页中：

{% asset_img new-configuration.png 新配置项 %}

在这个配置页面中，仅有云输入的启用和云输入源的选择可用。

延时发送云输入请求的时间一般情况下不会有人修改，目前的值先设为 600ms，上线后收集用户的反馈，根据情况进行修改。另外，用户也可以通过 GSettings 的命令行接口对这个值进行修改。而期望返回的云输入候选个数，由于前文所说的“百度云输入源无论何时都只返回一个候选”，目前默认定为1。

配置的 GUI 界面是 `setup/ibus-libpinyin-preferences.ui` 文件描述的，在 `setup/main2.py` 代码中由 Gtk 的 Python 绑定负责实例化和事件处理。

关于配置部分的整体架构如图：

{% asset_img settings.png 配置读取架构 %}

- 配置界面 GUI 和 Python 程序可以读取或修改 GSettings 中的配置值。
- `ibus-libpinyin` 中的 `libpinyin` 或 `libbopomofo` 的各个模块可以读取到配置值。
- 通过 GSettings 命令行工具也可以直接修改对应的值。

# ibus-libpinyin 主程序中的云输入配置项

`PYConfig` 文件中声明了 `Config` 类，以及与配置相关的一系列值。比如与云输入相关的 `CloudInputSource` 云输入源：

```cpp
enum CloudInputSource{
    BAIDU = 0,
    GOOGLE
};
```

在 `Config` 类中储存了与云输入配置项有关的保护变量及其读取函数：

```cpp
gboolean enableCloudInput (void) const      { return m_enable_cloud_input; }
guint cloudInputSource (void) const         { return m_cloud_input_source; }
guint cloudCandidatesNumber (void) const    { return m_cloud_candidates_number; }
guint cloudRequestDelayTime (void) const    { return m_cloud_request_delay_time; }

gboolean m_enable_cloud_input;
guint m_cloud_input_source;
guint m_cloud_candidates_number;
guint m_cloud_request_delay_time;
```

正如之前配置读取架构描述的那样，这里的数据流应当是单向的，因此不应当有从此处更改配置值的操作。

读取配置时需要用到配置项名字，对应的是 `.gschema.xml` 中的 `key` 标签的 `name` 属性值，在 `ibus-libpinyin` 中声明成一系列常量：

```cpp
const gchar * const CONFIG_INIT_ENABLE_CLOUD_INPUT   = "enable-cloud-input";
const gchar * const CONFIG_CLOUD_INPUT_SOURCE        = "cloud-input-source";
const gchar * const CONFIG_CLOUD_CANDIDATES_NUMBER   = "cloud-candidates-number";
const gchar * const CONFIG_CLOUD_REQUEST_DELAY_TIME  = "cloud-request-delay-time";
```

在这个类中，可以通过下面的方法读取一个属性值：

```cpp
m_enable_cloud_input = read (CONFIG_INIT_ENABLE_CLOUD_INPUT, false);
```

读取过后，还有对值的合法性的一系列检查，如果超过了限制，会置为默认值，并显示一个警告。

```cpp
m_cloud_candidates_number = read (CONFIG_CLOUD_CANDIDATES_NUMBER, 1);
if (m_cloud_candidates_number > 10 || m_cloud_candidates_number < 1) {
    m_cloud_candidates_number = 1;
    g_warn_if_reached ();
}
m_cloud_input_source = read (CONFIG_CLOUD_INPUT_SOURCE, 0);
if (m_cloud_input_source != BAIDU &&
    m_cloud_input_source != GOOGLE) {
    m_cloud_input_source = BAIDU;
    g_warn_if_reached ();
}
m_cloud_request_delay_time = read (CONFIG_CLOUD_REQUEST_DELAY_TIME, 600);
if (m_cloud_request_delay_time > 2000 || m_cloud_request_delay_time < 200) {
    m_cloud_request_delay_time = 600;
    g_warn_if_reached ();
}
```

在构造函数中，初始化过默认值之后，会将 `valueChangedCallback` 函数注册为 `changed` 信号的回调。

```cpp
initDefaultValues ();
g_signal_connect (m_settings,
                    "changed",
                    G_CALLBACK (valueChangedCallback),
                    this);
```

如果值发生了变化，这个函数会被调用，然后对应的配置值会被更新。

# 云输入中获取配置的实现

目前，云输入的配置仅仅在 `CloudCandidates` 构造函数中读取：

```cpp
m_cloud_source = m_editor->m_config.cloudInputSource ();
m_delayed_time = m_editor->m_config.cloudRequestDelayTime ();
m_cloud_candidates_number = m_editor->m_config.cloudCandidatesNumber ();
```

之后的过程都直接使用 `CloudCandidates` 内暂存的配置值。

这样造成的问题是，用户在更改了配置之后，值更改的事件会被触发，`Config` 和它的子类中的值会更新为新值；但 `CloudCandidates` 中仍为旧值，只有在切换到其他输入法，再切换回来，`CloudCandidates` 的构造函数才会再次被调用，新的配置值才会更新到这个新的 `CloudCandidates` 实例。

优化的其中一项方法是将暂存的值取消，每次使用时直接从 `Config` 的实例读取，这样能保证一直是最新的值。

# 总结

这篇文章粗略介绍了使用 GLib 的 GSettings 实现应用程序配置的过程，以及具体的在 `ibus-libpinyin` 中的实现。
