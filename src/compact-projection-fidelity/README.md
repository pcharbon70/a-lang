---
title: "Compact Projection Fidelity Implementation"
kind: map
created: 2026-08-12
tags:
  - directory-index
  - evaluation
  - source-code
  - token-efficiency
aliases: []
---

# Compact Projection Fidelity Implementation (`src/compact-projection-fidelity`)

## Purpose

This directory contains the BEAM-resident contracts, validators, campaign
materializers, statistical tools, and preregistration evidence for the
[compact projection fidelity plan](../../60-planning/03-compact-projection-fidelity/README.md).
It does not authorize model calls or implement the Phase 2 compact projector.

## What belongs here

- Closed experiment-contract and evidence validators.
- Deterministic power, pairing, schedule, corpus, scope, and digest tools.
- EUnit and integration tests for the numbered planning sections.
- Reproducible evidence documents that distinguish offline qualification from
  model efficacy.

Generated BEAM and machine evidence belong under the ignored
`build/compact-projection-fidelity/` tree. Model adapters and live execution
belong to later phases.

## Index

### Subdirectories

- None yet.

### Files

- [`alang_compact_contract.erl`](alang_compact_contract.erl) — validates the
  frozen six-condition/four-protocol scientific contract and applies its
  ordered invalid, unsafe, promote, or retain-readable decision rule.
- [`alang_compact_contract_tests.erl`](alang_compact_contract_tests.erl) —
  freezes condition roles and thresholds and tests every outcome, strict
  boundary, nonpromotable control, and unknown-field failure.
- [`alang_compact_corpus.erl`](alang_compact_corpus.erl) — validates the 48
  held-out semantic descriptors against the opaque design, audits separation
  from development data, and expands each into a checked neutral oracle.
- [`alang_compact_design_tests.erl`](alang_compact_design_tests.erl) — tests
  deterministic power selection, power-contract mutation, the 2,304-cell
  factor matrix, opaque identities, balance, and semantic-case separation.
- [`alang_compact_power.erl`](alang_compact_power.erl) — runs the registered
  paired case-cluster simulation and selects the first balanced sample size
  meeting the frozen central-scenario power threshold.
- [`alang_compact_registration.erl`](alang_compact_registration.erl) —
  validates exact provider artifacts, token accounting, offline policy,
  request and compute ceilings, retention, and invalidation triggers.
- [`alang_compact_registration_tests.erl`](alang_compact_registration_tests.erl)
  — tests corpus balance and independence, oracle authority, immutable profile
  identities, offline defaults, fixed ceilings, and rejection mutants.
- [`alang_compact_schedule.erl`](alang_compact_schedule.erl) — validates the
  opaque 48-case design and deterministically materializes and validates the
  seeded paired schedule and digest.
- [Section 1.1 integration evidence](section-01-01-integration-evidence.md) —
  records the contract, decision, mutation, BEAM-residency, and no-model-call
  results for the completed section.
- [Section 1.2 integration evidence](section-01-02-integration-evidence.md) —
  records the power-driven expansion to 48 cases and the deterministic,
  balanced 2,304-cell schedule.
- [Section 1.3 integration evidence](section-01-03-integration-evidence.md) —
  records the held-out corpus audit, checked semantic oracles, exact profile
  and tokenizer registration, campaign ceilings, and zero-call boundary.

## Maintaining this index

Inventory every direct source and evidence file, keep trusted modules BEAM-
resident, and mark a planning checkbox complete only when the named clean
command and negative tests reproduce its evidence.
