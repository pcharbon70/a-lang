---
title: "Phase 1 BEAM Vertical Slice"
kind: map
created: 2026-07-31
tags:
  - beam
  - directory-index
  - proof-of-concept
  - runtime-systems
aliases:
  - "Phase 1 implementation index"
---

# Phase 1 BEAM Vertical Slice (`src/phase-01`)

## Purpose

This directory implements the first A-Lang proof-of-concept phase. It starts
with a normative execution contract, then adds the pinned OTP 29 Abstract
Format compiler boundary, a deterministic typed fixture, artifact packaging,
and isolated ERTS integration tests.

The generated A-Lang program must execute as a loaded BEAM module and spawned
ERTS process. Build tools in this directory may validate and lower the fixed
fixture, but they may not evaluate it or produce its runtime result.

## What belongs here

- The closed runtime ABI and first observable-program contract.
- The OTP version guard and allowed Abstract Format subset.
- The typed semantic fixture and build-only lowering implementation.
- Artifact manifests, inspection logic, and isolated execution tests.

Generated `.beam` files, manifests, traces, and test output belong under the
ignored repository `build/` directory, not in source control.

## Index

### Subdirectories

- None yet.

### Files

- [Abstract Format subset](abstract-format-subset.md) — the exact supported
  forms, calls, validation order, import allowlist, and rejection behavior.
- [`alang_phase1_compiler.erl`](alang_phase1_compiler.erl) — build-only OTP
  version guard, Abstract Format validator, deterministic compiler bridge, and
  BEAM inspection boundary.
- [`alang_phase1_compiler_tests.erl`](alang_phase1_compiler_tests.erl) — EUnit
  coverage for version rejection, subset enforcement, OTP strong validation,
  deterministic emission, and import inspection.
- [Runtime contract](runtime-contract.md) — normative execution-engine,
  bootstrap-boundary, ABI, success-trace, and failure-class requirements.
- [`toolchain.config`](toolchain.config) — machine-readable OTP, ERTS,
  architecture, validation, and compiler constraints.

## Maintaining this index

Add every direct implementation, fixture, specification, and test file with a
short description. Keep generated output out of this directory, and update the
corresponding Phase 1 section evidence whenever an indexed file changes a
completed claim.
