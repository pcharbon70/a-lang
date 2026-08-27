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
- [`alang_mnemonic_corpus.erl`](alang_mnemonic_corpus.erl) — validates the 48
  fresh semantic cases, all-72-case separation, adversarial coverage, exact
  authority, and neutral-oracle digests using the existing checked semantics.
- [`alang_mnemonic_design_tests.erl`](alang_mnemonic_design_tests.erl) — tests
  deterministic power and scheduling, fresh-corpus balance and mutations,
  exact profiles and prompts, offline ceilings, and trusted residency.
- [`alang_mnemonic_power.erl`](alang_mnemonic_power.erl) — applies the frozen
  paired case-cluster audit and prevents selection below the 48-case minimum.
- [`alang_mnemonic_registration.erl`](alang_mnemonic_registration.erl) —
  validates exact model/tokenizer profiles, prompt bytes, offline defaults,
  request ceilings, replacement, retention, and zero-call state.
- [`alang_mnemonic_schedule.erl`](alang_mnemonic_schedule.erl) — materializes
  and validates the deterministic, opaque, balanced 1,536-cell P0/P1 schedule.
- [Section 1.1 integration evidence](section-01-01-integration-evidence.md) —
  records the frozen P0/P1 contract, exact historical references, decision
  mutations, BEAM residency, and zero-call boundary.
- [Section 1.2 integration evidence](section-01-02-integration-evidence.md) —
  records the power-qualified 48-case selection, fresh all-72-case-separated
  corpus, exact profiles and prompts, balanced schedule, mutations, ceilings,
  and zero-call boundary.

## Maintaining this index

Inventory every direct implementation and evidence file, keep trusted modules
BEAM-resident, and complete a planning checkbox only from reproducible positive
and negative evidence.
