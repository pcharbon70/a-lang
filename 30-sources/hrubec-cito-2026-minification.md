---
title: "Reducing Token Usage of State-in-Context Agents using Minification"
kind: source
created: 2026-08-11
authors:
  - "Nicolas Hrubec"
  - "Jürgen Cito"
published: 2026
citation_key: "hrubec-cito-2026-minification"
container: "2026 IEEE/ACM 34th International Conference on Program Comprehension"
edition: null
isbn: null
doi: "10.1145/3794763.3798174"
url: "https://arxiv.org/abs/2606.01326"
accessed: 2026-08-11
tags:
  - coding-agents
  - minification
  - token-efficiency
aliases: []
---

# Reducing Token Usage of State-in-Context Agents using Minification

## Reference

Nicolas Hrubec and Jürgen Cito. “Reducing Token Usage of State-in-Context
Agents using Minification.” *ICPC 2026*, Replications and Negative Results
track. [arXiv](https://arxiv.org/abs/2606.01326). DOI:
[10.1145/3794763.3798174](https://doi.org/10.1145/3794763.3798174).

## Method

The authors reimplement a state-in-context repository-repair agent and apply
Python transformations including comment and docstring removal, whitespace
reduction, identifier shortening, import rewriting, and dedentation. The full
SWE-bench Verified comparison uses GPT-5-mini. Individual and stacked
ablations use a 100-instance subset with GPT-4.1 and GPT-5-mini. Token counts
use one tiktoken encoding as a consistent proxy rather than each model's
internal tokenizer.

## Findings

End-to-end minification lowers average input from 90,535 to 52,776 tokens, a
42% reduction, while resolution falls from 50% to 38%. Dedentation is excluded
from that run because it causes a larger degradation.

Identifier shortening is a smaller and riskier contributor. On the 100-case
GPT-4.1 ablation, short variable, function, and class names save roughly
2.9%, 2.6%, and 4.5% of input tokens respectively. Resolution changes from a
46% baseline to 38%, 42%, and 45%. Mapping variants preserve more information
and recover some or all of the performance while saving fewer tokens.

## Relevance

This is the closest negative evidence for the proposal to shorten A-Lang
identifiers. Token savings from names can be modest even when the task penalty
is material. It also shows that a transformation preserving Python execution
semantics does not necessarily preserve an LLM agent's repair performance.

## Limits

The identifier ablations use only 100 tasks and one primary model, and exact
results are sensitive to stochastic file selection. The full 42% condition
combines many transformations and cannot attribute the performance loss to
names alone. A-Lang tasks are much smaller and structurally different.

## Derived notes

- [Token-efficient syntax for A-Lang](../20-notes/token-efficient-syntax-for-a-lang.md)
- [Can a compact projection reduce A-Lang token use without reducing fidelity?](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
- [Token-efficient A-Lang syntax](../10-maps/token-efficient-alang-syntax.md)
