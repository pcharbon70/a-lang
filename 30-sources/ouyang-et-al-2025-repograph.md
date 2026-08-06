---
title: "RepoGraph: Enhancing AI Software Engineering with Repository-Level Code Graph"
kind: source
created: 2026-08-05
authors:
  - "Siru Ouyang"
  - "Wenhao Yu"
  - "Kaixin Ma"
  - "Zilin Xiao"
  - "Zhihan Zhang"
  - "Mengzhao Jia"
  - "Jiawei Han"
  - "Hongming Zhang"
  - "Dong Yu"
published: 2025
citation_key: "ouyang-et-al-2025-repograph"
container: "The Thirteenth International Conference on Learning Representations"
edition: null
isbn: null
doi: null
url: "https://openreview.net/forum?id=dw9VUsSHGB"
accessed: 2026-08-05
tags:
  - code-graphs
  - repository-level-code
  - software-engineering-agents
aliases:
  - "RepoGraph"
---

# RepoGraph: Enhancing AI Software Engineering with Repository-Level Code Graph

## Reference

Siru Ouyang et al. “RepoGraph: Enhancing AI Software Engineering with
Repository-Level Code Graph.” *ICLR 2025*. [OpenReview](https://openreview.net/forum?id=dw9VUsSHGB).

## Method

RepoGraph parses Python with tree-sitter and builds a line-oriented graph whose
nodes carry definition or reference metadata. `invoke` and `contain` edges
connect project-specific elements. A system can flatten a bounded ego graph
into the prompt or let an agent call a graph-search tool. The authors add the
module to RAG, Agentless, AutoCodeRover, and SWE-agent on SWE-bench Lite, then
also evaluate it on Python CrossCodeEval.

## Findings

- RepoGraph improves all four SWE-bench Lite systems in the reported runs:
  resolve rates move from 2.67 to 5.33 for basic RAG, 27.33 to 29.67 for
  Agentless, 19.00 to 21.33 for AutoCodeRover, and 18.33 to 20.33 for
  SWE-agent.
- File- and function-localization measures improve, supporting structured
  navigation even where end-to-end repair gains are modest.
- Larger neighborhoods are not automatically better. A flattened two-hop
  graph averages roughly 10,500 tokens and performs below the no-RepoGraph
  Agentless baseline; the one-hop form is best in that comparison.

## Relevance

RepoGraph supports typed graph edges and task-local neighborhoods as a context
interface. It also warns against recursive expansion by default: edge types,
depth, fan-out, and bytes all need explicit bounds.

## Limits

The primary graph is Python-specific and parser-derived, and the SWE-bench
improvements are small in absolute terms for several systems. Wrong
localization, context misalignment, and regressive patches remain. The study
does not establish that relationships should be embedded in source rather than
generated as a revision-specific sidecar.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
