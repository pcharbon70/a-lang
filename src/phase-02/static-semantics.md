---
title: "Phase 2 Resolution and Data Typing"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - compiler-implementation
  - name-resolution
  - proof-of-concept
  - type-system
aliases:
  - "Phase 2 static semantics"
---

# Phase 2 Resolution and Data Typing

## Purpose

This document freezes the source-oriented resolution and ordinary data-typing
contract that precedes effect checking, capability requirements, IR lowering,
and BEAM code generation. A module must pass both judgments before any later
phase may consume it.

## Stable semantic identities

The resolver assigns identities from declaration ownership rather than source
offsets. Source origins remain attached to definitions and uses for diagnostics.

| Definition | Identity form |
| --- | --- |
| Module | `module:<module>` |
| Named type | `type:<module>.<type>` |
| Record field | `field:<type-id>.<field>` |
| Function | `function:<module>.<name>/<arity>` |
| Task | `task:<module>.<name>/<arity>` |
| Effect | `effect:<effect>` |
| Parameter/local | `<owner-id>:parameter|local:<name>[:<index>]` |
| Completion predicate | `verifier:<task-id>` |

The PoC reserves versioned identities for the promoted effect boundary:

- `resource:model/v1` and `operation:model.complete/v1`
- `resource:workspace/v1` and `operation:workspace.write/v1`
- `resource:trace/v1` and `operation:trace.emit/v1`

Other declared effects and operations receive deterministic lowercase fallback
identities. This permits source experimentation without treating those fallback
identities as promoted runtime contracts.

## Scope and namespace rules

Modules have separate type, callable, effect, operation, field, and local value
namespaces. Top-level definitions are collected before bodies are resolved, so
declaration order does not affect identity or visibility. Function and task
names share the callable namespace.

Parameters and lexical `let` bindings form nested value scopes. Shadowing is
rejected in the PoC, including collision with the task completion predicate's
reserved `result` value. Duplicate definitions, unknown names, wrong-namespace
uses, and arity mismatches are errors. Every accepted use is recorded by its
source-origin key and stable target identity.

## Minimal data types

The data checker is closed and monomorphic. It admits:

- `Int`, `Bool`, and `String` primitives;
- named opaque, record, and result types;
- structural product types;
- structural `Result<ok, error>` expression types;
- fixed function, task, and operation signatures.

It checks literals, variables, complete record construction, field access,
result constructors, calls, effect-operation arguments and results, `let`,
exhaustive `ok`/`error` matches, sequencing, integer addition, equality, task
result types, and Boolean completion predicates. Each accepted expression is
indexed by source origin with its inferred type.

There are no implicit coercions, inferred polymorphism, subtyping, overloaded
operations, or partial result matches. Result branches must agree. A named
opaque value cannot be constructed as a record or inspected through field
access; later runtime operations are the only intended authority boundary for
creating or consuming opaque identifiers.

## Failure and determinism contract

Resolution and typing collect independent source-local diagnostics where
possible, then sort them deterministically. Later semantic phases receive no
partially resolved or partially typed module. Symbol maps, shapes, signatures,
uses, and expression types use ordered collections so serialization and tests
do not depend on host hash order.

## Reproducible evidence

Run the Section 2.2 gate from the repository root:

```console
make test-section-2-2
```

The resolver tests cover stable identities, definition/use tables, duplicate
and shadowing failures, unknown and wrong-namespace names, and arity checks. The
data-typing tests cover records, functions, tasks, results, lexical composition,
exhaustiveness, mismatches, and opaque-boundary failures.
