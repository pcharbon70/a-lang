---
title: "CGBridge: Bridging Code Graphs and Large Language Models for Better Structure-Aware Code Understanding"
kind: source
created: 2026-08-06
authors:
  - "Zeqi Chen"
  - "Zhaoyang Chu"
  - "Yi Gui"
  - "Feng Guo"
  - "Yao Wan"
  - "Chuan Shi"
published: 2026
citation_key: "chen-et-al-2026-cgbridge"
container: "Findings of the Association for Computational Linguistics: ACL 2026"
edition: null
isbn: "979-8-89176-395-1"
doi: "10.18653/v1/2026.findings-acl.434"
url: "https://aclanthology.org/2026.findings-acl.434/"
accessed: 2026-08-06
tags:
  - code-graphs
  - code-understanding
  - graph-text-alignment
  - representation-learning
aliases:
  - "CGBridge"
---

# CGBridge: Bridging Code Graphs and Large Language Models for Better Structure-Aware Code Understanding

## Reference

Zeqi Chen et al. “CGBridge: Bridging Code Graphs and Large Language Models for
Better Structure-Aware Code Understanding.” *Findings of ACL 2026*,
8945–8966. [ACL Anthology](https://aclanthology.org/2026.findings-acl.434/).

## Method

CGBridge builds code property graphs with AST, control-flow, and data-flow
relations. A graph encoder and a trainable bridge compress graph information
into a 32-token soft prefix for a frozen decoder LLM. The authors train on about
270,000 code-graph pairs and evaluate summarization, translation, execution
understanding, identifier obfuscation, and several model families. GraphText,
which serializes graph information as ordinary prompt text, is a baseline.

## Findings

- On Qwen2.5-Coder-7B, summarization LLM-judge scores are 2.78 for the base,
  2.98 for LoRA, 2.96 for GraphText, and 3.23 for CGBridge. Translation
  execution accuracy is 89.46, 97.21, 70.75, and 98.26 respectively.
- GraphText is actively harmful in several settings: for Qwen 1.5B,
  translation execution accuracy falls from 70.63 to 57.26, while CGBridge
  reaches 89.01.
- In the Qwen 7B graph ablation, execution accuracy is 93.12 with AST alone,
  94.53 with AST and control flow, 97.39 with AST and data flow, 91.57 with
  control plus data flow, and 98.26 with the full graph.
- Identifier renaming reduces the Qwen 7B summarization judge score by 0.3% for
  CGBridge, versus 15.1% for LoRA and 28.4% for GraphText.

## Relevance

This source provides unusually direct negative evidence against “put the graph
in the prompt.” The strongest result needs a learned cross-modal bridge, while
the plain text graph can be worse than no graph. For a hosted A-Lang agent, the
actionable analogue is a compact, task-specific projection or query result—not
an assumption that an arbitrary triple dump preserves graph semantics.

## Limits

CGBridge changes training and adds a 180.8-million-parameter module. Its
reported 371 ms inference figure excludes roughly 281 ms per sample for offline
graph construction and the embedding step. Static analysis requires parseable
snippets, gains are smaller on short or structurally sparse code, and part of
the evaluation uses an automated judge. It does not test repositories, authored
relations, inline syntax, or unmodified black-box APIs.

## Derived notes

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
