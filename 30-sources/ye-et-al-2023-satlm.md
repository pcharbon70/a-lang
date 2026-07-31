---
title: "SatLM: Satisfiability-Aided Language Models Using Declarative Prompting"
kind: source
created: 2026-07-30
authors:
  - "Xi Ye"
  - "Qiaochu Chen"
  - "Isil Dillig"
  - "Greg Durrett"
published: 2023
citation_key: ye2023SatLM
doi: "10.52202/075280-1974"
url: "https://proceedings.neurips.cc/paper_files/paper/2023/hash/8e9c7d4a48bdac81a58f983a64aaf42b-Abstract-Conference.html"
accessed: 2026-07-30
tags:
  - declarative-specification
  - symbolic-reasoning
  - constraint-solving
aliases:
  - "SatLM"
---

# SatLM: Satisfiability-Aided Language Models Using Declarative Prompting

## Reference

Xi Ye, Qiaochu Chen, Isil Dillig, and Greg Durrett.
“SatLM: Satisfiability-Aided Language Models Using Declarative Prompting.”
NeurIPS 2023.
[Paper](https://proceedings.neurips.cc/paper_files/paper/2023/hash/8e9c7d4a48bdac81a58f983a64aaf42b-Abstract-Conference.html)

## Method

The LLM translates a natural-language problem into a declarative set of logical
constraints. An automated theorem prover performs search and derives the answer.
The model therefore specifies what must hold rather than generating an
imperative solution procedure.

## Finding

Across eight datasets, SatLM consistently outperformed imperative program-aided
language-model baselines. It reported a 23% advantage on a challenging GSM
subset and new state-of-the-art results on LSAT and BoardgameQA at publication
time. The authors attribute the gain to the declarative representation being
closer to the problem statement and the solver eliminating execution and search
errors relative to the parsed specification.

## Relevance

This is the strongest evidence in the reading set for making task intent
declarative. An agent language should privilege goals, facts, invariants, and
constraints over a model-generated sequence of steps whenever a runtime can
plan or verify the rest.

## Limits

The solver guarantees correctness only with respect to the translated
specification. A fluent but semantically wrong translation remains a failure.
The benchmark domains are substantially more formal and closed than general
research or software-engineering tasks.
