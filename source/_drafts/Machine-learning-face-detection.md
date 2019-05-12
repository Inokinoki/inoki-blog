---
title: Machine Learning - Introduction
date: 2019-04-22 20:36:24
tags:
- Machine Learning
categories:
- Machine Learning
---

# Machine and Think

A famous question is "Can machines think ?"

A. M. Turing, Computeing Machinery and Intelligence:
```
As I have explained, the problem is mainly one of programming. [...] Estimates of the storage capacity of the brain vary from 1010 to 1015 binary digits. [...] I should be surprised if more than 109 was required for satisfactory playing of the imitation game, at any rate against a blind man. [...] At my present rate of working I produce about a thousand digits of progratiirne a day, so that about sixty workers, working steadily through the fifty years might accomplish the job, if nothing went into the wastepaper basket. Some more expeditious method seems desirable.
[...]
Instead of trying to produce a programme to simulate the adult mind, why not rather try to produce one which simulates the child's? If this were then subjected to an appropriate course of education one would obtain the adult brain. Presumably the child brain is something like a notebook as one buys it from the stationer's. Rather little mechanism, and lots of blank sheets. (Mechanism and writing are from our point of view almost synonymous.) Our hope is that there is so little mechanism in the child brain that something like it can be easily programmed. The amount of work in the education we can assume, as a first approximation, to be much the same as for the human child.
```

So it's easier to teach the machine think from no given mechanism situation.

# Type of Machine Learning

## Classified by learning
### Supervisor learning
The learning data has associated results.
### Non-supervisor learning
The learning data has no result.
### Renforcement learning
The learning data has no result, but we will give a score for the given decision.

## Classified by prediction
### Classification
The space of prediction is discrete and finite.
The result y is called *Class* or *Label*.
### Regression
The space of prediction is continuous.

# Concepts
## Loss function
For a binary classification (the result is 0/-1 and 1), there are four cases:
|Prediction \ Reality  |+1             |-1/0           |
|----------------------|---------------|---------------|
|+1                    |True positive  |False positive |
|-1/0                  |False negative |True negative  |
|                      |               |               |
The True/False is the correction of prediction.
The Positive/Negative is the result of prediction.

...

## Train set

## Validation set

## Test set

## Cross validation
