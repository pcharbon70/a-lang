---
title: "CodexGraph: Bridging Large Language Models and Code Repositories via Code Graph Databases"
kind: source
created: 2026-08-06
authors:
  - "Xiangyan Liu"
  - "Bo Lan"
  - "Zhiyuan Hu"
  - "Yang Liu"
  - "Zhicheng Zhang"
  - "Fei Wang"
  - "Michael Qizhe Shieh"
  - "Wenmeng Zhou"
published: 2025
citation_key: "liu-et-al-2025-codexgraph"
container: "Proceedings of the 2025 Conference of the Nations of the Americas Chapter of the Association for Computational Linguistics: Human Language Technologies"
edition: null
isbn: "979-8-89176-189-6"
doi: "10.18653/v1/2025.naacl-long.7"
url: "https://aclanthology.org/2025.naacl-long.7/"
accessed: 2026-08-06
tags:
  - code-graphs
  - graph-databases
  - repository-level-code
  - software-engineering-agents
aliases:
  - "CodexGraph"
---

# CodexGraph: Bridging Large Language Models and Code Repositories via Code Graph Databases

## Reference

Xiangyan Liu et al. “CodexGraph: Bridging Large Language Models and Code
Repositories via Code Graph Databases.” *NAACL 2025*, 142–160.
[ACL Anthology](https://aclanthology.org/2025.naacl-long.7/).

## Method

CodexGraph indexes Python modules, classes, methods, functions, fields, and
global variables in Neo4j. Typed edges express containment, inheritance,
membership, and use. A primary agent writes a natural-language retrieval
request; a second LLM translates it into Cypher, executes it, and returns code
references or structure for completion, issue repair, and generation tasks.

## Findings

- With GPT-4o, CrossCodeEval Lite exact match is 27.90 versus 21.20 for BM25
  and 21.20 for AutoCodeRover. SWE-bench Lite Pass@1 is 22.96, tied with
  AutoCodeRover; EvoCodeBench Pass@1 is 36.02 versus 28.78.
- Removing edges reduces GPT-4o CrossCodeEval exact match from 27.90 to 16.40
  and DeepSeek-Coder from 20.20 to 14.50, but has almost no effect for the weak
  Qwen2 condition. Removing the query-translation agent causes an even larger
  drop.
- Average GPT-4o input cost is 22.16k tokens on CrossCodeEval and 102.25k on
  SWE-bench, compared with BM25’s 1.47k and 14.76k respectively.

## Relevance

CodexGraph supports a graph as an addressable agent tool: the model requests a
relation-aware view instead of receiving every node and edge. It also shows
that usefulness depends on query formulation, model capability, and result
control—not graph availability alone.

## Limits

The edge ablation removes both topology and retrievable facts, so it is not an
equal-information comparison with a flat index. The system bundles graph
construction, a second LLM, Cypher, and repeated agent calls. It is evaluated
only on Python, lacks call edges, has high and sometimes uncontrolled token
cost, and warns that scanning a whole repository creates privacy risk. No
authored semantic claims or inline source syntax are tested.

## Derived notes

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
