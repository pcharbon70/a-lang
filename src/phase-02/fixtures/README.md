---
title: "Phase 2 Compiler Fixtures"
kind: map
created: 2026-07-31
tags:
  - compiler-testing
  - directory-index
  - proof-of-concept
aliases:
  - "Phase 2 fixture index"
---

# Phase 2 Compiler Fixtures (`src/phase-02/fixtures`)

## Purpose

This directory contains durable textual programs used by Phase 2 frontend,
semantic, IR, backend-bridge, and integration tests. The BEAM-resident compiler
emits deterministic ETF and derived products under the ignored `build/`
directory so byte offsets and line-column origins remain tied to the textual
fixture being compiled.

## What belongs here

- Small accepted programs at a frozen language and IR version.
- Source inputs that exercise a named integration or backend profile.
- No generated ETF, IR, semantic views, BEAM files, or execution evidence.

## Index

### Subdirectories

- None.

### Files

- [`counter.alang`](counter.alang) — minimal pure successor task compiled
  through the textual and canonical ETF boundaries, typed IR, Phase 1 adapter,
  and ERTS.

## Maintaining this index

Index every direct fixture. Keep a fixture focused, make its expected semantics
explicit in the owning specification, and generate origin-preserving canonical
partners through the pinned BEAM-resident compiler rather than editing them by
hand.
