---
title: "Phase 2 Minimal Typed Task IR and Semantic Views"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - beam
  - categorical-semantics
  - compiler-implementation
  - intermediate-representation
  - proof-of-concept
aliases:
  - "Phase 2 task IR"
---

# Phase 2 Minimal Typed Task IR and Semantic Views

## Purpose

`alang_typed_task_ir_v1` is the A-Lang-owned representation connecting checked
counter source to later general BEAM lowering. The representation, lowerer,
validator, law harness, reference oracle, and projections all run as ordinary
BEAM modules on ERTS. Only the generated program module can satisfy the runtime
execution gate.

## Module and task form

An IR module records its binary module name, ordered task list, and flat ordered
node list. Each task contains:

- `task:<module>.<name>/<arity>` identity;
- typed parameters and result;
- explicit empty effects and requirements;
- body and completion root identities; and
- source origin.

Node identities have `node:<task-id>:<four-digit-preorder>` form. A parent
reserves its number before its children, preserving deterministic source
evaluation order and producing stable deterministic ETF digests.

## Promoted primitives

| IR node | Meaning |
| --- | --- |
| `input` | Read one binary-named task parameter |
| `result` | Read the completed task result inside `ensures` |
| `literal` | Typed `Int` or `Bool` value |
| `add` | Add two typed integer children |
| `equal` | Compare two same-typed children |
| `verify` | Evaluate the Boolean completion child |

The validator rejects duplicate or nonbinary identities, dangling child
references, missing body roots, and absent or ill-typed verifier roots. The
Phase 2 bridge performs a stricter shape check for the exact successor graph.

## Executable category-law checks

The BEAM-resident EUnit suite exhaustively checks left identity, right identity,
and associativity over `increment`, `double`, and `negate` transformations for
integers from `-32` through `32`. This establishes that the implementation
detects violations on the bounded profile; it is not a universal proof.

PropEr remains the planned library for broader generated and state-machine law
tests after its dependency is pinned. The compiler does not depend on PropEr to
build or execute this slice.

## Test-only reference oracle

The reference oracle consumes only validated IR, an explicit binary-keyed
input map, and a maximum of 256 node steps. It returns
`deployable => false` and `engine => beam_test_oracle`. It exposes no external
effects and cannot satisfy a phase gate.

## Nonexecuting views

One BEAM compiler pass derives:

- task/body dry-run entries;
- a complete ordered node trace skeleton;
- an empty effect and requirement capability manifest;
- task completion roots; and
- counts plus an explicit full-node-coverage marker.

Run the reproducible gate from the repository root:

```console
make test-section-2-4
```
