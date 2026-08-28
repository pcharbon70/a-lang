---
title: "Token-Positive Mnemonic Promotion Phase 2 Contracts"
kind: map
created: 2026-08-28
tags:
  - directory-index
  - experiment-design
  - token-efficiency
aliases: []
---

# Token-Positive Mnemonic Promotion Phase 2 Contracts (`phase-02/contracts`)

## Purpose

This directory contains the closed machine contracts that qualify exact P1
bytes, deterministic protocols, token accounting, live authorization, and
Phase 2 evidence before any model call.

## What belongs here

- Versioned JSON contracts and their closed JSON Schemas.
- Exact digests for reused renderer, vocabulary, registry, and map machinery.
- Offline qualification and authorization records added by later sections.

## Index

### Subdirectories

- None yet.

### Files

- [Candidate contract](candidate-contract-v1.json) — binds P0 to R0 and P1 to
  the exact historical R2 renderer, decoder, alias vocabulary, and source-map
  contract without changing the historical role.
- [Candidate contract schema](candidate-contract-v1.schema.json) — closes all
  candidate identities, references, limits, conformance, and diagnostic rules.

## Maintaining this index

Keep every object closed, verify referenced hashes before use, and never edit
an existing contract after its digest participates in authorization evidence.
