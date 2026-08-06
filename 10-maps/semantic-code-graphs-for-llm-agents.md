---
title: "Semantic Code Graphs for LLM Agents"
kind: map
created: 2026-08-06
tags:
  - code-graphs
  - code-understanding
  - knowledge-graphs
  - llm-agents
aliases:
  - "Knowledge graphs for agent-readable code"
---

# Semantic Code Graphs for LLM Agents

## Scope

This map follows the continuation from exact source references to graphs of
repository relationships. It distinguishes compiler-derived program facts,
graph-aware model integration, graph-based retrieval, authored semantic claims,
and runtime semantic reflection.

## Starting points

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
  — the evidence synthesis, layered A-Lang graph, trust boundary, and staged
  experiment.
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
  — the open causal questions and separate promotion gates.
- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
  — the preceding case for exact identities, projections, provenance, and a
  generated-map baseline.

## Trail 1: Derive relationships before authoring them

- [Code property graphs](../30-sources/yamaguchi-et-al-2014-code-property-graphs.md)
  show why syntax, control flow, and data dependence are more useful when
  overlaid and queried together. Their inability to recover intended design
  defines the narrow opening for authored semantics.
- [GraphCodeBERT](../30-sources/guo-et-al-2021-graphcodebert.md) supports compact
  data-flow structure as a learned code representation.
- [GREAT](../30-sources/hellendoorn-et-al-2020-global-relational-models.md)
  combines global sequence processing with typed code relations and preserves
  the important synthetic-to-real performance gap.

## Trail 2: Use the graph to select context

- [GraphCoder](../30-sources/liu-et-al-2024-graphcoder.md) retrieves source with
  bounded statement-level control- and data-dependence slices.
- [RepoGraph](../30-sources/ouyang-et-al-2025-repograph.md) improves several
  repository agents while showing that a large two-hop graph can perform below
  the no-graph baseline.
- [CodexGraph](../30-sources/liu-et-al-2025-codexgraph.md) exposes a graph
  database as agent operations and shows both sizable gains and high query/token
  overhead.

Together these works support read-only `neighbors`, `path`, `impact`, and
`evidence` operations more strongly than unconditional graph inclusion.

## Trail 3: Do not assume a textual graph preserves topology

- [CGBridge](../30-sources/chen-et-al-2026-cgbridge.md) obtains strong results
  through a learned graph-to-prefix bridge, while ordinary GraphText prompting
  often degrades functional accuracy.
- [Talk Like a Graph](../30-sources/fatemi-et-al-2024-talk-like-a-graph.md) shows
  that encoding, question wording, topology, omissions, and distractors can
  change black-box LLM graph reasoning dramatically.

These are different kinds of evidence, but they agree on one boundary: the
graph should have task-specific projections, deterministic ordering, and an
equal-budget text baseline.

## Trail 4: Separate an ontology from evidence that it helps

- [CodeOntology](../30-sources/atzeni-atzori-2017-codeontology.md) demonstrates
  large-scale RDF extraction and expressive SPARQL over Java, but evaluates
  feasibility rather than understanding.
- [CODENS](../30-sources/kelious-et-al-2026-codens.md) adds intent-like
  descriptions, change history, typed relationships, and provenance to a living
  repository graph. Its preliminary evaluation does not compare retrieval modes
  or validate the extracted semantics against behavior.
- [GraphRAG](../30-sources/edge-et-al-2024-graphrag.md) supplies a non-code
  example of multi-scale graph summaries for global questions and evidence that
  a strong graph-free hierarchy can be competitive.

This trail motivates claim provenance, contradiction checks, and a direct test
of authored semantics beyond compiler facts.

## Trail 5: Keep static context separate from runtime reflection

- [Semantically Reflected Programs](../30-sources/kamburjan-et-al-2026-semantically-reflected-programs.md)
  formalizes a language whose runtime state is lifted into a knowledge graph and
  queried from the program. Its typing, consistency, performance, virtualization,
  and garbage-collection consequences show why this is a separate feature.

For A-Lang’s present question, the graph remains revision-bound, read-only
repository data. It cannot change effects, capabilities, control flow, or
runtime reachability.

## Local A-Lang trail

- The [typed task IR](../src/phase-02/typed-task-ir.md) is the starting point for
  compiler-owned node identities and source origins.
- The [context slicer](../src/phase-06/task-orchestration-and-context.md) is the
  materialization boundary for visibility, provenance, trust, and byte budgets.
- The [symbol-aware context map](symbol-aware-code-context-for-llm-agents.md)
  covers exact targets, generated repository maps, and security constraints.
- The [effectful source fidelity plan](../60-planning/02-effectful-source-fidelity/README.md)
  is a separate frozen experiment and cannot answer the graph question.

The trusted graph extractor, validator, and query layer must compile to BEAM and
run on ERTS. External graph stores or semantic-web tools can only be optional
untrusted caches or export targets.

## Open questions

- Does a bounded graph query beat an equal-fact flat edge table, or does it only
  retrieve additional information?
- Which edge families help location, explanation, impact, and verified edits?
- Do natural-language predicate labels matter after exact endpoints and source
  projections are controlled?
- Can an agent distinguish a compiler fact from a human claim, an imported
  claim, a test observation, and its own task-local inference?
- How should contradictions and materially stale authored claims be surfaced
  without making the whole graph unusable?
- Can agents maintain semantic relations through ordinary refactors?
- Does inline ownership improve maintenance over an identical sidecar graph?
- Which graph projections retain value under strict context and privacy bounds?
