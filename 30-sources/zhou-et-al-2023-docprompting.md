---
title: "DocPrompting: Generating Code by Retrieving the Docs"
kind: source
created: 2026-08-05
authors:
  - "Shuyan Zhou"
  - "Uri Alon"
  - "Frank F. Xu"
  - "Zhiruo Wang"
  - "Zhengbao Jiang"
  - "Graham Neubig"
published: 2023
citation_key: "zhou-et-al-2023-docprompting"
container: "The Eleventh International Conference on Learning Representations"
edition: null
isbn: null
doi: null
url: "https://openreview.net/forum?id=ZTCxT2t2Ru"
accessed: 2026-08-05
tags:
  - code-generation
  - documentation-retrieval
  - retrieval-augmented-generation
aliases:
  - "DocPrompting"
---

# DocPrompting: Generating Code by Retrieving the Docs

## Reference

Shuyan Zhou et al. “DocPrompting: Generating Code by Retrieving the Docs.”
*ICLR 2023*. [OpenReview](https://openreview.net/forum?id=ZTCxT2t2Ru).

## Method

DocPrompting retrieves the top documentation passages for a natural-language
intent and conditions code generation on both. The experiments cover Bash
commands in a newly curated `tldr` benchmark and held-out Python APIs in a
re-split CoNaLa benchmark. Sparse and trained dense retrievers are compared,
and oracle-document conditions estimate retrieval headroom.

## Findings

- Retrieved documentation consistently improves the tested smaller generators.
  On execution-tested CoNaLa examples, CodeT5 gains 2.85 absolute points at
  pass@1; on `tldr`, exact-match gains reach 6.9 points for GPT-Neo-1.3B.
- Documentation particularly improves recall of functions held out from
  generator training: CodeT5’s unseen-function recall rises from 9.03 to
  18.30.
- Documentation can bridge natural-language intent terms and exact code terms
  such as signatures. Retrieval errors also propagate: documentation for
  `read_csv` causes an invalid `skiprows` argument to be attached to
  `to_csv` in the paper’s case study.

## Relevance

The work supports references whose projections can expose signatures and
curated documentation, especially for unfamiliar APIs. It also supports
validating generated calls against the resolved target rather than trusting
retrieved prose.

## Limits

The tasks are short natural-language-to-code generation, not repository
understanding or editing. Results depend on constructed documentation pools and
held-out functions, with possible unsupervised pretraining exposure. Stronger
Codex results are small without an oracle retriever, and irrelevant top-k
documents can confuse the generator.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
