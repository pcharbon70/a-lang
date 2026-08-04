---
title: "Phase 8 Demonstration and Decision"
kind: map
created: 2026-08-04
tags:
  - beam
  - directory-index
  - proof-of-concept
  - release-engineering
aliases: []
---

# Phase 8 Demonstration and Decision (`src/phase-08`)

## Purpose

This directory packages the final offline A-Lang proof-of-concept scenario,
matched baseline comparisons, architecture decisions, and release-candidate
acceptance evidence. It consumes the BEAM-resident compiler and runtime proven
in earlier phases; it does not introduce an alternate interpreter.

## What belongs here

- Frozen demonstration inputs and expected observations.
- The one-command BEAM-native demonstration and bundle inspector.
- Controlled baselines and ablations that keep task semantics fixed.
- Decision, feature, risk, and deferred-work records.
- Final release-candidate checks and evidence indexes.

Generated bundles belong under ignored `build/phase-08/` paths.

## Index

### Subdirectories

- [Demonstration fixtures](fixtures/README.md) — frozen A-Lang source, model,
  grant, manifest, trace, output, and digest expectations.

### Files

- [`alang_phase8_demo.erl`](alang_phase8_demo.erl) — the offline source,
  compiled child, broker, durable workspace, verifier, and evidence-bundle
  runner.
- [`alang_phase8_inspect.erl`](alang_phase8_inspect.erl) — independent digest,
  redaction, artifact, and explanation checks for a generated bundle.
- [`alang_phase8_demo_tests.erl`](alang_phase8_demo_tests.erl) — deterministic
  rerun, expected-output, tamper, and inspection acceptance tests.
- [Reproducible demonstration package](reproducible-demonstration-package.md)
  — usage, contents, trust boundaries, reproducibility, and failure behavior.

## Maintaining this index

Index every direct file and subdirectory. Keep frozen fixture digests aligned
with the pinned OTP toolchain and update them only with an explained semantic
or compiler change.
