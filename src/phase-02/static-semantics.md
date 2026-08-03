---
title: "Phase 2 Minimal Resolution and Data Typing"
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

# Phase 2 Minimal Resolution and Data Typing

## Purpose

This document freezes the implemented static semantics of the Phase 2 counter
profile. The checker is a BEAM-resident compiler pass. It consumes an A-Lang
AST and returns checked compiler data; it never evaluates an A-Lang program.

## Stable semantic identities

Tasks receive `task:<module>.<name>/<arity>`. Module, task, parameter, and
variable names remain binaries, so source-controlled names do not enter the
VM's permanent atom table. Source origins remain attached to declarations and
expressions for diagnostics.

The checker rejects duplicate task names, duplicate parameters, and unresolved
variables. Parameters form the body environment. The completion environment
adds the reserved binary name `result`, bound to the task result type.

## Minimal data judgment

The closed monomorphic type set is `Int | Bool`:

- an in-range integer literal has type `Int`;
- `true` and `false` have type `Bool`;
- a variable has its environment type;
- addition requires two `Int` values and returns `Int`;
- equality requires equal operand types and returns `Bool`;
- a task body must match its declared result type; and
- `ensures` must return `Bool`.

There are no coercions, subtyping, inferred polymorphism, functions, records,
results, branches, or user operations in this vertical slice.

## Failure and determinism contract

Unsupported versions, malformed AST shapes, duplicate names, unresolved
variables, out-of-range literals, and type mismatches return diagnostic lists
before IR lowering. Identical accepted ASTs produce identical checked maps and
stable callable identities under deterministic term encoding.

## Reproducible evidence

From the repository root:

```console
make test-section-2-2
```

The gate executes the Phase 2 EUnit suite on ERTS, including positive counter
typing, unresolved-name rejection, deterministic IR construction, and compiler
residency assertions.
