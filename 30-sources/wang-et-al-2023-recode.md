---
title: "ReCode: Robustness Evaluation of Code Generation Models"
kind: source
created: 2026-08-11
authors:
  - "Shiqi Wang"
  - "Zheng Li"
  - "Haifeng Qian"
  - "Chenghao Yang"
  - "Zijian Wang"
  - "Mingyue Shang"
  - "Varun Kumar"
  - "Samson Tan"
  - "Baishakhi Ray"
  - "Parminder Bhatia"
  - "Ramesh Nallapati"
  - "Murali Krishna Ramanathan"
  - "Dan Roth"
  - "Bing Xiang"
published: 2023
citation_key: "wang-et-al-2023-recode"
container: "Proceedings of the 61st Annual Meeting of the Association for Computational Linguistics"
edition: null
isbn: null
doi: "10.18653/v1/2023.acl-long.773"
url: "https://aclanthology.org/2023.acl-long.773/"
accessed: 2026-08-11
tags:
  - code-generation
  - identifiers
  - robustness
aliases:
  - "ReCode robustness benchmark"
---

# ReCode: Robustness Evaluation of Code Generation Models

## Reference

Shiqi Wang et al. “ReCode: Robustness Evaluation of Code Generation Models.”
*ACL 2023*, pages 13818–13843.
[ACL Anthology](https://aclanthology.org/2023.acl-long.773/). DOI:
[10.18653/v1/2023.acl-long.773](https://doi.org/10.18653/v1/2023.acl-long.773).

## Method

ReCode applies more than 30 meaning-preserving or meaning-preserving-intended
transformations to HumanEval, MBPP, and derived function-completion prompts.
The transformations cover docstrings, function names, variable names, syntax,
and formatting. Identifier conditions include naming-convention changes,
natural name replacements, `VAR_0`, and random alphanumeric names. Generated
programs are executed, and robustness is measured over multiple randomized
perturbations rather than a single average case.

## Findings

Small prompt edits can substantially change generated programs. Across the
tested CodeGen, InCoder, and GPT-J models, syntax transformations produce the
largest worst-case performance drops. Function-name and variable-name changes
also expose instability, even when the transformation is applied consistently.
Human review found that more than 90% of sampled perturbations preserved the
original meaning, though the paper documents that some name perturbations are
less natural than others.

## Relevance

A-Lang's compact forms should be treated as robustness perturbations, not only
as byte-saving rewrites. Exact parsing of both forms is insufficient: the same
model task should be tested across readable names, locally aliased names, and
opaque names, with worst-case fidelity and safety outcomes reported.

## Limits

The evaluated models and benchmarks predate current agent models and do not
include an interpreted task language. Several transformations change more than
length, so ReCode does not isolate the causal effect of short identifiers.

## Derived notes

- [Token-efficient syntax for A-Lang](../20-notes/token-efficient-syntax-for-a-lang.md)
- [Can a compact projection reduce A-Lang token use without reducing fidelity?](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
- [Token-efficient A-Lang syntax](../10-maps/token-efficient-alang-syntax.md)
