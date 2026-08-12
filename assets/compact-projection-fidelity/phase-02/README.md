---
title: "Compact Projection Fidelity Phase 2 Assets"
kind: map
created: 2026-08-12
tags:
  - beam
  - directory-index
  - evaluation
  - token-efficiency
aliases: []
---

# Compact Projection Fidelity Phase 2 Assets (`phase-02`)

## Purpose

This directory owns the immutable runtime registries and tokenizer material
used to implement the six Phase 2 representations without changing the frozen
Phase 1 preregistration bundle.

## What belongs here

- Closed contracts introduced by the compact projection implementation.
- Exact tokenizer vocabulary, pre-tokenizer, and conformance registrations.
- Versioned inputs used by the trusted BEAM projector, decoder, and auditor.

Generated renderings, reports, and test evidence belong under the ignored
`build/compact-projection-fidelity/phase-02/` tree.

## Index

### Subdirectories

- [Contracts](contracts/README.md) — closed Phase 2 surface and token-audit
  registries with their schemas.
- [Tokenizers](tokenizers/README.md) — pinned mergeable-rank vocabularies,
  pre-tokenizer identities, and exact conformance vectors.

### Files

- None yet.

## Maintaining this index

Create a new version when a surface, tokenizer, schema, or byte representation
changes. Do not revise an identity after campaign observations exist.
