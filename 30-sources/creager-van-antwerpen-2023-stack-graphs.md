---
title: "Stack Graphs: Name Resolution at Scale"
kind: source
created: 2026-08-07
authors:
  - "Douglas A. Creager"
  - "Hendrik van Antwerpen"
published: 2023
citation_key: "creager-van-antwerpen-2023-stack-graphs"
container: "Eelco Visser Commemorative Symposium (EVCS 2023)"
edition: null
isbn: "978-3-95977-267-9"
doi: "10.4230/OASIcs.EVCS.2023.8"
url: "https://doi.org/10.4230/OASIcs.EVCS.2023.8"
accessed: 2026-08-07
tags:
  - code-graphs
  - code-navigation
  - incremental-analysis
  - name-resolution
  - software-evolution
aliases:
  - "Stack Graphs"
---

# Stack Graphs: Name Resolution at Scale

## Reference

Douglas A. Creager and Hendrik van Antwerpen. “Stack Graphs: Name Resolution
at Scale.” *Eelco Visser Commemorative Symposium (EVCS 2023)*, article 8,
pages 8:1–8:12. [DOI](https://doi.org/10.4230/OASIcs.EVCS.2023.8).

## Method

Stack graphs encode definitions, references, scopes, and name-binding rules as
graph nodes and paths. Each source file produces a disjoint subgraph using a
purely syntactic, declarative tree-sitter-graph analysis. Cross-file name
resolution is performed with virtual edges and a stack-based path search at
query time rather than by persisting eager cross-file edges during indexing.

The implementation also precomputes reusable partial paths within individual
files. A previously analyzed file version can therefore reuse its subgraph and
partial paths; a changed file can be rebuilt without reconstructing every
unchanged file.

## Findings

- File-isolated subgraphs preserve incrementality while still supporting
  cross-file and type-dependent name resolution at query time.
- The split between index-time subgraph construction and query-time path
  assembly amortizes both parsing and substantial parts of path finding.
- The paper reports that Stack Graphs had analyzed every commit to GitHub's
  public and private Python repositories in production since November 2021.

## Relevance

Stack Graphs is direct evidence that “constructed by language analysis” need
not mean “rebuilt only by a whole-project compilation.” Stable per-file graph
fragments can be reused across source versions while revision-sensitive paths
are assembled on demand. For A-Lang, this supports separating the compiler's
authority over derived facts from the live update cadence required by an
editing agent.

It also motivates a verified-base-plus-working-delta design: immutable graph
fragments for unchanged content can remain valid, while edits invalidate and
replace only affected fragments before queries are served for a new workspace
revision. That A-Lang design is an inference from the paper, not a result the
paper evaluates.

## Limits

The graph represents name binding, not general call, control-flow, data-flow,
effect, test, or authored semantic relations. Its file-isolation property may
not transfer to analyses whose facts inherently depend on other files. The
production unit described by the paper is a committed file version, not an
unsaved or temporarily malformed editing buffer. The paper does not evaluate
LLM agents, semantic claims, graph freshness during multi-step edits, or an
atomic consistency protocol between writes and queries.

## Derived notes

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
