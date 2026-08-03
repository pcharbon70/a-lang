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
- [Backend representation contract](backend-representation-contract.md) —
  value encodings, failure domains, evaluation order, and supported IR nodes.
- [Erlang Abstract Format contract](abstract-format-contract.md) — supported
  forms, calls, compiler-owned atoms, bounds, and diagnostic rules.

## Maintaining this index

Index every direct Phase 3 source, contract, fixture directory, and evidence
file. No foreign executable may enter the compiler path, and no test oracle may
become a deployable A-Lang runtime.
