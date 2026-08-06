---
title: "Semantically Reflected Programs"
kind: source
created: 2026-08-06
authors:
  - "Eduard Kamburjan"
  - "Vidar Norstein Klungre"
  - "Yuanwei Qu"
  - "Rudolf Schlatte"
  - "Egor V. Kostylev"
  - "Martin Giese"
  - "Einar Broch Johnsen"
published: 2026
citation_key: "kamburjan-et-al-2026-semantically-reflected-programs"
container: "Transactions on Graph Data and Knowledge"
edition: null
isbn: null
doi: "10.4230/TGDK.4.1.3"
url: "https://drops.dagstuhl.de/entities/document/10.4230/TGDK.4.1.3"
accessed: 2026-08-06
tags:
  - knowledge-graphs
  - programming-languages
  - semantic-reflection
  - type-safety
aliases:
  - "SMOL semantic reflection"
---

# Semantically Reflected Programs

## Reference

Eduard Kamburjan et al. “Semantically Reflected Programs.” *Transactions on
Graph Data and Knowledge* 4(1), 3:1–3:52, 2026.
[Dagstuhl](https://drops.dagstuhl.de/entities/document/10.4230/TGDK.4.1.3).

## Method

The paper formalizes semantic lifting for SMOL, a small object-oriented
imperative language. A runtime configuration—including objects, fields, and
selected static program facts—is mapped to an RDF knowledge graph and linked
to a domain ontology. Source constructs such as `hidden`, `domain`, and `links`
control exposure and correspondence. Programs can query the lifted state with
SPARQL, OWL membership, or SHACL validation.

The type system addresses unrepresentable query results, assignment-type
failures, and inconsistent lifted graphs. Under its assumptions, every
reachable configuration of a well-typed program lifts to a consistent graph.
Large dynamic structures are exposed virtually: matching triples are generated
on demand instead of materializing the complete heap.

## Findings and design experience

- Domain linkage and typed queries provide an explicit interface between
  executable behavior and application-domain knowledge.
- The implementation removed computational lifting that executed arbitrary
  pure methods because it scaled poorly. It also stopped lifting the call stack
  because applications rarely needed it and the graph was too large.
- Virtualization reduces materialization cost, but the current setup does not
  combine well with reasoners that require the complete graph.
- Query results can depend on garbage collection unless reachability and object
  lifetime are defined carefully. The reference implementation avoids an
  automatic collector and offers explicit destruction.
- The static type result does not cover all domain-linkage cases; deeper guard
  analysis is left for future work.

## Relevance

This is the strongest example here of knowledge-graph concepts becoming part
of a programming language rather than an external index. It demonstrates that
semantic reflection is a semantic and safety feature, not merely richer
documentation. For the narrower goal of helping LLM agents read code, A-Lang
should initially avoid runtime reflection: compile non-executable authored
claims into a read-only revision graph and keep them outside effects,
capabilities, object reachability, and program control flow.

## Limits

The paper studies runtime application-domain state, not static repository
understanding or LLMs. Its case studies demonstrate uses of semantic reflection
but do not compare agent comprehension with and without inline relations. SMOL
also depends on Java semantic-web tooling; those implementation choices cannot
enter A-Lang’s trusted BEAM compiler path.

## Derived notes

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
