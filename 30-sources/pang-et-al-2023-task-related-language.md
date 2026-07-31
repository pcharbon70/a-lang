---
title: "Natural Language Instruction-following with Task-related Language Development and Translation"
kind: source
created: 2026-07-30
authors:
  - "Jing-Cheng Pang"
  - "Xinyu Yang"
  - "Si-Hang Yang"
  - "Xiong-Hui Chen"
  - "Yang Yu"
published: 2023
citation_key: pang2023TALAR
url: "https://proceedings.neurips.cc/paper_files/paper/2023/hash/1dc2fe8d9ae956616f86bab3ce5edc59-Abstract-Conference.html"
accessed: 2026-07-30
tags:
  - task-language
  - instruction-following
  - reinforcement-learning
aliases:
  - "TALAR"
---

# Natural Language Instruction-following with Task-related Language Development and Translation

## Reference

Jing-Cheng Pang, Xinyu Yang, Si-Hang Yang, Xiong-Hui Chen, and Yang Yu.
“Natural Language Instruction-following with Task-related Language Development
and Translation.” NeurIPS 2023.
[Paper](https://proceedings.neurips.cc/paper_files/paper/2023/hash/1dc2fe8d9ae956616f86bab3ce5edc59-Abstract-Conference.html)

## Method

TALAR separates natural-language interpretation from policy learning. It learns
a compact task language made of predicate-like discrete representations, trains
a translator from human instructions into that representation, and conditions a
reinforcement-learning policy on the translated task.

The task language is learned through a referential game rather than manually
designed. The experiments use FrankaKitchen and CLEVR-Robot and test both
training instructions and previously unseen expressions.

## Finding

The task-related representation improved instruction-following success and
generalization to unseen phrasings over the reported baselines. It also served
as a useful subtask abstraction for hierarchical reinforcement learning.

## Relevance

This is unusually direct evidence for the hypothesis that an intermediate task
language can reduce the burden of simultaneously interpreting unrestricted
natural language and learning task behavior.

## Limits

The learned language is an anonymous binary predicate representation for
bounded robotics environments, not a human-authored general-purpose agent
language. It requires task data, translation training, and policy training;
the result does not imply that a novel textual syntax will help a pretrained LLM
without adaptation.
