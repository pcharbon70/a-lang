---
title: "Phase 2 Native Frontend and Typed Task IR"
kind: map
created: 2026-07-31
tags:
  - compiler-implementation
  - directory-index
  - proof-of-concept
  - rust
aliases:
  - "Phase 2 implementation index"
---

# Phase 2 Native Frontend and Typed Task IR (`src/phase-02`)

## Purpose

This directory implements the second A-Lang proof-of-concept phase. Its Rust
compiler library owns the canonical JSON frontend, handwritten textual lexer
and parser, source-oriented static semantics, typed task IR, and test-only
semantic views. Accepted programs continue through the Phase 1 OTP 29
Abstract Format boundary and execute only as loaded BEAM modules.

Rust is a native compiler implementation language here, not an A-Lang
runtime. Test-only evaluation is visibly separated from the production
frontend-to-BEAM path and cannot satisfy an execution gate.

## What belongs here

- The frozen Phase 2 source schema and textual grammar.
- Native lexer, parser, resolver, type/effect checker, and IR implementation.
- Requirement normalization and nondeployable semantic views.
- Paired fixtures, negative diagnostics, fuzz-smoke tests, and BEAM bridge.

Cargo target output, generated fixtures, snapshots, BEAM artifacts, and
execution evidence belong under the ignored repository `build/` directory.

## Index

### Subdirectories

- None yet.

### Files

- [`Cargo.toml`](Cargo.toml) — pinned Rust crate metadata, dependencies, and
  strict lint policy for the native compiler.
- [`Cargo.lock`](Cargo.lock) — exact transitive dependency resolution for
  reproducible native compiler builds.
- [`diagnostic.rs`](diagnostic.rs) — stable source-oriented diagnostic codes,
  severity, labels, and deterministic ordering.
- [`effect_checker.rs`](effect_checker.rs) — closed effect inference, exact
  annotation checks, and effect-to-requirement coverage.
- [Effects and requirements](effects-and-requirements.md) — normative closed
  effect, authority predicate, canonicalization, subsumption, and coverage
  contracts.
- [`json_frontend.rs`](json_frontend.rs) — bounded canonical JSON decoder and
  complete schema validation.
- [`ir.rs`](ir.rs) — versioned flat typed task IR, stable preorder identities,
  source lowering, and structural/type/effect invariant validation.
- [Language surface](language-surface.md) — the normative Phase 2 canonical
  schema, textual grammar, precedence, limits, and recovery contract.
- [`lexer.rs`](lexer.rs) — handwritten UTF-8 textual lexer with byte and
  line-column spans.
- [`lib.rs`](lib.rs) — crate boundary and public compiler frontend API.
- [`parser.rs`](parser.rs) — handwritten recovering parser that constructs the
  common untyped AST.
- [`reference.rs`](reference.rs) — bounded, fixture-only, explicitly
  nondeployable reference evaluation for tests and differential comparison.
- [`resolver.rs`](resolver.rs) — namespaces, lexical scopes, stable semantic
  identities, definition/use tables, and resolution diagnostics.
- [`requirements.rs`](requirements.rs) — typed requirement normalization,
  union, equality, subsumption, and deterministic serialization.
- [`semantic.rs`](semantic.rs) — deterministic resolved and data-typed semantic
  model shared by later compiler passes.
- [`source.rs`](source.rs) — versioned source AST, declarations, types,
  requirements, expressions, identifiers, and complete origins.
- [Static semantics](static-semantics.md) — normative resolution, identity,
  scope, data-type, opaque-boundary, and failure contracts.
- [`type_checker.rs`](type_checker.rs) — closed monomorphic data checker and
  source-origin-indexed expression types.
- [Typed task IR and views](typed-task-ir.md) — normative IR vocabulary,
  validation boundary, test evaluator, and nonexecuting projection contracts.
- [`views.rs`](views.rs) — deterministic dry-run, trace, capability-manifest,
  completion-checklist, and explanation views with full node coverage.

## Maintaining this index

Index every direct compiler, fixture, specification, and test file. Keep Rust
build output outside this directory, keep the native frontend independent of
BEAM languages, and link completed plan claims to reproducible implementation
evidence.
