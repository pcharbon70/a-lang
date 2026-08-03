---
title: "Phase 2 BEAM-Resident Compiler and Typed Task IR"
kind: map
created: 2026-07-31
tags:
  - beam
  - compiler-implementation
  - directory-index
  - proof-of-concept
aliases:
  - "Phase 2 implementation index"
  - "Phase 2 native frontend"
---

# Phase 2 BEAM-Resident Compiler and Typed Task IR (`src/phase-02`)

## Purpose

This directory implements the second A-Lang proof-of-concept phase. Every
trusted compiler component here—lexing, parsing, canonical decoding, static
semantics, IR lowering, projections, bridge, and compiler command—is compiled
to `.beam` and executed by OTP 29 ERTS. Erlang source bootstraps these compiler
passes; it does not interpret A-Lang programs.

The compiler accepts the deliberately small counter profile, produces a
deterministic A-Lang-owned typed task IR, and feeds the exact Phase 1 semantic
fixture into OTP's supported Abstract Format compiler boundary. The accepted
program then runs as the separately loaded `phase1_counter_v1` BEAM module.

## What belongs here

- BEAM-resident compiler passes and their EUnit tests.
- The frozen minimal source, semantic, IR, and authority contracts.
- Deterministic ETF compiler interchange and reproducibility evidence.
- An explicitly nondeployable BEAM reference oracle and semantic views.
- The fail-closed counter bridge and isolated ERTS agreement harness.

Generated ETF, fixtures, `.beam` files, artifacts, traces, and evidence belong
under the ignored repository `build/` directory.

## Index

### Subdirectories

- [Fixtures](fixtures/README.md) — durable textual A-Lang programs used by the
  frontend, semantic, IR, bridge, and runtime tests.

### Files

#### Compiler modules

- [`alang_phase2_lexer.erl`](alang_phase2_lexer.erl) — bounded handwritten
  lexer with byte and line-column origins.
- [`alang_phase2_parser.erl`](alang_phase2_parser.erl) — parser for the frozen
  counter grammar and shared source AST.
- [`alang_phase2_canonical.erl`](alang_phase2_canonical.erl) — bounded,
  safe-decoded, deterministic ETF canonical boundary.
- [`alang_phase2_semantics.erl`](alang_phase2_semantics.erl) — name, type,
  purity, and empty-authority checks with stable task identities.
- [`alang_phase2_ir.erl`](alang_phase2_ir.erl) — typed task IR lowering,
  structural validation, and small pure morphisms used by law tests.
- [`alang_phase2_views.erl`](alang_phase2_views.erl) — deterministic dry-run,
  trace, manifest, completion, and explanation projections.
- [`alang_phase2_bridge.erl`](alang_phase2_bridge.erl) — fail-closed recognition
  of the exact Phase 1 successor profile.
- [`alang_phase2_compiler.erl`](alang_phase2_compiler.erl) — BEAM-resident
  source-to-product command and compiler-residency evidence emitter.

#### Test-only and runtime modules

- [`alang_phase2_reference.erl`](alang_phase2_reference.erl) — bounded,
  explicitly nondeployable BEAM test oracle.
- [`alang_phase2_compiler_tests.erl`](alang_phase2_compiler_tests.erl) —
  frontend, canonical, semantic, IR, category-law, oracle, bridge, robustness,
  and whole-toolchain residency tests.
- [`alang_phase2_runtime.erl`](alang_phase2_runtime.erl) — runtime-only wrapper
  comparing generated reference evidence with loaded BEAM observation.
- [`alang_phase2_integration_tests.erl`](alang_phase2_integration_tests.erl) —
  isolated ERTS compiler-residency, agreement, and no-interpreter tests.

#### Contracts and evidence

- [Language surface](language-surface.md) — textual grammar, canonical ETF,
  limits, origins, and failure contract.
- [Static semantics](static-semantics.md) — minimal resolution, identity, and
  data-type judgments.
- [Effects and requirements](effects-and-requirements.md) — the Phase 2 pure
  boundary and the distinction between effects and declarative authority.
- [Typed task IR and views](typed-task-ir.md) — promoted nodes, validation,
  law checks, oracle, and projection contracts.
- [Phase 2 integration evidence](phase-02-integration-evidence.md) — compiler
  residency, deterministic products, artifact identity, and ERTS observation.

## Maintaining this index

Index every direct source, fixture, contract, and evidence file. A future
compiler pass must run as BEAM code on ERTS; foreign executables may appear
only as bounded runtime effect adapters outside the trusted compiler path.
