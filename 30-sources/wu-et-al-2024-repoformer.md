---
title: "Repoformer: Selective Retrieval for Repository-Level Code Completion"
kind: source
created: 2026-08-05
authors:
  - "Di Wu"
  - "Wasi Uddin Ahmad"
  - "Dejiao Zhang"
  - "Murali Krishna Ramanathan"
  - "Xiaofei Ma"
published: 2024
citation_key: "wu-et-al-2024-repoformer"
container: "Proceedings of the 41st International Conference on Machine Learning, PMLR 235"
edition: null
isbn: null
doi: null
url: "https://proceedings.mlr.press/v235/wu24a.html"
accessed: 2026-08-05
tags:
  - code-completion
  - repository-level-code
  - selective-retrieval
aliases:
  - "Repoformer"
---

# Repoformer: Selective Retrieval for Repository-Level Code Completion

## Reference

Di Wu et al. “Repoformer: Selective Retrieval for Repository-Level Code
Completion.” *Proceedings of the 41st International Conference on Machine
Learning*, PMLR 235:53270–53290, 2024. [PMLR record](https://proceedings.mlr.press/v235/wu24a.html).

## Method

Repoformer trains a code model with self-supervised labels to decide whether
retrieval is likely to improve a completion. The same model acts as selective
retrieval policy and generator. The experiments span RepoEval,
CrossCodeEval, and CrossCodeLongEval, with multiple generators, retrievers,
languages, and context placements.

## Findings

- In the studied standard RAG setting, only about one fifth of retrieved
  contexts help, about one fifth hurt, and most leave the judged result
  unchanged; in some tasks as many as 80% of retrievals do not improve output.
- Selective retrieval maintains or improves completion quality while producing
  up to 70% online-serving speedup in the reported setup.
- Retrieval placement and training for robustness matter. Ablations show that
  a retrieval-decision objective and exposure to cross-file context are both
  important, while poorly placed context can substantially damage function
  completion.

## Relevance

This is the clearest evidence against treating every source reference as an
automatic prompt inclusion. A-Lang should preserve references as typed,
queryable candidates and let a bounded selector decide which projections to
materialize for the current question.

## Limits

The retrieval-needed labels use lexical completion metrics, which are weaker
for function bodies. The work evaluates completion rather than general code
understanding or agent editing. A learned selector can also expose sensitive
repository material, and the paper does not test source-authored annotations.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
