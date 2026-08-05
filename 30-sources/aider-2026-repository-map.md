---
title: "Aider Repository Map Documentation and Implementation"
kind: source
created: 2026-08-05
authors:
  - "Paul Gauthier"
  - "Aider contributors"
published: null
citation_key: "aider-2026-repository-map"
container: "Aider"
edition: "main at 5dc9490bb35f9729ef2c95d00a19ccd30c26339c"
isbn: null
doi: null
url: "https://aider.chat/docs/repomap.html"
accessed: 2026-08-05
tags:
  - code-context
  - repository-maps
  - symbol-retrieval
aliases:
  - "Aider repo map"
---

# Aider Repository Map Documentation and Implementation

## Reference

Paul Gauthier and Aider contributors. [“Repository
map”](https://aider.chat/docs/repomap.html), accessed 2026-08-05. Implementation
inspected at
[`aider/repomap.py`](https://github.com/Aider-AI/aider/blob/5dc9490bb35f9729ef2c95d00a19ccd30c26339c/aider/repomap.py),
revision `5dc9490bb35f9729ef2c95d00a19ccd30c26339c`.

## Contribution

Aider generates a compact sidecar map containing repository paths, important
symbols, signatures, and selected definition lines. The implementation extracts
definition and reference tags with tree-sitter queries, falls back to lexical
name tokens when a language supplies definitions without references, builds a
directed file-dependency graph, and ranks it with PageRank.

Ranking is personalized toward files and identifiers already in the
conversation. Identifier shape, frequency, privacy-like leading underscores,
and chat-file references adjust edge weights. A binary search selects ranked
tags that fit the active token budget, and a syntax-aware tree renderer exposes
the relevant definition context. The documented default map budget is roughly
1,000 tokens and can expand when no file is already active.

## Relevance

Aider is a concrete example of a generated symbol map that helps an agent
navigate without embedding reference annotations in source. It is therefore an
essential baseline: a language feature is justified only if typed authored
relations add value beyond a revision-derived map with the same token budget.

## Limits

The documentation describes product behavior but does not provide a controlled
causal evaluation of the map against an otherwise identical no-map agent.
Tree-sitter tags and lexical fallbacks can conflate same-named symbols, PageRank
is a relevance heuristic, and the implementation evolves. Its Python,
tree-sitter, and NetworkX stack may inform an A-Lang design but cannot enter the
trusted compiler path under the repository’s BEAM-only invariant.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
