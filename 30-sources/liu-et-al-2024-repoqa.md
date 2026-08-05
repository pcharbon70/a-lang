---
title: "RepoQA: Evaluating Long Context Code Understanding"
kind: source
created: 2026-08-05
authors:
  - "Jiawei Liu"
  - "Jia Le Tian"
  - "Vijay Daita"
  - "Yuxiang Wei"
  - "Yifeng Ding"
  - "Yuhan Katherine Wang"
  - "Jun Yang"
  - "Lingming Zhang"
published: 2024
citation_key: "liu-et-al-2024-repoqa"
container: "ICML 2024 Workshop on Long-Context Foundation Models"
edition: null
isbn: null
doi: null
url: "https://openreview.net/forum?id=hK9YSrFuGf"
accessed: 2026-08-05
tags:
  - code-understanding
  - long-context
  - repository-level-code
aliases:
  - "RepoQA"
---

# RepoQA: Evaluating Long Context Code Understanding

## Reference

Jiawei Liu et al. “RepoQA: Evaluating Long Context Code Understanding.” *ICML
2024 Workshop on Long-Context Foundation Models*.
[OpenReview](https://openreview.net/forum?id=hK9YSrFuGf).

## Method

RepoQA’s Searching Needle Function task asks a model to reproduce a function
from a natural-language description while reading a 16K-token repository
context. The benchmark contains 500 tasks from 50 repositories in five
languages. Descriptions cover purpose, inputs, outputs, and procedure while
avoiding the target’s identifiers. Thirty-three models are evaluated.

The comment-removal ablation removes natural comments and inserts synthetic
line comments so the target function remains at approximately the same relative
position.

## Findings

- Strong long-context models can perform the retrieval task well, with the
  best reported average near 90.6%, but performance varies by language and
  model.
- Most tested models improve when natural comments are removed. GPT-4o moves
  from 90.6 to 93.2 and GPT-4 Turbo from 76.4 to 92.6 in the reported
  comparison. Gemini models are a notable exception; Gemini 1.5 Flash falls
  from 90.0 to 54.2 and often begins counting the synthetic line comments.
- The result is evidence that comments are not automatically useful context;
  content, formatting, model family, and position interact.

## Relevance

RepoQA is important counterevidence to a simple “add more explanatory text”
strategy. A typed source reference should have machine-checkable semantics and
should usually be rendered separately from arbitrary comments. Any benefit
must be compared against generated symbol maps and comment-only baselines.

## Limits

This is one synthetic retrieval task with GPT-4-generated, deliberately
distinct descriptions and a BLEU-based acceptance threshold. Synthetic padding
comments are themselves behaviorally active, so the ablation does not prove
that comments generally harm understanding. It does not test references or
repository editing.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
