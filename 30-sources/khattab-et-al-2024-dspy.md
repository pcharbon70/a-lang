---
title: "DSPy: Compiling Declarative Language Model Calls into State-of-the-Art Pipelines"
kind: source
created: 2026-07-30
authors:
  - "Omar Khattab"
  - "Arnav Singhvi"
  - "Paridhi Maheshwari"
  - "Zhiyuan Zhang"
  - "Keshav Santhanam"
  - "Sri Vardhamanan"
  - "Saiful Haq"
  - "Ashutosh Sharma"
  - "Thomas T. Joshi"
  - "Hanna Moazam"
  - "Heather Miller"
  - "Matei Zaharia"
  - "Christopher Potts"
published: 2024
citation_key: khattab2024DSPy
url: "https://openreview.net/forum?id=sY5N0zY5Od"
accessed: 2026-07-30
tags:
  - declarative-programming
  - prompt-optimization
  - language-model-pipelines
aliases:
  - "DSPy"
---

# DSPy: Compiling Declarative Language Model Calls into State-of-the-Art Pipelines

## Reference

Omar Khattab et al. “DSPy: Compiling Declarative Language Model Calls into
State-of-the-Art Pipelines.” ICLR 2024.
[Paper](https://openreview.net/forum?id=sY5N0zY5Od)

## Contribution

DSPy represents language-model operations as declarative modules with
natural-language typed signatures. A compiler searches or bootstraps prompts,
demonstrations, and other parameters to maximize a developer-supplied metric,
instead of requiring every prompt string to be hand-written.

## Finding

In the paper’s two case studies, compact DSPy programs bootstrapped pipelines
that outperformed standard few-shot prompting and pipelines using
expert-created demonstrations.

## Relevance

The task language can define a semantic interface and an evaluation contract
while a compiler adapts its prompt realization to different models. This argues
against making literal prompt wording the language’s stable semantics.

## Limits

Optimization is only as good as the metric and examples supplied. A pipeline can
overfit an incomplete evaluator, and natural-language “types” do not provide the
same guarantees as machine-checked algebraic or refinement types.
