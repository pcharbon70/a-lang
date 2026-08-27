---
title: "Token-Positive Mnemonic Promotion Implementation"
kind: map
created: 2026-08-27
tags:
  - directory-index
  - evaluation
  - source-code
  - token-efficiency
aliases: []
---

# Token-Positive Mnemonic Promotion Implementation (`src/token-positive-mnemonic-promotion`)

## Purpose

This directory contains the BEAM-resident contract, corpus, schedule,
registration, and evidence tools for the
[token-positive mnemonic promotion plan](../../60-planning/04-token-positive-mnemonic-promotion/README.md).
It reuses R2 by exact reference and never changes the historical campaign.

## What belongs here

- Closed P0/P1 contract and ordered-decision validators.
- Deterministic power, fresh-corpus, profile, schedule, and registration tools.
- EUnit, mutation, clean-process, and zero-call integration evidence.

Generated BEAM files and machine evidence belong under the ignored
`build/token-positive-mnemonic-promotion/` directory. Live model adapters
belong to Phase 3 and remain unauthorized here.

## Index

### Subdirectories

- None yet.

### Files

- [`alang_mnemonic_contract.erl`](alang_mnemonic_contract.erl) — validates
  exact P0/P1 roles and R2 references and applies validity, token, safety, and
  fidelity gates in their frozen order.
- [`alang_mnemonic_contract_tests.erl`](alang_mnemonic_contract_tests.erl) —
  tests exact reference hashes, role closure, strict thresholds, every outcome,
  precedence, and unknown-field rejection.
- [Section 1.1 integration evidence](section-01-01-integration-evidence.md) —
  records the frozen P0/P1 contract, exact historical references, decision
  mutations, BEAM residency, and zero-call boundary.

## Maintaining this index

Inventory every direct implementation and evidence file, keep trusted modules
BEAM-resident, and complete a planning checkbox only from reproducible positive
and negative evidence.
