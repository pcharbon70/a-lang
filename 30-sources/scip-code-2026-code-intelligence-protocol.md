---
title: "SCIP Code Intelligence Protocol"
kind: source
created: 2026-08-05
authors:
  - "SCIP Code Intelligence Protocol contributors"
published: null
citation_key: "scip-code-2026-code-intelligence-protocol"
container: "scip-code/scip"
edition: "scip.proto at 44d39fcfc95486d066a796e2cec8c7ec5d429aae"
isbn: null
doi: null
url: "https://github.com/scip-code/scip/blob/44d39fcfc95486d066a796e2cec8c7ec5d429aae/scip.proto"
accessed: 2026-08-05
tags:
  - code-indexing
  - code-navigation
  - symbol-identities
aliases:
  - "SCIP"
---

# SCIP Code Intelligence Protocol

## Reference

SCIP Code Intelligence Protocol contributors. *SCIP Code Intelligence
Protocol*, `scip.proto`, revision
[`44d39fcfc95486d066a796e2cec8c7ec5d429aae`](https://github.com/scip-code/scip/blob/44d39fcfc95486d066a796e2cec8c7ec5d429aae/scip.proto),
accessed 2026-08-05. See also the official [indexer guide](https://sourcegraph.com/docs/code-navigation/writing-an-indexer).

## Contribution

SCIP is a language-agnostic, revision-specific code-index format. An index
contains metadata, documents with canonical project-relative paths,
occurrences, symbol information, and optional external symbols. Occurrences
attach a symbol identity and role bitset—definition, import, read, write, and
others—to typed source ranges. Symbol records can carry documentation,
signatures, enclosing symbols, kinds, and relationships for references,
implementations, type definitions, and alternate definitions.

The schema explicitly permits indexers along a spectrum from compiler-backed
precision to syntax-directed heuristics. Official guidance recommends running a
compiler through semantic analysis and producing deterministic indexes.

## Relevance

SCIP is a strong model for keeping compiler-derived facts outside authored
source while retaining resolvable identities and typed relations. It suggests
that A-Lang’s compiler should own canonical symbol identity, occurrences,
spans, revision metadata, and digests, even if authors declare higher-level
intent such as `tested_by` or `specified_by`.

## Limits

SCIP’s relationship vocabulary is designed for code navigation, not arbitrary
semantic claims or LLM projections. An index can become stale as soon as the
workspace changes; global and local identity conventions have different
properties; and ranges require an explicit position encoding. Existing SCIP
indexers for other languages are foreign executables and therefore cannot be
required by A-Lang’s trusted BEAM compiler path.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
