---
title: "Token Sugar: Making Source Code Sweeter for LLMs through Token-Efficient Shorthand"
kind: source
created: 2026-08-11
authors:
  - "Zhensu Sun"
  - "Chengran Yang"
  - "Xiaoning Du"
  - "Zhou Yang"
  - "Li Li"
  - "David Lo"
published: 2025
citation_key: "sun-et-al-2025-token-sugar"
container: "Proceedings of the 40th IEEE/ACM International Conference on Automated Software Engineering"
edition: null
isbn: "979-8-3503-5733-2"
doi: "10.1109/ASE63991.2025.00201"
url: "https://arxiv.org/abs/2512.08266"
accessed: 2026-08-11
tags:
  - code-generation
  - syntactic-sugar
  - token-efficiency
aliases:
  - "Token Sugar"
---

# Token Sugar: Making Source Code Sweeter for LLMs through Token-Efficient Shorthand

## Reference

Zhensu Sun, Chengran Yang, Xiaoning Du, Zhou Yang, Li Li, and David Lo.
“Token Sugar: Making Source Code Sweeter for LLMs through Token-Efficient
Shorthand.” *ASE 2025*, pages 2440–2451.
[arXiv](https://arxiv.org/abs/2512.08266). DOI:
[10.1109/ASE63991.2025.00201](https://doi.org/10.1109/ASE63991.2025.00201).

## Method

Token Sugar generalizes Python abstract syntax trees, mines frequent and
token-heavy subtrees, and assigns special-token shorthands to selected
patterns. Each transformation is bijective: desugaring must reconstruct the
original code. The authors mine 799 patterns, transform a training corpus, and
continually pretrain approximately one-billion-parameter Pythia, Llama 3.2, and
Qwen 2.5 models on the sugarized representation.

## Findings

The representation reduces source tokens by 15.1% on the mined LeetCode set
and 12.9% on HumanEval; combined with syntax-level SimPy, reductions reach
22.4% and 20.0%. Adapted models save 7.7–11.2% of generated tokens with no
desugaring failures and near-identical Pass@1 to matched training baselines.

The zero-shot result is the crucial qualification. GPT-4.1 completes ordinary
Python prefixes at 94.5% Pass@1, but falls to 51.2% on sugarized prefixes.
Putting examples of sugars and expansions in the prompt raises this only to
54.9%. The authors conclude that dedicated training is required.

## Relevance

The reversible-transform requirement maps well to a compiler-produced A-Lang
projection, as does mining frequent patterns rather than inventing aliases by
intuition. The zero-shot failure strongly argues against making opaque macros
the primary surface for unadapted hosted models.

## Limits

The experiment covers Python function generation, small adapted models, and a
pattern vocabulary supported by continual pretraining. It is not evidence that
arbitrary A-Lang abbreviations will work with current model families.

## Derived notes

- [Token-efficient syntax for A-Lang](../20-notes/token-efficient-syntax-for-a-lang.md)
- [Can a compact projection reduce A-Lang token use without reducing fidelity?](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
- [Token-efficient A-Lang syntax](../10-maps/token-efficient-alang-syntax.md)
