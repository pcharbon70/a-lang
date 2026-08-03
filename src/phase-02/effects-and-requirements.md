---
title: "Phase 2 Pure Effects and Capability-Requirement Boundary"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - capability-security
  - compiler-implementation
  - effect-system
  - proof-of-concept
aliases:
  - "Phase 2 authority semantics"
---

# Phase 2 Pure Effects and Capability-Requirement Boundary

## Purpose

Effects and capability requirements are separate declarative concepts:
effects state what operations a task may perform, while requirements state the
least authority the runtime must grant for those operations. Neither is a
credential or portable authorization token.

Phase 2 deliberately implements only the pure base case. Every task must state
`effect []` and `requires []`; the parser and semantic checker fail closed on a
nonempty list. The typed IR and capability manifest retain both empty sets so
later phases can extend their domains without changing the distinction.

## Why the boundary is narrow

Declaring `Workspace.write` or `Model.complete` without a runtime reference
monitor would create vocabulary without enforcement. Phase 4 introduces the
local opaque grant, typed broker, operation matching, budgets, deadlines, and
revocation. Until that boundary exists, the compiler accepts no external
operation and the reference oracle has no filesystem, network, port, process,
clock, random, or dynamic-code interface.

The current invariant is therefore:

```text
inferred effects = declared effects = []
normalized requirements = []
runtime external operations = []
```

## Determinism and evidence

Empty effects and requirements are encoded explicitly in checked tasks, typed
IR, nondeployable reference observations, capability manifests, agreement
records, and bridge validation. The Phase 2 integration test requires the BEAM
result and all test projections to agree on the empty set.

Run from the repository root:

```console
make test-section-2-3
```

The broader requirement algebra remains specified by the research and future
Phase 4 plan; it is not claimed as implemented by Phase 2.
