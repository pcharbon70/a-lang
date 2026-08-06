---
title: "Can Semantic Code Graphs Improve LLM Understanding?"
kind: inquiry
created: 2026-08-06
status: open
tags:
  - code-graphs
  - code-understanding
  - knowledge-graphs
  - llm-agents
aliases:
  - "Do semantic knowledge graphs help agents understand code?"
---

# Can Semantic Code Graphs Improve LLM Understanding?

## Why this matters

Typed references give an agent exact destinations, but many repository questions
concern paths rather than individual targets: what flows into this value, which
effect reaches this handler, why a component exists, what contract it implements,
and which tests or decisions support that claim. A graph can represent and query
those paths directly.

A semantic knowledge graph could add relationships that syntax and static
analysis cannot derive. It could also turn uncertain design statements into
apparently authoritative facts, grow stale, overwhelm prompts, or create a
second semantics that disagrees with the language. The graph layer, authored
semantic layer, and inline source syntax each need independent evidence.

## Operational question

On unseen repository revisions, does a revision-bound typed graph improve an
LLM agent’s grounded answers and verified edits relative to a generated flat
symbol map when facts, context budget, model, tools, and runtime policy are held
constant?

If it does, do provenance-bearing authored relations such as `specified_by`,
`tested_by`, `invariant_of`, and `rationale_for` add a further benefit beyond
compiler-derived structure? If that layer also wins, does writing the same
claims inline improve agent authoring and maintenance relative to an equivalent
sidecar manifest?

## Provisional answer

Probably for the graph query layer, especially on multi-hop location, impact,
control-flow, and data-flow tasks. The evidence is strongest when graph
structure is used to select or encode context and weakest when the full graph is
serialized as ordinary prompt text.

The authored semantic layer is plausible but unproven. Existing semantic
software graphs show expressive queries and promising repository answers, but
they do not isolate semantic relations from added facts, LLM extraction,
retrieval machinery, or token cost. There is currently no evidence that inline
placement is necessary.

## Working hypotheses

1. Bounded path and impact queries will improve exact evidence retrieval over a
   flat symbol map on genuinely multi-hop tasks.
2. Derived graph queries will not improve simple definition-location tasks
   enough to justify their extra cost.
3. The graph will help mainly before prompting, by selecting compact evidence;
   full graph text will perform worse at the same byte budget.
4. Directional control-, data-, call-, type-, and effect-relation labels will
   contribute differently by task and model family.
5. Authored relations will add value only for non-inferable intent and will be
   neutral or harmful when they duplicate compiler facts.
6. Provenance and truth status will reduce unsupported use of extracted or stale
   semantic claims, but only if agents are trained or prompted to consult them.
7. False, reversed, or stale edges will cause confident wrong answers unless
   contradiction and evidence queries are first-class.
8. Inline declarations and sidecar claims will read equivalently after
   compilation; any inline advantage will appear in agent authoring, refactoring,
   and review rather than answer quality.
9. One-hop selective traversal will outperform recursive expansion under fixed
   budgets.
10. Runtime semantic reflection will add no necessary benefit to static code
    understanding and will introduce unrelated safety and semantic costs.

## Paths to explore

- Define graph node and edge identities over the existing typed task IR.
- Generate containment, definition, occurrence, call, data-flow, type, effect,
  and test-discovery facts in the BEAM compiler path.
- Implement deterministic `neighbors`, `path`, `impact`, `evidence`,
  `explain_edge`, and `conflicts` queries with strict bounds.
- Construct equal-fact flat-map, edge-table, graph-query, and graph-text
  conditions.
- Define a closed authored predicate vocabulary with domain, range, direction,
  inference, provenance, and lifecycle rules.
- Represent compiler facts, authored claims, imported claims, observations, and
  task-local model inferences as distinct origins.
- Mutate labels, direction, topology, targets, revisions, and evidence to test
  whether agents actually follow the graph.
- Compare an external claim manifest with identical claims compiled from a
  minimal source declaration.
- Test graph reconstruction and reference repair across renames, moves, merges,
  and materially changed definitions.
- Seed source and semantic descriptions with prompt injection and verify that
  graph content cannot change action authority.

This inquiry remains separate from the frozen [effectful source fidelity
plan](../60-planning/02-effectful-source-fidelity/README.md). That experiment
tests task representation, not repository context or graph navigation.

## Findings

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
  separates graph facts, topology, relation semantics, presentation, and source
  ownership and proposes a layered A-Lang design.
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
  organizes the evidence by derived analysis, model integration, repository
  retrieval, semantic knowledge, and language embedding.
- [Code property graphs](../30-sources/yamaguchi-et-al-2014-code-property-graphs.md)
  show that combined syntax, control, and data relations support useful queries,
  while intended design remains outside static derivation.
- [GraphCodeBERT](../30-sources/guo-et-al-2021-graphcodebert.md),
  [GREAT](../30-sources/hellendoorn-et-al-2020-global-relational-models.md), and
  [CGBridge](../30-sources/chen-et-al-2026-cgbridge.md) support graph structure
  in trained or bridged models; CGBridge’s graph-text failures block a simple
  prompt-serialization conclusion.
- [GraphCoder](../30-sources/liu-et-al-2024-graphcoder.md),
  [RepoGraph](../30-sources/ouyang-et-al-2025-repograph.md), and
  [CodexGraph](../30-sources/liu-et-al-2025-codexgraph.md) support graph-aware
  retrieval and tool use, with important confounds from added facts, query
  agents, action spaces, and token cost.
- [Talk Like a Graph](../30-sources/fatemi-et-al-2024-talk-like-a-graph.md)
  shows that a graph’s text encoding, question phrasing, topology, omissions,
  and distractors materially change black-box LLM performance.
- [CodeOntology](../30-sources/atzeni-atzori-2017-codeontology.md) establishes
  scalable ontology-backed source queries but not an understanding outcome.
- [CODENS](../30-sources/kelious-et-al-2026-codens.md) is encouraging evidence
  for living semantic software memory, but it lacks a retrieval-mode control and
  validation of extracted semantic truth.
- [GraphRAG](../30-sources/edge-et-al-2024-graphrag.md) supports multi-scale
  global retrieval, while its second evaluation does not separate graph topology
  from strong graph-free summarization.
- [Semantically Reflected Programs](../30-sources/kamburjan-et-al-2026-semantically-reflected-programs.md)
  shows that runtime graph embedding changes typing, consistency, performance,
  and object lifetime; that feature is outside the present need.

## Decision criteria

Use a staged gate rather than one all-or-nothing decision:

1. **Derived graph gate:** graph queries beat the flat map by at least five
   absolute points on the pre-registered multi-hop primary score under equal
   facts and context budgets, with positive paired confidence intervals across
   declared model families.
2. **Semantic claim gate:** true authored claims add a further repeatable gain
   over the derived graph and do not increase unsupported-edge, stale-evidence,
   privacy, or prompt-injection failures.
3. **Inline syntax gate:** agents create, repair, and review valid inline claims
   more reliably or cheaply than equivalent sidecar claims, while producing the
   same compiled graph.

Safety violations veto promotion. A graph-text-only win does not justify a
query layer, a trained-bridge-only win does not justify language syntax, and a
query-layer win does not justify runtime semantic reflection.

## Outcome

The inquiry remains open. Current evidence justifies prototyping a generated,
read-only graph and controlled query experiment. It does not yet justify an
authored semantic ontology in accepted A-Lang source. No grammar, compiler,
runtime, or API change and no hosted model evaluation has been made.

## Connections

- [Can typed source references improve LLM code understanding?](can-typed-source-references-improve-llm-code-understanding.md)
  supplies the preceding exact-target and generated-map comparison.
- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
  provides the symbol, projection, provenance, and context-safety foundation.
