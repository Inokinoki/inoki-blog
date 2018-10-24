---
title: ELFhash algorithm understanding by GDB
date: 2018-08-11 12:06:00
updated: 2018-10-24 23:12:32
tags:
- Algorithm
- Hash
- GDB
categories:
- [Algorithm, Hash]
---
ELFhash algorithm is a hash function who works very well with great string and tiny string.

The source code is as follows:

```c
unsigned int ELFhash(char *str)
{
	unsigned int hash=0;
	unsigned int x=0;
	while(*str)
	{
		hash=(hash<<4)+*str; 
		if(( x=hash & 0xf0000000 ) != 0) { hash^=(x>>24);
		hash&=~x; // Clear high 4 bit
	}
	str++;
	}
	return (hash & 0x7fffffff);
}
```

The time complexity is ``O(n)`` because of the loop of source string has n characters.

While the space complexity is ``O(1)``.

```
(gdb) b 5
Breakpoint 1 at 0x725: file test.c, line 5.
```
We set a breakpoint at the beginning of function ``main``. There is nothing to do at this line, so we let it go.

```
(gdb) n
7		scanf("%s", source);
```
At this line, we will input ``abcdefghijkl`` as the string to be hashed.

```
(gdb) n
abcdefghijkl
8		unsigned int r = ELFhash(source);
```
When we reached line 8, enter the function.

```
(gdb) p str
$1 = 0x7fffffffdba0 "abcdefghijkl"
(gdb) n
9			hash=(hash<<4)+*str;
(gdb) n
10			if(( x=hash & 0xf0000000 ) != 0)
(gdb) p hash
$2 = 97
```
At the end of the first loop, we got str ``abcdefghijkl``, and hash became ``97(0x00000061)``.

```
(gdb) p hash
$3 = 1650
(gdb) p str
$4 = 0x7fffffffdba1 "bcdefghijkl"
```
After the second loop, ``0x00000061`` will be moved 4 bits to the left. So it's ``0x00000610`` + ``0x00000062`` = ``0x00000672 (1650)``.

For the mixture of the first 7 number, it's simply moving to the left with 4 bits and an addition.

At the 7th times, 6 is moved to the first bit of the hash. So if we continue the operations, it will be removed. To avoid this, the algorithm provides a serial of operations to guarantee the mixture between every bit near. For the moment, ``x=0x06``, ``hash=0x6789abc7``.

```
0			if(( x=hash & 0xf0000000 ) != 0)
(gdb) 
12				hash^=(x>>24);  
(gdb) n
13				hash&=~x;   	// Clear high 4 bit
```
After these operations, the high 4 bits at the first bit is cleared to be 0. And the operation exclusive OR (^) will keep the bits from the second to the last second with ``789ab``. For x, it's the high 4 bits of the first character. As the similarity between exclusive OR and the addition, it's the same operation as the code ``hash=(hash<<4)+*str``. But it's a looped one.  So in the end, the hash became, ``0x0789aba7``.

Obviously, the following characters will be handled as the seventh bit ("g" for the string), and it can be a ring of addition while a new character added.

I'm waiting for a proof of the homogeneity.
