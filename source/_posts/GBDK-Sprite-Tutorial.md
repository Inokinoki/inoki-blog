---
title: GBDK Sprite 精灵
date: 2015-09-19 21:41:23
tags:
- GBDK
- 中文
categories:
- GBDK
---

原文链接：[https://gbdev.gg8.se/wiki/articles/GBDK_Sprite_Tutorial](https://gbdev.gg8.se/wiki/articles/GBDK_Sprite_Tutorial)

# 介绍

本教程旨在介绍一种工作流程，能够显示多个精灵和设置动画。为了使它尽可能地易于访问，我假设您不了解 C 语言。如果您不想在开始之前的几个小时内浏览参考文件，这就是为您准备的。

# 工具

您将需要：GBDK，文本编辑器，Game Boy Tile Designer 和仿真器（建议使用 BGB，它有许多调试功能）以及任何水平的 C 知识。

如果需要，请替换您喜欢的工具，但是本教程假定您具有上面列出的工具。

# 第一步：创建瓦块

运行 GBTD。单击视图，图块大小，16x16。

{% asset_img 01gbtd16x16.png }

绘制图像，将其复制并粘贴到第二个瓦块插槽中，然后进行更改以制作两帧动画。 我们将在这些之间来回切换。

{% asset_img 02gbtdtwotiles.png }

单击文件，导出到，将 Type 更改为 GBDK C 文件（* .c），并将 To 更改为1。我还将文件名和标签更改为“ smile”。 点击确定。

{% asset_img 03gbtdexport.png }

这将创建一个 .c 和 .h 文件。.c 文件应如下所示：

```c
//lots of comments
unsigned char smile[] =
{
  0x0F,0x0F,0x30,0x30,0x40,0x40,0x40,0x40,
  0x84,0x84,0x84,0x84,0x84,0x84,0x84,0x84,
  0x84,0x84,0x84,0x84,0x80,0x80,0x80,0x80,
  0x44,0x44,0x43,0x43,0x30,0x30,0x0F,0x0F,
  0xF0,0xF0,0x0C,0x0C,0x02,0x02,0x02,0x02,
  0x21,0x21,0x21,0x21,0x21,0x21,0x21,0x21,
  0x21,0x21,0x21,0x21,0x01,0x01,0x01,0x01,
  0x22,0x22,0xC2,0xC2,0x0C,0x0C,0xF0,0xF0,
  0x0F,0x0F,0x30,0x30,0x40,0x40,0x40,0x40,
  0x84,0x84,0x84,0x84,0x84,0x84,0x84,0x84,
  0x84,0x84,0x84,0x84,0x80,0x80,0x80,0x80,
  0x44,0x44,0x43,0x43,0x30,0x30,0x0F,0x0F,
  0xF0,0xF0,0x0C,0x0C,0x02,0x02,0x02,0x02,
  0x01,0x01,0x01,0x01,0x01,0x01,0xF9,0xF9,
  0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,
  0x22,0x22,0xC2,0xC2,0x0C,0x0C,0xF0,0xF0
};
//more comments
```

可见，GBTE 只是将像素转换为以标签命名的数组。我们将在要编写的代码中包含 .c 文件。

# 第二步：set_sprite_data

## 在屏幕上绘制精灵

GBDK 通过 gb.h 中提供的一些函数来处理精灵。

启动您的文本编辑器，并包含必要的文件：

```c
#include <gb/gb.h>  //Angle brackets check the compiler's include folders
#include "smile.c" //double quotes check the folder of the code that's being compiled
```

每个 C 脚本都需要一个主函数，因此请在其中添加以下函数之一：

```c
void main(){

}
```

这是我们将编写所有代码的地方。

进入 main 函数，输入：

```c
SPRITES_8x16;
set_sprite_data(0, 8, smile);
set_sprite_tile(0, 0);
move_sprite(0, 75, 75);
SHOW_SPRITES;
```

逐行显示：

- 告诉 GBDK 一次加载两个 8x8 精灵，制作一个 8x16 瓦片
- 从零开始，将 8 个 8x8 瓦片从 smile 数组推入运行中的精灵数据
- 将图块 0 设置为精灵数据中编号为 0 的精灵
- 将精灵 0 移动到该坐标

这是到目前为止的完整代码：

```c
#include <gb/gb.h>
#include "smile.c"

void main(){
	SPRITES_8x16;
	set_sprite_data(0, 8, smile);
	set_sprite_tile(0, 0);
	move_sprite(0, 75, 75);
	SHOW_SPRITES;
}
```

将该文件保存为 filename.c，使用 lcc 编译：`/path/to/GBDK/bin/lcc -o gamename.gb filename.c`。

运行 BGB 并加载 gamename.gb。

{% asset_img 04bgbhalfsmile.png }

Emmmmmm，这里只有半张脸。好吧，由于 Gameboy 只能处理最大 8x16 的瓦块，我们需要通过把两个 8x16 的瓦块画在一起来构造一个 16x16 的。


首先，让我们看看精灵和图块如何存储在 Gameboy 上。

在 BGB 中，您已编写的 rom 已加载并运行，右键单击，将鼠标悬停在 “其他” 上，单击 “VRAM查看器”。

{% asset_img 05bgbvramviewer.png }

在这里，您可以看到我们使用 set_sprite_data 设置为 8x8 瓦片的精灵。最左侧的两个数字 0 和 1 亮起，表示它们正在使用中。我们想要的是设置第二个图块，将其用脸的右半部分填充，然后将其与左半部分对齐。

将此添加到代码中：

```c
set_sprite_tile(1, 2);
move_sprite(1, 75 + 8, 75);
```

在 VRAM 查看器中进行计数时，该面的左上象限是精灵 0，左下角是 1，右上角从 2 开始，并且 SPRITES_8x16 行将使我们设置的图块包含精灵 3，即 所有四个象限。现在，我们在屏幕上激活了两个精灵，分别是 0 号和 1 号 ，而精灵 1 比精灵 0 靠右 8 个像素，这意味着它可以完美排列以显示一个 16x16 的面。

请记住，每次移动此精灵时，都需要将两个部分一起移动。

编译并运行它，然后在 VRAM 查看器中查看。

# 第三步：动画

我们将定时使用 set_sprite_tile 替换图块。

在 SHOW_SPRITES 之后在主函数中编写一个 while 循环。我们使用 while(1)，这样它会永远循环。

```c
while(1){

}
```

在该循环内，将图块编号 1（脸的右侧）更改为精灵 6（我使用 VRAM 查看器进行计数）。

```c
set_sprite_tile(1, 6);
```

将其交换回去并延迟几个时间，以便可以看到更改，我们会得到以下代码：

```c
while(1){
	set_sprite_tile(1, 6);
	delay(500);
	set_sprite_tile(1,2);
	delay(500);
}
```

这是所有可以用于复制和粘贴的代码：

```c
#include <gb/gb.h>
#include "smile.c"

void main(){
	SPRITES_8x16;
	set_sprite_data(0, 8, smile);
	set_sprite_tile(0, 0);
	move_sprite(0, 75, 75);
	set_sprite_tile(1, 2);
	move_sprite(1, 75 + 8, 75);
	SHOW_SPRITES;

	while(1){
		set_sprite_tile(1, 6);
		delay(500);
		set_sprite_tile(1,2);
		delay(500);
	}
}
```

编译并运行它。成功运行！

{% asset_img 06bgbwink.gif }

在 VRAM 查看器中实时观看图块切换。

    一个有趣的注释：由于仅精灵的右侧发生了变化，因此左侧的重复是多余的。将来的迭代可能会删除它以保存数据。此外，只有右上角的四分之一会发生变化，因此，如果我们绘制四个8x8瓦片而不是两个8x16瓦片，我们可以通过仅包含并交换该象限来节省更多空间。

现在，让这个更加复杂一点：加载多个精灵集。

# 第四步：多个精灵集合

本节在这里展示了跟踪“哪些精灵存储在何处”的重要性。

我为动画制作了第二张脸，并将其导出到 frown.c（带有皱眉标签），并使用上述方法将其包含在代码中。

这是数组：

```c
unsigned char frown[] =
{
  0x0F,0x0F,0x30,0x30,0x40,0x40,0x40,0x40,
  0x84,0x84,0x84,0x84,0x84,0x84,0x84,0x84,
  0x84,0x84,0x84,0x84,0x80,0x80,0x87,0x87,
  0x58,0x58,0x40,0x40,0x30,0x30,0x0F,0x0F,
  0xF0,0xF0,0x0C,0x0C,0x02,0x02,0x02,0x02,
  0x21,0x21,0x21,0x21,0x21,0x21,0x21,0x21,
  0x21,0x21,0x21,0x21,0x01,0x01,0xE1,0xE1,
  0x1A,0x1A,0x02,0x02,0x0C,0x0C,0xF0,0xF0,
  0x0F,0x0F,0x30,0x30,0x40,0x40,0x40,0x40,
  0x90,0x90,0x8E,0x8E,0x80,0x80,0x84,0x84,
  0x84,0x84,0x84,0x84,0x80,0x80,0x87,0x87,
  0x58,0x58,0x40,0x40,0x30,0x30,0x0F,0x0F,
  0xF0,0xF0,0x0C,0x0C,0x02,0x02,0x02,0x02,
  0x09,0x09,0x71,0x71,0x01,0x01,0x21,0x21,
  0x21,0x21,0x21,0x21,0x01,0x01,0xE1,0xE1,
  0x1A,0x1A,0x02,0x02,0x0C,0x0C,0xF0,0xF0
};
```

让我们在主函数中（在循环上方）将其设置为我们的Sprite数据：

```c
set_sprite_data(8, 8, frown);
```

这就是本演示的重点：当图块以数字方式进展时（图块 0，图块 1，图块 2 ...），set_sprite_data 只是将 8x8 子图插入到数据集中。第一个参数必须指向内存中的第一个自由精灵，并且要记住，我们已经用微笑艺术的 8 个精灵填充了 0-7 。如果我们将第一个参数设置为小于 8 的任何值，它将覆盖部分微笑，对于更大的覆盖范围，并且两张脸之间会有间隙。第二个参数再次是我们在此处插入的 8x8 磁贴的数量，并且我们的心理计数最高跳到 16，这意味着 0-15 被占用。

这样做的复杂之处在于，即使我们有并行的动画周期，我们也必须记住每个图块在内存中的位置。 好处是任何图块都可以从子画面堆栈中的任何位置拉出。

让我们复制微笑代码以便与新的皱眉脸一起使用，同时交换精灵：

```c
#include <gb/gb.h>
#include "smile.c"
#include "frown.c"

void main(){
	SPRITES_8x16;
	set_sprite_data(0, 8, smile);
	set_sprite_tile(0, 0);
	move_sprite(0, 55, 75);
	set_sprite_tile(1, 2);
	move_sprite(1, 55 + 8, 75);
		
	set_sprite_data(8, 8, frown);
	set_sprite_tile(2, 8);
	move_sprite(2, 95, 75);
	set_sprite_tile(3, 10);
	move_sprite(3, 95 + 8, 75);

	SHOW_SPRITES;

	while(1){
		set_sprite_tile(1, 6);
		set_sprite_tile(2, 12);
		set_sprite_tile(3, 14);
		delay(500);
		set_sprite_tile(1,2);
		set_sprite_tile(2, 8);
		set_sprite_tile(3, 10);
		delay(500);
	}
}
```

    我们用第二张脸的左半部分和右半部分填充编号为 2 和 3 的精灵。
    当笑脸在精灵数据 2（和 3）和 6（和 7）之间切换时，皱眉在左侧的 8（和 9）和 12（和 13）之间以及在 10（和 11）和 14（和 15）之间循环。 ）在右侧，两边同时出现。

编译并在 VRAM 查看器中查看！

{% asset_img 07bgbsmilefrown.gif }

# 结论

希望这可以教您如何使用 GBDK 加载和显示精灵，或者至少以人类可读形式呈现了一个真实示例。
