---
title: 【译】我的 C++ 20 协程的予取予求
date: 2021-12-16 15:34:00
tags:
- C++
- 翻译
- 中文
categories:
- [Modern C++]
---

原文链接：[https://www.scs.stanford.edu/~dm/blog/c++-coroutines.html](https://www.scs.stanford.edu/~dm/blog/c++-coroutines.html)

# 介绍

在过去的 25 年里，我在 C++ 中写了很多事件驱动的代码。一个典型的事件驱动代码的例子是注册一个回调，每次套接字有数据需要读取时都会被调用。一旦你读取了整个消息，可能经过多次调用，你就会解析消息，并从更高的抽象层调用另一个回调，如此反复。这种代码写起来很痛苦，因为你必须把你的代码分成一堆不同的函数，因为它们是不同的函数，所以不共享局部变量。

作为一个例子，这里是 Mail Avenger 的 smtpd 类上的方法子集，我的 SMTP 服务器是用 C++03 编写的：

```c
void cmd_rcpt (str cmd, str arg);
void cmd_rcpt_0 (str cmd, str arg, int, in_addr *, int);
void cmd_rcpt_2 (str addr, int err);
void cmd_rcpt_3 (str addr, str errmsg);
void cmd_rcpt_4 (str addr, str errmsg, int local);
void cmd_rcpt_5 (str addr, str errmsg, str err);
void cmd_rcpt_6 (str addr, str err);
```

第1步，cmd_rcpt 似乎是一个合理的函数，在客户端发出 SMTP "RCPT" 命令时调用。处理 RCPT 命令取决于对客户的某些信息的缓存。如果这些信息没有被缓存，它就会启动一个异步任务来探测客户端并返回。异步任务完成后，"回到" 第 0 步，cmd_rcpt_0，它只是再次调用 cmd_rcpt，但需要一个不同的函数，因为客户端探测代码期望一个回调，它可以提供额外的参数。然后，各种其他的事情可能需要异步发生，而每个可能的异步调用的返回点都需要是它自己的方法，这相当恶心。

C++11 通过引入 lambda 表达式，使情况大为改善。现在你只需要类上的一个 cmd_rcpt 方法，其余的可以使用嵌套的 lambda 表达式。更好的是，lambdas 可以从包围的函数中捕获局部变量。尽管如此，你仍然需要把你的代码分成许多函数。跳过多个步骤或支持在运行时发出异步事件的顺序可能改变的情况是很笨拙的。最后，当你的嵌套 lambda 表达式缩进得越来越远时，你常常会与文本编辑器的右侧边距作斗争。

看到 C++20 支持协程，我感到非常兴奋，这应该会极大地改善编写事件驱动代码的过程。现在终于有人出版了一本关于 C++20 的书（或者至少是一本书的草稿），几天前我迫不及待地拿到了一本，并阅读了它。虽然我发现这本书在概念（语言特性）和其他 C++20 的改进方面做得很合理，但我悲哀地发现对协程的解释完全无法理解。我在网上找到的几乎所有其他解释都是如此。因此，我不得不通过规范和 cppreference.org 来弄清楚到底发生了什么。

这篇博文代表了我解释协程的尝试--基本上是我希望在 48 小时之前，当我只想弄清楚这些东西的时候，我就需要有的一个教程。

# 教程

粗略地说，coroutines 是可以互相调用的函数，但它们不共享堆栈，所以可以在任何时候灵活地暂停执行，进入一个不同的 coroutine。本着真正的 C++ 精神，C++20 的 coroutines 被实现为一个漂亮的小块，埋藏在一堆垃圾之下，你必须涉足其中才能获得漂亮的部分。坦率地说，我对这种设计感到失望，因为最近的其他语言变化做得更有品味，但可惜它们不是 coroutines。进一步混淆 coroutines 的事实是，C++ 标准库实际上并没有提供你访问 coroutines 所需的脏活，所以你实际上必须完成你自己的脏活，然后越过它。总之，我尽量把任何进一步的编辑工作留到这篇博文的最后。

另一个需要注意的复杂情况是，C++ 的程序经常使用术语 future 和 promise 来解释，甚至指定。这些术语与 C++ <future> 头中的 std::future 和 std::promise 类型毫无关系。具体来说，std::promise 不是 coroutine promise 对象的一个有效类型。在我的博文中，除了这一段之外，没有任何内容与 std::future 或 std::promise 有关。

说完了这些，C++20 给我们提供的好东西是一个新的操作符，叫做 co_await。粗略地说，表达式 "co_await a;"做了以下工作。

1. 确保当前函数--必须是一个协程--中的所有局部变量被保存到一个堆分配的对象中。
2. 创建一个可调用的对象，当它被调用时，将在紧随 co_await 表达式的评估之后恢复执行该循环程序。
3. 调用（或者更准确地说是跳转到）co_await 的目标对象 a 的一个方法，将步骤 2 中的可调用对象传递给该方法。

注意第 3 步中的方法，当它返回时，并不把控制权返回到 coroutine。只有当第2步的可调用对象被调用时，该循环程序才会恢复执行。如果你使用了一种支持当前继续的调用的语言，或者玩过 Haskell Cont monad，那么第2步的可调用对象就有点像一个 continuation。

## 使用协程编译代码

由于 C++20 还没有被编译器完全支持，你需要确保你的编译器实现了 coroutines 来玩它们。我使用的是 GCC 10.2，只要你用下面的标志来编译，它似乎就支持 coroutines。

```
g++ -fcoroutines -std=c++20
```

Clang 的支持就没那么深入了。你需要安装 llvm libc++，然后用以下方式编译。

```
clang++ -std=c++20 -stdlib=libc++ -fcoroutines-ts
```

不幸的是，在 clang 中，你还需要将 coroutine 头文件作为 `<experimental/coroutine>` 而不是 `<coroutine>`。此外，一些类型被命名为 std::experimental::xxx 而不是 std::xxx。因此，在写这篇文章的时候，下面的例子不能用 clang 开箱编译，但最好能在未来的版本中编译。

如果你想玩一玩，本博文中所有的演示都可以在一个文件 [corodemo.cc](https://www.scs.stanford.edu/~dm/blog/corodemo.cc) 中找到。

## 协程处理

如前所述，新的 co_await 操作符确保函数的当前状态被捆绑在堆的某个地方，并创建一个可调用对象，其调用会继续执行当前函数。可调用对象的类型是 std::coroutine_handle<>。

Coroutine 句柄的行为很像 C 语言的指针。它可以很容易地被复制，但它没有一个析构器来释放与轮询状态相关的内存。为了避免泄漏内存，你通常必须通过调用 coroutine_handle::destroy 方法来销毁 coroutine 状态（尽管在某些情况下，coroutine 可以在完成时自我销毁）。就像C语言的指针一样，一旦 coroutine 句柄被销毁，引用同一 coroutine 的 coroutine 句柄将指向垃圾，并在调用时表现出未定义的行为。从好的方面看，协程句柄在协程的整个执行过程中都是有效的，即使控制在协程中多次进出。

现在让我们更具体地看看 co_await 做什么。当你评估表达式 co_await a 时，编译器会创建一个循环程序句柄并将其传递给方法 a.await_suspend(coroutine_handle)。

现在让我们来看看一个使用 co_await 的完整程序。现在，忽略 ReturnObject 类型--它只是我们为访问 co_await 而必须通过的垃圾中的一部分。

```cpp
#include <concepts>
#include <coroutine>
#include <exception>
#include <iostream>

struct ReturnObject {
  struct promise_type {
    ReturnObject get_return_object() { return {}; }
    std::suspend_never initial_suspend() { return {}; }
    std::suspend_never final_suspend() noexcept { return {}; }
    void unhandled_exception() {}
  };
};

struct Awaiter {
  std::coroutine_handle<> *hp_;
  constexpr bool await_ready() const noexcept { return false; }
  void await_suspend(std::coroutine_handle<> h) { *hp_ = h; }
  constexpr void await_resume() const noexcept {}
};

ReturnObject
counter(std::coroutine_handle<> *continuation_out)
{
  Awaiter a{continuation_out};
  for (unsigned i = 0;; ++i) {
    co_await a;
    std::cout << "counter: " << i << std::endl;
  }
}

void
main1()
{
  std::coroutine_handle<> h;
  counter(&h);
  for (int i = 0; i < 3; ++i) {
    std::cout << "In main1 function\n";
    h();
  }
  h.destroy();
}
```

**Output**:

    In main1 function
    counter: 0
    In main1 function
    counter: 1
    In main1 function
    counter: 2

这里的 counter 是一个永远计数的函数，递增并打印一个无符号整数。尽管这个计算很愚蠢，但这个例子的精彩之处在于，即使控制权在 counter 和调用它的函数 main1 之间反复切换，变量 i 仍然保持其值。

在这个例子中，我们用一个std::coroutine_handle<>*来调用counter，我们把它插入我们的Awaiter类型。在其 await_suspend 方法中，该类型将 co_await 产生的 coroutine 句柄存入 main1 的 coroutine 句柄中。每次 main1 调用 coroutine 句柄时，都会触发 counter 中的循环的一次迭代，然后在 co_await 语句处再次暂停执行。

为了简单起见，我们在每次调用 await_suspend 时都会存储该程序的句柄，但该句柄在不同的调用中不会改变。(回顾一下，句柄就像一个指向 coroutine 状态的指针，所以虽然i的值在这个状态下可能会改变，但指针本身保持不变。) 我们也可以很容易地写成：

```cpp
void
Awaiter::await_suspend(std::coroutine_handle<> h)
{
  if (hp_) {
    *hp_ = h;
    hp_ = nullptr;
  }
}
```

你会注意到 Awaiter 上还有两个方法，因为这些是语言所要求的。如果它返回 true，那么 co_await 就不会中止该函数。当然，你可以在 await_suspend 中实现同样的效果，通过恢复（或不暂停）当前的 coroutine，但在调用 await_suspend 之前，编译器必须将所有状态捆绑到 coroutine 句柄所引用的堆对象中，这可能是昂贵的。最后，这里的 await_resume 方法返回 void，但如果它返回一个值，这个值将是 co_await 表达式的值。

`<coroutine>` 头提供了两个预定义的 Awaiter，std:: suspend_always和std:: suspend_never。正如它们的名字所暗示的，suspend_always::await_ready 总是返回 false，而 suspend_never::await_ready 总是返回  true。这些类上的其他方法是空的，什么也不做。

## 协程返回对象

TBC

## Promise 对象

TBC

## co_yield 操作符

TBC

## co_return 操作符

TBC

## 带泛型的生成器示例

TBC

# Editorial

TBC
