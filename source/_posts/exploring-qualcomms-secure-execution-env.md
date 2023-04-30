---
title: 【译】探索高通的安全执行环境
date: 2023-04-30 13:20:00
tags:
- Android
- ABL
- Linux
- Bootloader
- 中文
categories:
- [Linux, Android]
---

在[本博客](http://bits-please.blogspot.com/2016/04/exploring-qualcomms-secure-execution.html)中，我们将再次深入探讨 TrustZone 的世界，并探索一系列新的漏洞和相应的利用程序，这些漏洞和利用程序将使我们能够从零权限提升特权，以在 TrustZone 内核中执行代码。

对于那些阅读过之前系列的人来说，这可能听起来很熟悉 - 但是让我向您保证;这个系列将会更加令人兴奋！

首先，这个漏洞链具有通用性，适用于所有 Android 版本和手机（而且不需要任何权限），并且一个影响广泛的 TrustZone 漏洞。其次，我们将深入探讨一个尚未被探索的操作系统 - QSEE - 高通的安全执行环境。最后，我们将看到一些有趣的 TrustZone 有效载荷，例如直接从 TrustZone 的加密文件系统中提取真实指纹。

如果您想跟随符号和反汇编二进制文件进行学习，我将在整个系列中使用我的Nexus 6，其指纹如下：

google/shamu/shamu:5.1.1/LMY48M/2167285:user/release-keys

您可以在[此处](https://dl.google.com/dl/android/aosp/shamu-lmy48m-factory-336efdae.tgz)找到确切的出厂镜像。

# 噢，QSEE 能否说得上安全？

在这篇博客文章中，我们将探索高通的安全执行环境 QSEE。

正如我们之前讨论的那样，设备上包含 TrustZone 的主要原因之一是提供“可信执行环境”(TEE)——一个理论上可以允许计算而不会被常规操作系统干扰的环境，因此是“可信的”。

这是通过创建一个仅在由 TrustZone 提供的“安全世界”中运行的小型操作系统来实现的。这个操作系统直接提供一些系统调用形式的少量服务，这些调用被 TrustZone 内核(TZBSP)本身处理。然而，为了允许可扩展的模型，其中可以添加“可信”的功能，TrustZone 内核还可以安全地加载和执行称为“Trustlet”的小程序，这些程序旨在为不安全的(“正常世界”)操作系统(在我们的情况下是 Android)提供安全服务。

![](https://4.bp.blogspot.com/--8-qxTK4nkQ/Vx5qgfd0MUI/AAAAAAAADlQ/JPi8hKxl0YI17w1vKfX0t-e4yuRTofwRACLcB/s1600/Screenshot%2Bfrom%2B2016-04-25%2B22%253A05%253A26.png)

这些 Trustlet 在设备上通常会被广泛使用：

- keymaster：实现了由 Android 密钥库守护程序提供的密钥管理 API。它可以安全地生成和存储加密密钥，并允许用户使用这些密钥对数据进行操作。
- widevine：实现了 Widevine DRM，允许在设备上安全播放媒体。

实际上，根据 OEM 和设备的不同，可能会有更多与 DRM 相关的 Trustlet，但这两个 Trustlet 被广泛使用。

# 我们从哪里开始？

自然而然的，我们可以选择一个 Trustlet 来开始，尝试理解其工作原理。由于 widevine 模块是最普遍的之一，我们将重点关注它。

简要搜索设备固件中的 widevine Trustlet，可以发现以下内容：

![](https://4.bp.blogspot.com/-K-p4I-gLUm0/Vw-p2N5S4cI/AAAAAAAADiU/AAIWhjl0DZEQPmlO7Wcetm4ewud6GoDygCLcB/s1600/Screenshot%2Bfrom%2B2016-04-14%2B17%253A31%253A36.png)

显然，Trustlet 被分成了几个不同的文件...打开这些文件会看到一堆混乱的东西——有些文件包含看起来像是代码的内容，而其他文件包含 ELF 头和元数据。无论如何，在我们开始反汇编 Trustlet 之前，我们需要从这种格式中理出一些意义。我们可以通过打开每个文件并猜测每个 Blob 的含义，或者通过跟踪负责加载 Trustlet 的代码路径来实现。让我们试试两种方法。

# 加载 Trustlet

为了从"正常世界"中加载 Trustlet，应用程序可以使用 `libQSEECom.so` 共享对象，该对象导出函数 `QSEECom_start_app`:

![](https://4.bp.blogspot.com/-2M0MBoxXx0s/Vw_i5H1ubYI/AAAAAAAADis/0mjja9u7fLUoSTDCqv-AQF_MqC0fNt1lQCLcB/s1600/Screenshot%2Bfrom%2B2016-04-14%2B21%253A35%253A02.png)

很不幸，这个库的源代码不可用，因此我们需要反向工程实现函数以找出它的作用。这样做会发现它执行以下操作：

- 打开 `/dev/qseecom` 设备并调用一些 `ioctl` 命令进行配置。
- 打开与信任应用程序相关的 `.mdt` 文件并从中读取前 `0x34` 字节。
- 使用 `.mdt` 的 `0x34` 字节计算 `.bXX` 文件的数量。
- 分配一个物理连续的缓冲区（使用"ion"）并将 `.mdt` 和 `.bXX` 文件复制到其中。
- 最后，使用分配的缓冲区调用 `ioctl` 来加载信任应用程序本身。

所以，仍然没有找到镜像加载的确切方法，但我们正在接近目标。

首先，数字 `0x34` 可能看起来很熟悉——这是 ELF 头的大小（32 位）。打开 MDT 文件后发现，前 `0x34` 字节确实是有效的 ELF 头：

![](https://2.bp.blogspot.com/-q5ISujqlZJQ/Vw_xqodDwHI/AAAAAAAADjE/5UsNb3fRqHYcpwww3yoU6D00zVhwPzPdQCLcB/s280/Screenshot%2Bfrom%2B2016-04-14%2B22%253A38%253A03.png)

此外，我们刚刚查看的 `QSEECOM_start_app` 函数使用偏移量 `0x2C` 处的 WORD 来计算 `.bXX` 文件的数量。正如您在上面看到的那样，这对应于 ELF 标头中的 `e_phnum` 字段。

由于 `e_phnum` 字段通常用于指定程序头的数量，这表明每个 `.bXX` 文件可能包含要加载的程序的单个段。实际上，打开每个文件都会显示出内容，看起来可能是正在加载的程序的段……但是为了确保，我们需要找到程序头本身（并查看它们是否与 `.bXX` 文件匹配）。

进一步查看，`.mdt` 文件中的下几个块实际上是程序头本身，每个头文件对应一个存在的 `.bXX` 文件。

![](https://3.bp.blogspot.com/-kCbanj5qnNI/VxoYC9hWc_I/AAAAAAAADkU/gwOYLG--NhgkHg0eo_F0ytxTkHulrBUfQCLcB/s1600/Screenshot%2Bfrom%2B2016-04-22%2B15%253A24%253A28.png)

而且，确认了我们之前的怀疑，它们的大小恰好与 `.bXX` 文件的大小匹配。太好了！

请注意，上面的前两个程序头看起来有点奇怪 - 它们都是空类型的头，意味着它们是“保留”的，不应加载到结果 ELF 映像中。奇怪的是，打开相应的 `.bXX` 文件会发现，第一个块包含与 `.mdt` 中相同的 ELF 头和程序头，第二个块包含其余的 `.mdt` 文件。

无论如何，这是一个简短的示意图，总结了我们目前所知道的内容：

![](https://3.bp.blogspot.com/-ng-lbPKtFqs/Vx6N8HqOBNI/AAAAAAAADmk/I-JQCN-w6i4vW1RoAyi7UR6PdD50PL08gCLcB/s280/Screenshot%2Bfrom%2B2016-04-26%2B00%253A36%253A37.png)

此外，请注意由于 ELF 头文件和程序头文件都在 `.mdt` 中，因此我们可以使用 `readelf` 快速转储有关信任执行环境的程序头信息。

![](https://1.bp.blogspot.com/-xz-y61aweD8/VxoYvWqHxjI/AAAAAAAADkc/KMID90TBNsQkEEDTFC0Yz315VFbkqeUfgCLcB/s1600/Screenshot%2Bfrom%2B2016-04-22%2B15%253A26%253A11.png)

在这一点上，我们已经拥有了从 `.mdt` 和 `.bXX` 文件创建完整有效的 ELF 文件所需的所有信息；我们拥有 ELF 头和程序头，以及每个段本身。我们只需要编写一个小脚本，使用这些数据创建一个 ELF 文件。

我编写了一个小的 Python 脚本，正是这样做的。您可以在[此处](https://github.com/laginimaineb/unify_trustlet)找到它：

# 信任 Trustlets 的思考

对 Trustlet 的信任过程，我们现在已经有了基本的了解，但我们仍然不知道它们是如何进行验证的。然而，由于我们知道 `.bXX` 文件仅包含要加载的段，这意味着这些数据必须驻留在 `.mdt` 文件中。

因此，现在是猜测的时间——如果我们要构建一个可信的加载程序，我们将如何做？

一个非常常见的范式是使用哈希和签名（依赖于 CRHF 和数字签名）。基本上——我们计算要进行身份验证的数据的哈希值，并使用对于加载器已知其对应的公共密钥的私有密钥进行签名。

如果情况是这样的，我们应该在 `.mdt` 中找到以下两个内容：

- 证书链
- 签名数据块

让我们从查找证书链开始。证书有太多的格式，但由于 `.mdt` 文件仅包含二进制数据，我们可以假设它可能是一个二进制格式，其中最常见的是 DER 格式。

我们可以使用一种快速的 hack 方法来查找 DER 编码的证书——它们几乎总是以 `ASN.1 SEQUENCE` 块开头，编码为：`0x30 0x82`。所以让我们在 `.mdt` 中搜索这两个字节，并将每个找到的块保存到一个文件中。现在，我们可以使用 `openssl` 检查这些块是否为格式良好的证书：


![](https://1.bp.blogspot.com/-sDFBSQziyeU/Vx55nxH0evI/AAAAAAAADlk/T2rZKFv5qAY9nt8xoPBugmZA5qU4RnT4ACLcB/s1600/Screenshot%2Bfrom%2B2016-04-25%2B23%253A08%253A18.png)

是的，我们猜对了--那些是证书。

事实上，该信任小程序包含三个证书，一个接一个。为了稳妥起见，我们可能还想检查一下这三个证书实际上是一个证书链，形成了一个有效的信任链。我们可以通过把证书转储到一个单一的"证书链"文件中，并使用  `openssl` 来验证使用这个证书链的每个证书来做到这一点：

![](https://1.bp.blogspot.com/-6EU5u0TlGNQ/Vx59xMP3d-I/AAAAAAAADl0/LuQKalEin2Uf51FbXHwM40NZ7hGCzFVIgCLcB/s1600/Screenshot%2Bfrom%2B2016-04-25%2B23%253A27%253A38.png)

至于这个链的信任根--看一下链中的根证书就会发现，这个根证书与高通公司安全启动过程中用于验证启动链的所有其他部分的根证书相同。对这一机制进行了一些研究，结果表明，验证是通过比较根证书的 SHA256 和一个名为 `OEM_PK_HASH` 的特殊值进行的，该值在生产过程中被"融合"到设备的 QFuse 中。由于这个值在设备生产后理论上不应该被修改，这意味着伪造这样的根证书基本上需要对 SHA256 进行第二次预镜像攻击。

现在，让我们回到 `.mdt`--我们已经找到了证书链，所以现在是时候寻找签名了。通常情况下，私钥是用来产生签名的，而公钥可以用来恢复签名数据。由于我们有证书链中最顶端的证书的公钥，我们可以用它来查看文件，并适时地尝试"恢复"每个 blob。

但我们怎么知道我们是否成功了呢？

回想一下，RSA 是一个陷阱门排列族--每一个具有与公共模数 N 相同位数的 blob 都被映射到另一个相同大小的 blob。

然而，虽然在我们的例子中，RSA 的公共模数是 2048 位，但大多数哈希值都比这短得多（SHA1 为 160 位，SHA256 为 256 位）。这意味着，如果我们试图用我们的公钥"解密"一个 blob，而它恰好以大量的"松弛"空间结束（例如，0 字节），有一个非常好的机会，这是我们正在寻找的签名（对于一个完全随机的排列组合，连续 n 个零位的机会是 2^-n - 即使是一个中等的 n，也非常小）。

为了做到这一点，我写了一个小程序，从链中最顶端的证书中加载公钥，并尝试"恢复" `.mdt` 中的每个 blob（使用带有 `PKCS #1 v1.5` 填充的 `rsa_public_decrypt`）。如果 "恢复的" blob 以一堆 0 字节结尾，程序就会输出它。所以......在我们的 `.mdt` 上运行它：

![](https://4.bp.blogspot.com/-cInoo8hdisg/Vx6FDn10xMI/AAAAAAAADmI/nfEtOGDr3d4O6jjAURpJUPi4t9PMxHfYwCLcB/s1600/Screenshot%2Bfrom%2B2016-04-25%2B23%253A58%253A43.png)

我们已经找到了一个签名! 太好了。

更重要的是，这个签名有 256 比特长，这意味着它可能是一个 SHA256 哈希值...... 如果 `.mdt` 里有一个 SHA256，也许还有更多？

![](https://2.bp.blogspot.com/-krFw0Ds87PM/Vx6gn52cZwI/AAAAAAAADnM/bcXuiNpiPk4fIFF5LZUeAXso9maJpi5XQCLcB/s1600/hashes.png)

再一次的幸运!

我们可以看到，每个 `.bXX` 文件的 SHA256 哈希值也连续存储在 `.mdt` 中。我们也可以做一个有根据的猜测，这将是被签名的数据（或至少是部分数据），以产生我们之前发现的签名。

注意，`.b01` 文件的哈希值不见了--这是为什么？记住，`.b01` 文件包含了 `.mdt` 中除 ELF 头和程序头以外的所有数据。由于这些数据也包含上面的签名，而签名（可能）是通过块文件的哈希值产生的，这将导致循环依赖（因为改变块文件将改变哈希值，这将改变签名，这将再次改变块文件，等等）。因此，这个区块的哈希值不存在是有道理的。

现在我们实际上已经解码了 `.mdt` 文件中的所有数据，除了一个位于程序头之后的小结构。然而，在看了一会儿之后，我们可以看到它只是包含了我们已经解码的 `.mdt` 中各个部分的指针和长度：

![](https://4.bp.blogspot.com/-1Q5f2Bdlqek/Vx6fnRC2-JI/AAAAAAAADnA/aiz2tmb2f2IhCXGLPvbN9VeUNhBsbsD8QCLcB/s1600/Screenshot%2Bfrom%2B2016-04-26%2B01%253A51%253A37.png)

所以最后，我们已经解码了 `.mdt` 中的所有信息...... 

![](https://4.bp.blogspot.com/-F25AwpsXJ4w/Vx6gAZPr5nI/AAAAAAAADnE/JjZ_H5OGObA-mCsB9l-_myEE6C2UtkcvwCLcB/s280/Screenshot%2Bfrom%2B2016-04-26%2B01%253A53%253A44.png)

# 摩托罗拉的高保障启动

尽管我们在上面看到的 `.mdt` 文件格式对所有的 OEM 来说都是通用的，但摩托罗拉决定增加一个小插曲。

他们没有像我们之前看到的那样提供一个 RSA 签名，而是实际上将签名 blob 留空（事实上，我之前给你看的签名是来自 Nexus 5）。事实上，摩托罗拉的签名看起来像这样：

![](https://1.bp.blogspot.com/-e4OtA8tpg-8/Vx6iL72LYuI/AAAAAAAADnc/5SJpBjFerDA2VlMYwxuwfvoxIpltOF1hwCLcB/s1600/Screenshot%2Bfrom%2B2016-04-26%2B02%253A03%253A02.png)

那么，图像是如何被验证的呢？

这是通过使用摩托罗拉称之为 HAB（"高保障启动"）的机制来完成的。这个机制允许他们通过在文件末尾附加一个证书链和整个 `.mdt` 的签名来验证 `.mdt` 文件，并使用 HAB 使用的专有格式进行编码：

![](https://1.bp.blogspot.com/-9zGaac0jPhc/Vx8cXryW4XI/AAAAAAAADn4/H4kTTh6xyMUKObt9uEWO7Wlk4Z8J6atLwCLcB/s1600/Screenshot%2Bfrom%2B2016-04-26%2B10%253A44%253A16.png)

关于这一机制的更多信息，你可以查看 Tal Aloni 的这项研究。简而言之，`.mdt` 使用证书链中最顶端的密钥进行散列和签名，而证书链中的根证书则使用 "超级根密钥 "进行验证，该密钥是在引导程序的某个阶段硬编码的。
 
# Trustlet 的生命周期

在我们上面看到的验证过程之后，TrustZone 内核将 Trustlet 的片段加载到"正常世界"无法访问的安全内存区域（`secapp-region`），并给它分配了一个 ID。

然后，内核切换到"安全世界"的用户模式，执行 Trustlet 的入口函数：

![](https://2.bp.blogspot.com/-ZjZwBYYkgwM/Vx9GZMOCgII/AAAAAAAADok/vMI6_Xjy1JAr8UGY3TpvS0eylnEk1PC8QCLcB/s1600/Screenshot%2Bfrom%2B2016-04-26%2B13%253A43%253A38.png)

正如你所看到的，Trustlet 向 TrustZone 内核注册了自己，同时还有一个"处理函数"。在注册完  Trustlet 后，控制权被返回到 TrustZone 内核，加载过程结束了。

现在，一旦 Trustlet 被加载，"正常世界"可以通过发出一个特殊的 SCM 调用（称为  `QSEOS_CLIENT_SEND_DATA_COMMAND`）向 Trustlet 发送命令，其中包含加载 Trustlet 的 ID 以及请求和响应缓冲区。下面是它的样子：

![](https://1.bp.blogspot.com/-bQG0yqPbGe8/Vx9J-HZKjSI/AAAAAAAADow/XrU2FHfdiAUggbxdNZU9B1L-0PvEK77NQCLcB/s1600/Screenshot%2Bfrom%2B2016-04-26%2B13%253A58%253A50.png)

TrustZone 内核（TZBSP）收到 SCM 调用，将其映射到 QSEOS，然后找到具有给定 ID 的应用程序，并调用先前注册的处理函数（来自"安全世界"用户模式），以便为请求服务。

![](https://2.bp.blogspot.com/-QyQkLeGzno0/Vx9MyXz_C4I/AAAAAAAADpA/XohkYcl4K7cCtPwenb7_UFNRG0DdRSgogCLcB/s280/Screenshot%2Bfrom%2B2016-04-26%2B14%253A10%253A52.png)

# 下一步是什么？

现在我们对什么是 Trustlet 以及它们是如何加载有了一些了解，我们可以继续进行攻击了！在下一篇博文中，我们将发现一个非常流行的 Trustlet 中的漏洞，并利用它在 QSEE 中执行代码。
