---
title: "GraphCoder: Enhancing Repository-Level Code Completion via Coarse-to-Fine Retrieval Based on Code Context Graph"
kind: source
created: 2026-08-06
authors:
  - "Wei Liu"
  - "Ailun Yu"
  - "Daoguang Zan"
  - "Bo Shen"
  - "Wei Zhang"
  - "Haiyan Zhao"
  - "Zhi Jin"
  - "Qianxiang Wang"
published: 2024
citation_key: "liu-et-al-2024-graphcoder"
container: "Proceedings of the 39th IEEE/ACM International Conference on Automated Software Engineering"
edition: null
isbn: null
doi: "10.1145/3691620.3695054"
url: "https://arxiv.org/abs/2406.07003"
accessed: 2026-08-06
tags:
  - code-completion
  - code-graphs
  - repository-level-code
  - retrieval-augmented-generation
aliases:
  - "GraphCoder"
---

# GraphCoder: Enhancing Repository-Level Code Completion via Coarse-to-Fine Retrieval Based on Code Context Graph

## Reference

Wei Liu et al. “GraphCoder: Enhancing Repository-Level Code Completion via
Coarse-to-Fine Retrieval Based on Code Context Graph.” *ASE 2024*, 570–581.
[DOI](https://doi.org/10.1145/3691620.3695054).

## Method

GraphCoder constructs a statement-level multigraph with control-flow,
control-dependence, and data-dependence edges. For each statement it stores a
bounded graph slice and nearby source. Retrieval first performs a coarse
lexical search, then reranks candidates using graph edit distance and a
distance-decay term before supplying source snippets to an LLM.

The study evaluates 8,000 line- and API-completion tasks from 20 Python and
Java repositories using six model configurations.

## Findings

- Relative to the evaluated retrieval baselines, the paper reports average
  gains of 6.06 points in code exact match and 6.23 points in identifier exact
  match.
- In the GPT-3.5 ablation, Python line-level code exact match is 46.60 for the
  full graph, 39.15 without control flow, 42.05 without data dependence, and
  41.70 without control dependence. On Java API completion the corresponding
  values are 61.57, 42.06, 56.62, and 56.36.
- The statement-level index uses fewer entries and similar generation tokens
  than the other one-pass RAG methods; iterative RepoCoder consumes much more
  context in the reported comparison.

## Relevance

This is direct evidence that a query-time program graph can improve the
selection of repository context for a black-box LLM. It favors bounded slices
and graph-aware ranking over dumping the graph itself into the prompt.

## Limits

Removing an edge family also removes information and changes the retrieval
algorithm, so the ablation does not isolate topology from an equal-information
flat representation. The task is completion, the languages are Python and
Java, and the graph is derived rather than authored. Retrieval also assumes
that a repository contains reusable, sufficiently similar snippets; the paper
identifies low duplication as a possible recall risk even though GraphCoder
often gains more than baselines in the lower-duplication subset.

## Derived notes

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
