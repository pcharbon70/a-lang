---
title: "Phase 8 Demonstration Fixtures"
kind: map
created: 2026-08-04
tags:
  - directory-index
  - fixtures
  - proof-of-concept
aliases: []
---

# Phase 8 Demonstration Fixtures (`src/phase-08/fixtures`)

## Purpose

This directory freezes the inputs and expected observations for the final
offline demonstration. Its parent is the [Phase 8 implementation
directory](../README.md).

## What belongs here

- Accepted A-Lang source and its fixed input.
- Deterministic mock-model and local-grant declarations.
- Expected manifests, output, normalized trace, BEAM metadata, and digests.

## Index

### Subdirectories

- None yet.

### Files

- [`demo.alang`](demo.alang) — the accepted source program compiled through
  the BEAM-resident frontend and backend.
- [`model-fixture.config`](model-fixture.config) — the offline model profile,
  instruction, context, operation identity, and deterministic response.
- [`grant-fixture.config`](grant-fixture.config) — the parent and attenuated
  child authority declarations without runtime capability references.
- [`expected-manifest.config`](expected-manifest.config) — expected source,
  model-child, and workspace effect/requirement sets.
- [`expected-trace.config`](expected-trace.config) — the normalized causal
  stages required in the human and machine evidence.
- [`expected-output.txt`](expected-output.txt) — the exact Markdown bytes for the verified workspace
  artifact.
- [`expected.config`](expected.config) — pinned canonical, IR, BEAM, output,
  witness, and bundle digests for the supported toolchain.

## Maintaining this index

Keep fixtures secret-free and deterministic. Any expected-digest update must
be accompanied by source or compiler evidence explaining why it changed.
