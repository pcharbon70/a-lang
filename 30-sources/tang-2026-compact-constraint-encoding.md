---
title: "Compact Constraint Encoding for LLM Code Generation: An Empirical Study of Token Economics and Constraint Compliance"
kind: source
created: 2026-08-11
authors:
  - "Hanzhang Tang"
published: 2026
citation_key: "tang-2026-compact-constraint-encoding"
container: "arXiv preprint"
edition: null
isbn: null
doi: "10.48550/arXiv.2604.07192"
url: "https://arxiv.org/abs/2604.07192"
accessed: 2026-08-11
tags:
  - code-generation
  - constraint-following
  - token-efficiency
aliases: []
---

# Compact Constraint Encoding for LLM Code Generation: An Empirical Study of Token Economics and Constraint Compliance

## Reference

Hanzhang Tang. “Compact Constraint Encoding for LLM Code Generation: An
Empirical Study of Token Economics and Constraint Compliance.”
arXiv:2604.07192, 2026. [arXiv](https://arxiv.org/abs/2604.07192). DOI:
[10.48550/arXiv.2604.07192](https://doi.org/10.48550/arXiv.2604.07192).

## Method

The preprint compares full natural-language constraints, compact natural
language, and a tag-based header across six experimental rounds. It reports 11
models, 16 tasks, and more than 830 invocations, including single-agent and
three-stage conditions. Six constraints per task are scored by deterministic
pattern checks. The paper reports nonparametric tests, effect sizes, and
confidence intervals, and separates conventional constraints from those that
oppose common model defaults.

## Findings

The compact header reduces the constraint section by about 71% and the full
prompt by roughly 25–30% in the tested templates. No statistically detectable
compliance difference appears among the three encodings; the H-versus-full
comparison has Cliff's delta near zero and a confidence interval within about
±3 percentage points. Constraint type and domain matter more than surface
encoding.

A negative-control encoding in Classical Chinese saves only 4.6%, despite its
human-perceived density. The paper attributes this to poor alignment with the
tested BPE vocabulary: compact characters are not necessarily compact tokens.

## Relevance

The header condition resembles a small task DSL and supports testing familiar,
mnemonic tags before opaque punctuation. It also supports external rule-based
verification instead of model self-assessment.

## Limits

This is a single-author preprint run through one non-public platform. Most
tasks are single-file generation, failures are concentrated in a few
constraint types, the study was not preregistered for formal equivalence, and
the scorer required corrections after review. It is promising but not a basis
for declaring compact A-Lang fidelity solved.

## Derived notes

- [Token-efficient syntax for A-Lang](../20-notes/token-efficient-syntax-for-a-lang.md)
- [Can a compact projection reduce A-Lang token use without reducing fidelity?](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
- [Token-efficient A-Lang syntax](../10-maps/token-efficient-alang-syntax.md)
