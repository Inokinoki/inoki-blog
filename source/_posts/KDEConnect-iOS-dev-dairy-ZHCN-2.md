---
title: KDE Connect iOS 开发日记(2) 识别协议
date: 2020-04-19 15:34:50
tags:
- KDE Connect
- 中文
- 翻译
categories:
- KDE Connect
- [Translation, Chinese]
---

在上一篇文章中，KDE Connect iOS 的构建已修复，可以将应用程序安装到设备或模拟器中。

要与其他设备连接，我们需要与它们配对。但是，在此之前，设备需要使用 KDE Connect 识别机制相互发现。

# 识别过程

初始身份验证过程非常简单，如下所示:

{% asset_img KDEConnectIdentityWithoutSSL.png Identity Process without TLS/SSL %}

1.首先，设备 A 将发送一个 UDP 广播数据包，其中包含其身份数据包；
2.每个接收到 UDP 广播的设备 B 都会尝试提取数据包中的 TCP 端口信息，并尝试通过该端口与设备连接；
3.通过 TCP 连接，每个设备 B 都会向设备 A 发送自己的标识数据包；
4.然后，设备会将链接项添加到发现的设备列表中，并等待用户的操作。

# 升级识别网络包

第一次尝试，除了 iOS 设备，我所有的设备都可以找到彼此。

在调试模式下，我看到发现消息和相关的输出：

```
"Inoki" uses an old protocol version, this won't work
```

因此，我使用 Wireshark 捕获数据包，以了解为什么 KDE Connect iOS 中的旧实现无法正常工作。

区别在于数据包内容和定制数据。

## 识别网络包内容

所有的网络包都是通过序列化 `NetWorkPackage` 类来实现的，这个类在 `lib/NetworkPackage.h` 和 `lib/NetworkPackage.m` 文件中被定义。

类中包含的属性有:

```objective-c
@property(nonatomic) NSString* _Id;
@property(nonatomic) NSString *_Type;
@property(nonatomic) NSMutableDictionary *_Body;
@property(nonatomic) NSData *_Payload;
@property(nonatomic) NSDictionary *_PayloadTransferInfo;
@property(nonatomic)long _PayloadSize;
```

序列化之后，内容将是 JSON 格式的字符串。例如，来自 KDE Connect iOS 的数据包内容为：

```json
{
    "id":"1587284674",
    "type":"kdeconnect.identity",
    "body":{
        "deviceId":"test-kdeconnect-ios",
        "SupportedOutgoingInterfaces":"kdeconnect.ping,kdeconnect.mpris,kdeconnect.share,kdeconnect.clipboard,kdeconnect.mousepad,kdeconnect.battery,kdeconnect.calendar,kdeconnect.reminder,kdeconnect.contact",
        "protocolVersion":5,
        "tcpPort":1714,
        "deviceType":"Phone",
        "deviceName":"Inoki",
        "SupportedIncomingInterfaces":"kdeconnect.calendar,kdeconnect.clipboard,kdeconnect.ping,kdeconnect.reminder,kdeconnect.share,kdeconnect.contact"
    }
}
```

来自 KDE Connect 的其他平台的内容是：

```json
{
    "id":1587284383,
    "type":"kdeconnect.identity",
    "body":{
        "deviceId":"9985DA4FDD3449C78ACC8597D2C5A782",
        "protocolVersion":7,
        "tcpPort":1716,
        "deviceType":"phone",
        "deviceName":"Inoki",
        "incomingCapabilities":[
            "kdeconnect.calendar","kdeconnect.clipboard","kdeconnect.ping","kdeconnect.reminder","kdeconnect.share","kdeconnect.contact"
        ],
        "outgoingCapabilities":[
            "kdeconnect.ping","kdeconnect.mpris","kdeconnect.share","kdeconnect.clipboard","kdeconnect.mousepad","kdeconnect.battery","kdeconnect.calendar","kdeconnect.reminder","kdeconnect.contact"
        ]
    }
}
```

### 修复 id 字段的类型

我们可以看到第一个区别是关于 `id` 字段。在 KDE Connect iOS 数据包中，它是一个字符串。但是在较新版本的协议中，它是一个整数。

因此我将其类型从 `NSString` 改为 `NSNumber`:

```objective-c
@property(nonatomic) NSNumber *_Id;
@property(nonatomic) NSString *_Type;
@property(nonatomic) NSMutableDictionary *_Body;
@property(nonatomic) NSData *_Payload;
@property(nonatomic) NSDictionary *_PayloadTransferInfo;
@property(nonatomic)long _PayloadSize;
```

### 更新支持的功能类型

另一个重大更改是功能描述的类型和名称：

- 它们之前分别是 `SupportedOutgoingInterfaces` 和 `SupportedIncomingInterfaces`，字符串类型；
- 在最新版本中，它们是 `incomingCapabilities` 和 `outgoingCapabilities`，数组类型。

在 KDE Connect iOS 中，它是由 `lib/NetworkPackage.m` 中的以下代码生成的：

```objective-c
[np setObject:[[[PluginFactory sharedInstance] getSupportedIncomingInterfaces] componentsJoinedByString:@","] forKey:@"SupportedIncomingInterfaces"];
[np setObject:[[[PluginFactory sharedInstance] getSupportedOutgoingInterfaces] componentsJoinedByString:@"," ] forKey:@"SupportedOutgoingInterfaces"];
```

显然，返回的值是数组，但是它们由逗号字符串连接形成一个字符串。因此，我只是更改了键名，并删除了 `componentsJoinedByString` 方法：

```objective-c
[np setObject:[[PluginFactory sharedInstance] getSupportedIncomingInterfaces] forKey:@"incomingCapabilities"];
[np setObject:[[PluginFactory sharedInstance] getSupportedOutgoingInterfaces] forKey:@"outgoingCapabilities"];
```

### 更新协议版本

协议版本字段在头文件中定义：

```objective-c
#define ProtocolVersion         5
```

我将其升级为 7 来匹配现版本。

## 身份数据包定制数据

在 Wireshark 数据包中 KDE Connect iOS 的身份数据包的定制数据为 `\x0D\x0A`。来自其他 KDE Connect 版本的是 `\x0A`。

因此，我更改了 `lib/NetworkPackage.m` 中的代码：

```git
- #define LFDATA [NSData dataWithBytes:"\x0D\x0A" length:2]
+ #define LFDATA [NSData dataWithBytes:"\x0A" length:1]
```

# 结论

最终，KDE Connect iOS 可以找到其他设备并建立与它们的连接：

{% asset_img discovery.jpg Discovery %}

相反，其他人还找不到 KDE Connect iOS 客户端。这是因为新版本在 TCP 连接后需要 TLS / SSL。这将在下一篇文章中解决。

祝我好运！
