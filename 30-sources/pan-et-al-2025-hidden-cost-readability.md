---
title: "The Hidden Cost of Readability: How Code Formatting Silently Consumes Your LLM Budget"
kind: source
created: 2026-08-11
authors:
  - "Dangfeng Pan"
  - "Zhensu Sun"
  - "Cenyuan Zhang"
  - "David Lo"
  - "Xiaoning Du"
published: 2025
citation_key: "pan-et-al-2025-hidden-cost-readability"
container: "arXiv preprint; accepted to ICSE 2026"
edition: null
isbn: null
doi: "10.48550/arXiv.2508.13666"
url: "https://arxiv.org/abs/2508.13666"
accessed: 2026-08-11
tags:
  - code-generation
  - minification
  - token-efficiency
aliases: []
---

# The Hidden Cost of Readability: How Code Formatting Silently Consumes Your LLM Budget

## Reference

Dangfeng Pan, Zhensu Sun, Cenyuan Zhang, David Lo, and Xiaoning Du. “The
Hidden Cost of Readability: How Code Formatting Silently Consumes Your LLM
Budget.” arXiv:2508.13666, 2025; accepted to ICSE 2026.
[arXiv](https://arxiv.org/abs/2508.13666). DOI:
[10.48550/arXiv.2508.13666](https://doi.org/10.48550/arXiv.2508.13666).

## Method

The study removes only formatting elements whose removal preserves the parsed
program: selected indentation, whitespace, and newlines. It evaluates
fill-in-the-middle completion in Java, Python, C++, and C# across ten commercial
and open models. Functional correctness is measured with Pass@1, token counts
use each model's tokenizer, and significance tests compare formatted and
unformatted conditions.

## Findings

The authors report an average input reduction around 24.5% with generally
small performance changes. The opportunity is language-dependent: Python saves
far less because indentation and newlines carry syntax, while Java, C++, and C#
permit more removal. Output savings are much smaller unless models are prompted
or fine-tuned to emit compact code. The accompanying transformer is
bidirectional so human-readable code can remain outside inference.

## Relevance

This is direct support for separating a readable A-Lang source from a
deterministic model-facing layout. It also argues for grammar-level
minification that preserves the AST, rather than destructive text stripping.

## Limits

The task is local code completion, not comprehension or generation of a novel
agent contract. The paper covers four mainstream languages and notes that
smaller models fluctuate more. Its aggregate savings should not be transferred
to A-Lang without tokenizer-specific measurement and fidelity tests.

## Derived notes

- [Token-efficient syntax for A-Lang](../20-notes/token-efficient-syntax-for-a-lang.md)
- [Can a compact projection reduce A-Lang token use without reducing fidelity?](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
- [Token-efficient A-Lang syntax](../10-maps/token-efficient-alang-syntax.md)
