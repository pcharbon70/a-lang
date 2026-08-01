---
title: "Phase 2 Typed Task IR and Semantic Views"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - categorical-semantics
  - compiler-implementation
  - intermediate-representation
  - proof-of-concept
aliases:
  - "Phase 2 task IR"
---

# Phase 2 Typed Task IR and Semantic Views

## Purpose

This document freezes the normalized backend-independent representation that
connects authorized A-Lang source to later BEAM lowering. It also defines the
nondeployable semantic views used for tests and explanations. The IR is owned
by A-Lang; neither its Rust data representation nor its reference evaluator is
an accepted production runtime.

## Module and callable form

`alang-task-ir-v1` is a flat graph of typed nodes. A module records its stable
module identity, an ordered callable map, and an ordered node map. Each
callable is either a pure arrow or a task and contains:

- stable parameter identities and types;
- one result type and root node;
- its closed effect set and normalized requirements;
- for tasks, the verifier identity, verifier node, and reserved result binding;
- source origin; and
- no host-language closure or callback.

Node identities have the form `node:<callable-id>:<four-digit-preorder>`. The
lowerer reserves each parent before lowering its children, and child vectors
preserve source evaluation order. Thus names, effects, requirements, verifier
links, and left-to-right evaluation are explicit and deterministic.

## Promoted primitives

The complete Phase 2 node vocabulary is:

| IR node | Meaning |
| --- | --- |
| `constant` | Primitive typed value |
| `input` | Parameter, lexical, branch, or task-result binding read |
| `record_product` | Typed finite product construction |
| `project` | Typed product field projection |
| `ok`, `error` | Result coproduct injections |
| `apply` | Application of a resolved pure arrow or task |
| `bind` | Explicit lexical value-to-body composition |
| `match_result` | Exhaustive two-alternative result elimination |
| `effect_request` | Typed request for a stable declared operation |
| `sequence` | Explicit left-to-right computation composition |
| `add`, `equal` | Closed primitive data operations |
| `verify` | Boolean task completion predicate |

Source `let` becomes `bind`; result matches always retain both branches;
operation and callable spellings become stable identities; and every node
retains its result type, callable owner, and source origin. No optimization is
performed in this phase.

## Validation boundary

Validation rejects unsupported versions, mismatched map keys, noncanonical or
noncontiguous identities, unknown owners, dangling or cross-owner edges,
incorrect primitive and child types, incomplete products, non-result matches,
call and operation signature mismatches, effect escapes, effect requests
outside the owner annotation, noncanonical or uncovered requirements, and
missing or malformed task verifiers. Backend work may consume only a validated
graph.

## Test-only reference evaluator

The reference evaluator is marked nondeployable in its module and result. Its
only inputs are validated IR, explicit task values, per-node fixture effect
results, and a bounded step count. It has no filesystem, network, process,
clock, randomness, dynamic loading, or host callback interface.

It evaluates nodes deterministically, consumes effect results in fixture order,
records effect and completion observations, detects integer overflow, validates
input/result types, and rejects missing fixtures or exhausted steps. These
outcomes support semantic comparison but cannot satisfy a BEAM execution gate.

## Nonexecuting views

One traversal derives five ordered projections:

- a dry-run plan describing each node without running it;
- a normalized trace skeleton with one event category per node;
- per-task capability manifests containing effects, requirements, and direct
  effect sites;
- completion checklists linking task, verifier, predicate, and result binding;
- human-readable explanations of every node.

Every projection records the complete node set it inspected. Their exhaustive
matches over the node enum make a newly added primitive a compile-time coverage
obligation, and tests assert deterministic equality and full instance coverage.

## Reproducible evidence

Run the Section 2.4 gate from the repository root:

```console
make test-section-2-4
```

The gate checks deterministic lowering across all 14 node kinds, negative IR
invariants, bounded fixture evaluation, stable observations, and complete
coverage by all semantic projections.
