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

- [`alang_mnemonic_candidate.erl`](alang_mnemonic_candidate.erl) — validates
  exact reused references and binds P0/R0 and P1/R2 rendering, decoding,
  semantic equality, complete source maps, and readable diagnostics.
- [`alang_mnemonic_candidate_tests.erl`](alang_mnemonic_candidate_tests.erl) —
  proves exact P1/R2 bytes across 136 frozen and generated oracles, identical
  acceptance and decoding, stable maps, bounds, and trusted residency.
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
- [`alang_mnemonic_integration_tests.erl`](alang_mnemonic_integration_tests.erl)
  — reconciles the complete registration, deterministic evidence, design-
  evidence boundary, mutation coverage, traceability, and BEAM residency.
- [`alang_mnemonic_mutation.erl`](alang_mnemonic_mutation.erl) — seeds and
  requires detection of 19 scientific-role, threshold, corpus, schedule,
  profile, prompt, and inference defects.
- [`alang_mnemonic_phase1_worker.erl`](alang_mnemonic_phase1_worker.erl) —
  writes canonical Phase 1 evidence from a clean offline ERTS process.
- [`alang_mnemonic_power.erl`](alang_mnemonic_power.erl) — applies the frozen
  paired case-cluster audit and prevents selection below the 48-case minimum.
- [`alang_mnemonic_preregister.erl`](alang_mnemonic_preregister.erl) — closes
  schemas and traceability, audits trusted-source scope, reconciles every
  registration dimension, and builds the 21-file evidence record.
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
- [Section 1.3 integration evidence](section-01-03-integration-evidence.md) —
  records deterministic full-phase reproduction, design-input separation,
  closed schemas, 19 detected mutants, BEAM residency, and zero hosted calls.
- [Section 2.1 integration evidence](section-02-01-integration-evidence.md) —
  records exact P1/R2 rendering and decoding, closed aliases and bounds,
  complete stable source maps, readable diagnostics, and zero-call isolation.

## Maintaining this index

Inventory every direct implementation and evidence file, keep trusted modules
BEAM-resident, and complete a planning checkbox only from reproducible positive
and negative evidence.
