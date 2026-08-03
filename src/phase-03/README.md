---
title: "Phase 3 Abstract Format Backend and BEAM Runtime Kernel"
kind: map
created: 2026-08-03
tags:
  - beam
  - compiler-implementation
  - directory-index
  - runtime-systems
aliases:
  - "Phase 3 implementation index"
---

# Phase 3 Abstract Format Backend and BEAM Runtime Kernel (`src/phase-03`)

## Purpose

This directory generalizes the source-derived Phase 2 IR into a validated
Erlang Abstract Format backend, a closed runtime ABI, supervised task
processes, and an inspected artifact-loading boundary. Every trusted compiler
and runtime component is a BEAM module executed by ERTS.

## What belongs here

- Executable backend representation and Abstract Format contracts.
- BEAM-resident lowering, OTP compilation, metadata, and inspection modules.
- Closed runtime ABI, supervision, task, gateway, and trace components.
- Positive, negative, differential, lifecycle, and residency evidence.

Generated `.beam` files, manifests, traces, and test evidence remain under the
ignored repository `build/` directory.

## Index

### Subdirectories

- None yet.

### Files

- [`alang_phase3_contract.erl`](alang_phase3_contract.erl) — executable value,
  failure, IR vocabulary, reference, and runtime-call contract.
- [`alang_phase3_contract_tests.erl`](alang_phase3_contract_tests.erl) —
  representation, bounds, source-origin, and fail-closed subset tests.
- [`alang_phase3_lowering.erl`](alang_phase3_lowering.erl) — deterministic
  typed-IR lowering to a fixed module and compiler-owned Abstract Format
  identities.
- [`alang_phase3_forms.erl`](alang_phase3_forms.erl) — bounded, fail-closed
  validator for the accepted Abstract Format subset and runtime calls.
- [`alang_phase3_backend.erl`](alang_phase3_backend.erl) — pinned OTP 29 strong
  validation and deterministic in-memory BEAM compilation bridge.
- [`alang_phase3_backend_tests.erl`](alang_phase3_backend_tests.erl) — lowering,
  determinism, source-diagnostic, and forbidden-form evidence.
- [`alang_phase3_abi.erl`](alang_phase3_abi.erl) — closed versioned envelopes,
  bounded validation, effect correlation, stale-reply handling, and typed
  denial results.
- [`alang_phase3_trace.erl`](alang_phase3_trace.erl) — bounded per-session trace
  collector with explicit overflow evidence.
- [`alang_phase3_effect_gateway.erl`](alang_phase3_effect_gateway.erl) — bounded
  effect admission, monitored execution, cancellation, contextual trusted
  handler calls, and no-retry replies.
- [`alang_phase3_task_worker.erl`](alang_phase3_task_worker.erl) — isolated
  compiled-task execution, exception containment, deadlines, and result
  envelopes.
- [`alang_phase3_session_sup.erl`](alang_phase3_session_sup.erl) — one-session
  supervisor owning the trace collector, effect gateway, and temporary task.
- [`alang_phase3_launcher.erl`](alang_phase3_launcher.erl) — bounded session
  admission, optional broker-bound session identity, monitoring, cancellation,
  trace collection, and teardown.
- [`alang_phase3_runtime_fixture.erl`](alang_phase3_runtime_fixture.erl) —
  nondeployable pure, effect, and slow-task fixture used by runtime tests.
- [`alang_phase3_runtime_tests.erl`](alang_phase3_runtime_tests.erl) — ABI,
  atom-safety, supervision, overload, gateway-death, deadline, cancellation,
  trace-bound, and no-retry evidence.
- [`alang_phase3_artifact.erl`](alang_phase3_artifact.erl) — metadata, chunk,
  import, export, compiler, toolchain, size, load, and soft-purge policy.
- [`alang_phase3_artifact_tests.erl`](alang_phase3_artifact_tests.erl) —
  pre-load rejection and inspected load-execute-purge lifecycle evidence.
- [`alang_phase3_reference.erl`](alang_phase3_reference.erl) — explicit
  nondeployable test oracle for differential value, effect, and verifier
  observations.
- [`alang_phase3_test_fixtures.erl`](alang_phase3_test_fixtures.erl) —
  nondeployable promoted-node, effect, and verifier-failure IR fixtures.
- [`alang_phase3_residency.erl`](alang_phase3_residency.erl) — reproducible
  compiler/runtime module paths, imports, boundary trace, and BEAM-residency
  evidence.
- [`alang_phase3_integration_tests.erl`](alang_phase3_integration_tests.erl) —
  source-to-BEAM differential, negative, scheduler-smoke, and residency phase
  gates.
- [Backend representation contract](backend-representation-contract.md) —
  value encodings, failure domains, evaluation order, and supported IR nodes.
- [Erlang Abstract Format contract](abstract-format-contract.md) — supported
  forms, calls, compiler-owned atoms, bounds, and diagnostic rules.
- [BEAM artifact and loading contract](artifact-contract.md) — metadata
  placement, digest scopes, inspection gates, and code lifecycle rules.

## Maintaining this index

Index every direct Phase 3 source, contract, fixture directory, and evidence
file. No foreign executable may enter the compiler path, and the reference and
fixture modules are permanently nondeployable test support rather than an
A-Lang runtime.
