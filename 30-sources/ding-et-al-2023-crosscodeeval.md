---
title: "CrossCodeEval: A Diverse and Multilingual Benchmark for Cross-File Code Completion"
kind: source
created: 2026-08-05
authors:
  - "Yangruibo Ding"
  - "Zijian Wang"
  - "Wasi Uddin Ahmad"
  - "Hantian Ding"
  - "Ming Tan"
  - "Nihal Jain"
  - "Murali Krishna Ramanathan"
  - "Ramesh Nallapati"
  - "Parminder Bhatia"
  - "Dan Roth"
  - "Bing Xiang"
published: 2023
citation_key: "ding-et-al-2023-crosscodeeval"
container: "Advances in Neural Information Processing Systems 36, Datasets and Benchmarks Track"
edition: null
isbn: null
doi: null
url: "https://proceedings.neurips.cc/paper_files/paper/2023/hash/920f2dced7d32ab2ba2f1970bc306af6-Abstract-Datasets_and_Benchmarks.html"
accessed: 2026-08-05
tags:
  - code-completion
  - cross-file-context
  - repository-level-code
aliases:
  - "CrossCodeEval"
---

# CrossCodeEval: A Diverse and Multilingual Benchmark for Cross-File Code Completion

## Reference

Yangruibo Ding et al. “CrossCodeEval: A Diverse and Multilingual Benchmark for
Cross-File Code Completion.” *Advances in Neural Information Processing Systems
36*, Datasets and Benchmarks Track, 2023. [Proceedings record](https://proceedings.neurips.cc/paper_files/paper/2023/hash/920f2dced7d32ab2ba2f1970bc306af6-Abstract-Datasets_and_Benchmarks.html).

## Research question

Can code-completion systems use repository context that lies outside the active
file, and how much does retrieval quality affect that ability?

## Method

The authors construct roughly 10,000 completion examples from about 1,000
permissively licensed Python, Java, TypeScript, and C# repositories. Static
analysis identifies unfinished code that uses names imported from other files.
The evaluation compares in-file context, BM25-retrieved fixed-size snippets,
and an oracle-like condition in which retrieval is informed by the actual
cross-file reference.

## Findings

- Cross-file context materially improves aggregate completion results. For
  StarCoder-15.5B on Python, exact code match rises from 8.82 with in-file
  context to 15.72 with ordinary retrieval and 21.01 with reference-informed
  retrieval.
- Retrieval quality remains a bottleneck: even the strongest tested condition
  stays far from complete accuracy, and identifier overlap is associated with
  better completion.
- More context is not monotonically useful. Retrieved snippets turn some
  otherwise correct completions into failures, and fixed line windows can mix
  relevant definitions with distracting material.

## Relevance

CrossCodeEval supports the claim that exact cross-file relationships are useful
retrieval signals. It does **not** test references authored inside a language.
Its reference-informed condition is better understood as an upper-bound hint:
if a compiler can resolve a source reference reliably, that signal may improve
selection, but the selected content still needs a strict budget.

## Limits

The task is continuation, not architectural explanation or repository editing.
The evaluated models and retrieval methods predate current coding agents. The
reference-informed condition uses information unavailable to an ordinary
retriever, and the paper does not isolate whether a symbol identity, its target
text, or both cause the gain.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
