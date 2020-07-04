---
title: 【译】为 Rust 生成 Qt 绑定
date: 2020-07-04 16:51:00
tags:
- Qt
- Rust
- 中文
- 翻译
categories:
- [Translation, Chinese]
- Qt
- Rust
---

原文链接：[https://www.vandenoever.info/blog/2017/09/04/rust_qt_binding_generator.html](https://www.vandenoever.info/blog/2017/09/04/rust_qt_binding_generator.html)

这篇博客文章是 Rust Qt Binding Generator 的发布。该项目正在审核中，之后会加入到 KDE 当中。您可以在[此处](https://invent.kde.org/sdk/rust-qt-binding-generator)获取源代码。

{% asset_img rust_qt_binding_generator.svg Rust Qt Binding Generator (Logo by Alessandro Longo) %}

该代码生成器可帮助在 Qt 和 QML 中快速开始使用 Rust 代码。换句话说，它有助于在 Rust 代码之上创建基于 Qt 的 GUI。

Qt是成熟的跨平台图形用户界面库。而 Rust 是一种新的编程语言，具有强大的编译时检查和现代语法。

# 入门

有两个模板项目可帮助您快速入门。一个用于 Qt Widgets，另一个用于 Qt Quick。只需复制这些文件夹、作为新项目开始编码。

| 文件关系 | |
|---------------------------------------------|--------------|
| **Qt Widgets (main.cpp) / Qt Quick (main.qml)** | ⟵ 写出的 UI 代码 |
| src/Binding.h, src/Binding.cpp, rust/src/interface.rs | ⟵ 从 binding.json 中生成 |
| **rust/src/implementation.rs** | ⟵ 写出的 Rust 代码 |

为了结合 Qt 和 Rust，需要在一个 JSON 文件中编写一个接口。生成器会从这个文件创建 Qt 代码和 Rust 代码。Qt 代码可以直接使用。而 Rust 代码有两个文件：接口和实现。接口可以直接使用。

```json
{
    "cppFile": "src/Binding.cpp",
    "rust": {
        "dir": "rust",
        "interfaceModule": "interface",
        "implementationModule": "implementation"
    },
    "objects": {
        "Greeting": {
            "type": "Object",
            "properties": {
                "message": {
                    "type": "QString",
                    "write": true
                }
            }
        }
    }
}
```

这个文件描述了 Greeting 这个对象的绑定。它有一个可写属性 `message`。

运行这个命令，Rust 的 Qt 绑定生成器会从描述中创建绑定源代码：

```
rust_qt_binding_generator binding.json
```

这个过程会生成下面四个文件：

- src/Binding.h
- src/Binding.cpp
- rust/src/interface.rs
- rust/src/implementation.rs

只需要更改 `Implementation.rs` 即可，其余文件是绑定文件。`Implementation.rs` 是使用一个简单实现创建出的，带有一些注释，文件内容如下：

```rust
use interface::*;

/// A Greeting
pub struct Greeting {
    /// Emit signals to the Qt code.
    emit: GreetingEmitter,
    /// The message of the greeting.
    message: String,
}

/// Implementation of the binding
/// GreetingTrait is defined in interface.rs
impl GreetingTrait for Greeting {
    /// Create a new greeting with default data.
    fn new(emit: GreetingEmitter) -> Greeting {
        Greeting {
            emit: emit,
            message: "Hello World!".into(),
        }
    }
    /// The emitter can emit signals to the Qt code.
    fn emit(&self) -> &GreetingEmitter {
        &self.emit
    }
    /// Get the message of the Greeting
    fn message(&self) -> &str {
        &self.message
    }
    /// Set the message of the Greeting
    fn set_message(&mut self, value: String) {
        self.message = value;
        self.emit.message_changed();
    }
}
```

Qt 和 QML 项目的构建关键是 QObject 和 Model View 类。 `rust_qt_binding_generator` 读取一个 json 文件以生成 QObject 或 QAbstractItemModel 类，这些类会调用生成的 Rust 文件。对于 JSON 文件中的每种类型，都会生成应实现的 Rust Trait。

这样，Rust 代码就可以从 Qt 和 QML 项目中调用了。

## Qt Widgets 与 Rust

这里的 C++ 代码使用了上面编写的 Rust 代码。

```cpp
#include "Binding.h"
#include <QDebug>
int main() {
    Greeting greeting;
    qDebug() << greeting.message();
    return 0;
}
```

## Qt Quick 与 Rust

这里的 Qt Quick（QML） 代码使用了上面编写的 Rust 代码。

```qml
Rectangle {
    Greeting {
        id: rust
    }
    Text {
        text: rust.message
    }
}
```

# 示例程序

该项目带有一个演示应用程序，该应用程序显示了基于 Rust 的 Qt 用户界面。 它使用了对象，列表和树的所有功能。阅读这些演示代码是入门的好方法。

# Dcoekr 开发环境

为了快速上手，该项目附带了一个Dockerfile。执行下面的命令可以启动具有所需依赖项的 Docker 会话：

```
./docker/docker-bash-session.sh
```

# 更多信息

- [Rust Qt Binding Generator](https://cgit.kde.org/rust-qt-binding-generator.git/)
- [Qt](http://doc.qt.io/)
- [Qt 示例与教程](http://doc.qt.io/)
- [The QML Book](http://doc.qt.io/)
