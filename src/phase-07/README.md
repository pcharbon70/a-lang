---
title: "Phase 7 Validation Harness"
kind: map
created: 2026-08-04
tags:
  - beam
  - directory-index
  - property-based-testing
  - runtime-validation
aliases: []
---

# Phase 7 Validation Harness (`src/phase-07`)

## Purpose

This directory contains the BEAM-native conformance, security, fault, and
performance harness for Phase 7 of the minimal proof of concept. Its test-only
reference models and PropEr properties may falsify implementation claims, but
they are not a deployable A-Lang interpreter and do not replace compiled BEAM
acceptance evidence.

## What belongs here

- Typed source, IR, capability, history, fault, and hostile-input generators.
- Explicit pure, trace, authority, durability, and completion observations.
- PropEr laws, state-machine properties, adversarial tests, fault injection,
  benchmarks, mutation checks, and reproducible evidence.
- Erlang bootstrap modules that compile to BEAM and execute on the pinned ERTS
  toolchain.

Generated dependencies and build products belong in the ignored `_build/` and
`build/` directories.

## Index

### Subdirectories

- None yet.

### Files

- [`alang_phase7_generators.erl`](alang_phase7_generators.erl) — replayable
  PropEr generators and validity-preserving semantic shrink candidates for
  source, promoted pure IR, and fixture-backed effect IR.
- [`alang_phase7_observation.erl`](alang_phase7_observation.erl) — explicit
  value, manifest, fresh-identity, and effect-trace normalization rules.
- [`alang_phase7_law_tests.erl`](alang_phase7_law_tests.erl) — generated
  categorical, serialization, shrinking, and reference-to-BEAM properties.
- [Typed generators and law observations](typed-generators-and-law-observations.md)
  — the dependency boundary, generated domains, equality rules, and
  reproduction command for Section 7.1.

## Maintaining this index

Index every direct file and subdirectory when it is added. Keep generated
case counts, replay rules, observations, limits, and evidence synchronized
with the Phase 7 roadmap and executable test targets.
