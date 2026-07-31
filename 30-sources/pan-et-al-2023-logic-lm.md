---
title: "Logic-LM: Empowering Large Language Models with Symbolic Solvers for Faithful Logical Reasoning"
kind: source
created: 2026-07-30
authors:
  - "Liangming Pan"
  - "Alon Albalak"
  - "Xinyi Wang"
  - "William Wang"
published: 2023
citation_key: pan2023LogicLM
doi: "10.18653/v1/2023.findings-emnlp.248"
url: "https://aclanthology.org/2023.findings-emnlp.248/"
accessed: 2026-07-30
tags:
  - symbolic-reasoning
  - formal-specification
  - external-feedback
aliases:
  - "Logic-LM"
---

# Logic-LM: Empowering Large Language Models with Symbolic Solvers for Faithful Logical Reasoning

## Reference

Liangming Pan, Alon Albalak, Xinyi Wang, and William Wang.
“Logic-LM: Empowering Large Language Models with Symbolic Solvers for Faithful
Logical Reasoning.” Findings of EMNLP 2023.
[Paper](https://aclanthology.org/2023.findings-emnlp.248/)

## Method

Logic-LM separates problem formulation, symbolic inference, result
interpretation, and repair. The LLM maps natural language into one of several
symbolic representations; a deterministic solver performs inference; and solver
error messages feed a self-refinement stage when the formalization is invalid.

## Finding

On five logical-reasoning datasets, the reported average improvement was 39.2%
over standard prompting and 18.4% over chain-of-thought prompting.

## Relevance

The design supplies a practical compiler pattern for an agent task language:
parse, type-check or solve, return precise diagnostics, and let the model repair
the smallest invalid fragment. External diagnostic feedback has a clearer basis
than asking an LLM to reconsider its answer without new evidence.

## Limits

Formalization errors remain the central bottleneck. The results concern logical
question answering rather than open-ended, stateful tool use, and different
domains require different representations and solvers.
