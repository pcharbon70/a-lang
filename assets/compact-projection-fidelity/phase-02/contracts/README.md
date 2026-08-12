---
title: "Compact Projection Fidelity Phase 2 Contracts"
kind: map
created: 2026-08-12
tags:
  - directory-index
  - evaluation
  - json-schema
  - token-efficiency
aliases: []
---

# Compact Projection Fidelity Phase 2 Contracts (`contracts`)

## Purpose

This directory closes the representation registry and token-audit shape used
by the Phase 2 BEAM implementation.

## What belongs here

- Canonical surface identities and exact versions.
- Stable semantic and lexical attribution categories.
- Closed JSON Schemas for every Phase 2 contract in this directory.

## Index

### Subdirectories

- None yet.

### Files

- [`model-format-v1.json`](model-format-v1.json) — fixes the keyed R3 shape,
  exact derivations, bounded reverse aliases, collision rules, and semantic
  acceptance gate.
- [`model-format-v1.schema.json`](model-format-v1.schema.json) — the closed
  schema for the `alang-model-v1` format contract.
- [`surface-registry-v1.json`](surface-registry-v1.json) — registers `R0`
  through `R5`, exact versions, roles, and implementation sections.
- [`surface-registry-v1.schema.json`](surface-registry-v1.schema.json) — the
  closed schema for the six-entry surface registry.
- [`token-audit-contract-v1.json`](token-audit-contract-v1.json) — fixes exact
  and provider count provenance plus stable semantic and lexical categories.
- [`token-audit-contract-v1.schema.json`](token-audit-contract-v1.schema.json)
  — the closed schema for token-audit reports.

## Maintaining this index

Keep fields closed and versions exact. A new attribution category or surface
identity requires a new contract version and corresponding validator change.
