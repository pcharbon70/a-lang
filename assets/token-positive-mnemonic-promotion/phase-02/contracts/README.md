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
- [Protocol contract](protocol-contract-v1.json) — freezes four symmetric,
  single-turn prompt materializers and deterministic no-judge scorers.
- [Protocol contract schema](protocol-contract-v1.schema.json) — closes prompt
  provenance, request ordering, scoring modes, and semantic mutation coverage.
- [Qualification contract](qualification-contract-v1.json) — freezes exact
  tokenizers, pairwise and five-percent gates, registration inputs, and the
  explicit live-authorization handshake.
- [Qualification contract schema](qualification-contract-v1.schema.json) —
  closes token thresholds, tokenizer references, registration scope, and
  authorization defaults.
- [Qualification evidence schema](qualification-evidence-v1.schema.json) —
  closes the complete registration, conformance, protocol, token, schedule,
  gate, zero-call, and qualification-digest record.
- [Authorization contract](authorization-v1.json) — pins the one qualifying
  Phase 2 digest and exact opt-in value accepted by later live execution.
- [Authorization contract schema](authorization-v1.schema.json) — closes the
  authorization digest, environment variable, required value, and fail-closed
  drift policy.
- [Phase 2 evidence schema](phase-2-evidence-v1.schema.json) — closes replay,
  mutation, trusted-residency, digest reconciliation, and zero-call evidence
  published after qualification.

## Maintaining this index

Keep every object closed, verify referenced hashes before use, and never edit
an existing contract after its digest participates in authorization evidence.
