---
title: 【译】GBDK 手柄
date: 2020-09-19 22:41:23
tags:
- GBDK
- 中文
categories:
- GBDK
---

原文链接：[https://gbdev.gg8.se/wiki/articles/GBDK_Joypad_Tutorial](https://gbdev.gg8.se/wiki/articles/GBDK_Joypad_Tutorial)

# 介绍

本教程旨在详细介绍将手柄与 GBDK 配合使用的方法。

# 工具

您将需要：GBDK，文本编辑器，Game Boy Tile Designer 和仿真器（建议使用 BGB，它有许多调试功能）以及任何水平的 C 知识。

如果需要，请替换您喜欢的工具，但是本教程假定您具有上面列出的工具。

# joypad() 函数

GBDK 的 gb.h 具有 Joypad() 函数，该函数返回手柄的状态。

joypad() 函数可以返回以下输入的状态：

```c
J_START
J_SELECT
J_B
J_A
J_DOWN
J_UP
J_LEFT
J_RIGHT
```

## Program 1: 返回 joypad() 状态

{% asset_img Program1.gif %}

让我们编写一个简单的程序来在按下按钮时返回 joypad() 的状态：

```c
#include <stdio.h> // include this file for the printf() function
#include <gb/gb.h> // include this file for Game Boy functions

void main(void){
	
	while(1) {

	switch(joypad()) {
		
		case J_RIGHT : // If joypad() is equal to RIGHT
			printf("Right!\n");
			delay(100);
			break;
		case J_LEFT : // If joypad() is equal to LEFT
                        printf("Left!\n");
                        delay(100);
			break;
		case J_UP : // If joypad() is equal to UP
			printf("Up!\n");
			delay(100);
			break;
		case J_DOWN : // If joypad() is equal to DOWN
			printf("Down!\n");
			delay(100);
			break;
		case J_START : // If joypad() is equal to START
			printf("Start!\n");
			delay(100);
			break;
		case J_SELECT : // If joypad() is equal to SELECT
			printf("Select!\n");
			delay(100);
			break;
		case J_A : // If joypad() is equal to A
			printf("A!\n");
			delay(100);
			break;
		case J_B : // If joypad() is equal to B
			printf("B!\n");
			delay(100);
			break;			
		default :
			break;
			}
		}
	}
```

## Program 2: 使用 waitpad() 和 waitpadup()

{% asset_img Program2.gif %}

您还可以使用另外两个游戏手柄的函数：

```c
waitpad()  // This function waits for a button to be pressed.
waitpadup() // This function waits for all buttons to be released.
```

让我们在一个简单的程序中同时使用 waitpad() 函数和 waitpadup() 函数：

```c
#include <stdio.h> // include this file for the printf() function
#include <gb/gb.h> // include this file for Game Boy functions

void main(void){
	
	while(1) {

	printf("Please press A\n");
	waitpad(J_A); // waitpad() is waiting for the A button to be pressed.
	printf("You pressed A! Cool!\n\n");
	
	printf("Hold down the LEFT button\n");
	waitpad(J_LEFT); // waitpad() is waiting for the LEFT button to be pressed.
	printf("You're holding down LEFT!\n");
	waitpadup(); // waitpadup() is waiting for all buttons to be depressed but you have to hold down LEFT to get here so it is
                    // waiting on LEFT to be depressed.
	printf("You've released LEFT\n\n\n");
	
		}
	}
```

## Program 3: 在屏幕上移动精灵

{% asset_img Program3.gif %}

现在，让我们使用 joypad() 函数在屏幕上移动精灵。如果您对 GBDK Sprite 不熟悉，则需要查看 GBDK Sprite 教程。

```c
#include <gb/gb.h> // include this file for Game Boy functions

//Created with GBTD, exported to .c with options from: 0, to: 0, label: smile
unsigned char smile[] =
{
  0x3C,0x3C,0x42,0x42,0x81,0x81,0xA5,0xA5,
  0x81,0x81,0x81,0xA5,0x42,0x5A,0x3C,0x3C
};

void main(){
	
	int x = 55; // Our beginning x coord
	int y = 75; // Our beginning y coord
	
	SPRITES_8x8;
	set_sprite_data(0, 0, smile);
	set_sprite_tile(0, 0);
	move_sprite(0, x, y); // Move sprite to our predefined x and y coords

	SHOW_SPRITES;

	while(1){
		if(joypad()==J_RIGHT) // If RIGHT is pressed
		{
			x++;
			move_sprite(0,x,y); // move sprite 0 to x and y coords
			delay(10);
		}
		
		if(joypad()==J_LEFT)  // If LEFT is pressed
		{
			x--;
			move_sprite(0,x,y); // move sprite 0 to x and y coords
			delay(10);
		}
		
		if(joypad()==J_UP)  // If UP is pressed
		{ 
			y--;
			move_sprite(0,x,y); // move sprite 0 to x and y coords
			delay(10);
		}
		
		if(joypad()==J_DOWN)  // If DOWN is pressed
		{ 
			y++;
			move_sprite(0,x,y); // move sprite 0 to x and y coords
			delay(10);
		}
	}
```