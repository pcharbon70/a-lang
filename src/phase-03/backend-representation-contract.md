---
title: "Phase 3 Backend Representation Contract"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - beam
  - compiler-backend
  - runtime-systems
aliases: []
---

# Phase 3 Backend Representation Contract

## Purpose

This contract fixes the values, failures, evaluation order, and ownership
boundary shared by the Phase 3 reference observations and compiled backend.
It is executable through `alang_phase3_contract`; prose does not authorize a
representation that the module rejects.

## Values

Primitive integers remain signed 64-bit BEAM integers, Booleans use the fixed
atoms `true | false`, and bounded strings or byte sequences are binaries.
Structured source data always carries the private outer tag `alang_data_v1`:

```erlang
{alang_data_v1, product, {Field1, Field2}}
{alang_data_v1, ok, Value}
{alang_data_v1, error, Value}
```

Opaque runtime values use `{alang_opaque_v1, TypeId, Reference}` and require an
actual ERTS reference. Source text cannot manufacture them. Compiler and
runtime failures occupy separate tagged domains:

```erlang
{alang_compile_error_v1, Code, NodeId, {source, Byte, Line, Column}}
{alang_runtime_error_v1, Code, {source, Byte, Line, Column}}
```

All tags and error codes are compiler-known atoms. Module, callable, operation,
session, task, correlation, and source identities remain bounded binaries.

## Evaluation and failure order

1. Evaluate arguments and product fields from left to right.
2. Propagate a tagged error before evaluating a dependent step.
3. Suspend only at an explicit `effect_request` node.
4. Observe the monotonic deadline before dispatch and after the effect reply.
5. Evaluate the task verifier only after a result exists.
6. Contain generated exceptions as typed runtime failures at the task-process
   boundary.

Effects are requests, not implicit host calls. A timeout after dispatch records
an uncertain result and never triggers an automatic retry.

## Supported IR vocabulary

The contract reserves a bounded vocabulary for literals, inputs, task results,
addition, equality, products, projection, result injections and elimination,
binding, application, sequencing, effect requests, and verification. Phase 3
lowering must reject any other node with the original node identity and source
origin. Reserving a node here does not make it accepted source syntax; the
frontend remains the Phase 2 counter profile until a later plan promotes more
surface forms.

## Connections

- [Abstract Format contract](abstract-format-contract.md)
- [Phase 3 implementation plan](../../60-planning/01-minimal-proof-of-concept/phase-03-erlang-abstract-format-and-beam-runtime-kernel.md)
- [BEAM runtime and compiler-host research](../../20-notes/beam-runtime-for-native-agent-language.md)
