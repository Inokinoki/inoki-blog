---
title: Leetcode 300 Longest Increasing Subsequence
date: 2018-11-07 23:34:40
tags:
- Leetcode
- Dynamic Programming
categories:
- [Leetcode, Dynamic Programming]
---

Here the question:

Given an unsorted array of integers, find the length of longest increasing subsequence.

**Example:**

```
Input: [10,9,2,5,3,7,101,18]
Output: 4 
Explanation: The longest increasing subsequence is [2,3,7,101], therefore the length is 4. 
```

- There may be more than one LIS combination, it is only necessary for you to return the length.
- Your algorithm should run in O(*n2*) complexity.

There is a more simple algorithm to solve this question. But we would like to learn about **Dynamic Programming**. So we will take the O(n2) solution.



### Dynamic Programming

A condition necessary for Dynamic Programming:

```
In computer science, a problem is said to have optimal substructure if an optimal solution can be constructed from optimal solutions of its subproblems. This property is used to determine the usefulness of dynamic programming and greedy algorithms for a problem.
```

It means that the optimal result is constructed by the optimal result of its subproblem.

Another condition:

```
In computer science, a problem is said to have overlapping subproblems if the problem can be broken down into subproblems which are reused several times or a recursive algorithm for the problem solves the same subproblem over and over rather than always generating new subproblems.
```

It means that we can reuse the result of the subproblem of the problem that we are facing.

If a problem tallies with the two conditions, then the problem can be solved by Dynamic Programming.

### Solution

The prototype of this function is

```c
int lengthOfLIS(int *A, int length)
```

``A`` is an array, ``length`` is the length of array ``A``.

For overlapping subproblems property, to reuse the result of subproblems, we have to store the result of subproblems. We assigned an array with enougn slots for results.

```c
int F[length];
memset(F, 0, length);
```

The first element must be a valid increasing subsequence because there is only one element. 

So for the problem with only one element, we have the result:

```c
F[0] = 1;
```

And then, for the next subproblems, we can execute a loop to solve them one by one.

```c
for (int k=1;k<length;k++)
{
    ...
}
```

By using this loop, we can solve firstly F[1], then F[2]... until F[length-1].

For each F[k], we search all previous elements to find out which is smaller than ``A[k]``, the element on which we pause. If an element is smaller than ``A[k]``, it means that at worst, we have an increasing sequence with two elements (``A[k]`` and the element itself), so it's possible to increase the length at the position of that element by 1 to fill ``F[k]``.

```c
for (int i=0;i<k;i++)
{
    if (A[k] > A[i])
    {
        ...
    }
}
```

We have one slot to be filled, to find out the longest one, we can pick up the largest length at the positions before ``k``, and assign ``length+1`` to ``F[k]``. So we can garantee that, at this position, there is the length of longest increasing sequence, which is the optimal solution of such a problem(or subproblem).

So we can mix the process of finding the largest length and the process of finding the possible lengths.

```c
// Iteration for searching the max of each position
int max = -1;
for (int i=0;i<k;i++)
{
    if (A[k] > A[i])
    {
        // Init max
        if (max == -1) max = i;
        if (F[i] >= F[max])
        {
            max = i;
        }
    }
}

// Check if max value exist
if (max != -1)
{
    F[k] = F[max] + 1;
}
else
{
    F[k] = 1;
}
```

It should be noticed that we check the existence of max length with the condition ``A[k]>A[i]``. If we cannot find anyone, it means that at this position there is a new start of increasing sequence, so we give ``F[k]`` a ``1``.

After the loop, the results are well calculated and stored in the array ``F``. So we can find the largest one and return it. It's not very difficult, we can glance at the full code.

### Final Code

```c
int lengthOfLIS(int *A, int length)
{
    if (length<1) return 0;
    int F[length];
    memset(F, 0, length);
    F[0] = 1;
    for (int k=1;k<length;k++)
    {
        // Iteration for searching the max of each position
        int max = -1;
        for (int i=0;i<k;i++)
        {
            if (A[k] > A[i])
            {
                // Init max
                if (max == -1) max = i;
                if (F[i] >= F[max])
                {
                    max = i;
                }
            }
        }

        // Check if max value exist
        if (max != -1)
        {
            F[k] = F[max] + 1;
        }
        else
            F[k] = 1;
    }
    int max = 0;
    for (int k=0;k<length;k++)
    {
        if (max < F[k])
        {
            max = F[k];
        }
    }
    return max;
}
```

TO DO: There should be a solution with time complexity O(nlogn), find it out !