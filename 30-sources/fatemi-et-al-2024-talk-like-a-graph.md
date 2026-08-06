---
title: "Talk Like a Graph: Encoding Graphs for Large Language Models"
kind: source
created: 2026-08-06
authors:
  - "Bahare Fatemi"
  - "Jonathan Halcrow"
  - "Bryan Perozzi"
published: 2024
citation_key: "fatemi-et-al-2024-talk-like-a-graph"
container: "The Twelfth International Conference on Learning Representations"
edition: null
isbn: null
doi: null
url: "https://proceedings.iclr.cc/paper_files/paper/2024/hash/bf72f65f30eedf5d48da6980ee02b589-Abstract-Conference.html"
accessed: 2026-08-06
tags:
  - graph-reasoning
  - graph-serialization
  - large-language-models
  - representation-design
aliases:
  - "Talk Like a Graph"
---

# Talk Like a Graph: Encoding Graphs for Large Language Models

## Reference

Bahare Fatemi, Jonathan Halcrow, and Bryan Perozzi. “Talk Like a Graph:
Encoding Graphs for Large Language Models.” *ICLR 2024*.
[ICLR proceedings](https://proceedings.iclr.cc/paper_files/paper/2024/hash/bf72f65f30eedf5d48da6980ee02b589-Abstract-Conference.html).

## Method

The paper converts synthetic graphs into text and tests black-box PaLM-family
models on adjacency, connectivity, shortest path, cycle, degree, and
disconnected-node questions. It varies node names, edge phrasing, graph
serialization, question wording, prompting, model size, and graph topology.

## Findings

- Choosing an encoding suited to a task changes accuracy by 4.8 to 61.8
  percentage points across the reported comparisons. Incident-list phrasing is
  often strong but is not universally best.
- Rephrasing one edge-existence question in an application-oriented form raises
  PaLM 2 XXS accuracy from 42.8% to 60.8% with the graph held constant.
- Cycle detection reaches 91.7% on complete graphs and 5.9% on path graphs.
  Adding examples raises the path result but does not remove the topology bias.
- Disconnected-node accuracy is near zero when the serialization omits explicit
  statements for isolated nodes, and distracting edge statements reduce
  performance on several tasks.

## Relevance

The study demonstrates that graph semantics are not invariant under textual
rendering for an LLM. An A-Lang graph interface therefore needs query-specific,
deterministic projections and must test ordering, labels, omissions, and
distractors. “The model has all the triples” is not an adequate control.

## Limits

The graphs are small, synthetic, non-code, and mostly untyped. The work studies
prompt representation rather than retrieval, software maintenance, knowledge
graph truth, or source embedding. It supplies a boundary condition, not direct
evidence that a code graph improves repository understanding.

## Derived notes

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
