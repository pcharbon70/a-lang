---
title: "Effectful Source Fidelity Implementation"
kind: map
created: 2026-08-05
tags:
  - directory-index
  - evaluation
  - source-code
  - task-language
aliases: []
---

# Effectful Source Fidelity Implementation (`src/effectful-source-fidelity`)

## Purpose

This directory contains the BEAM-resident implementation of the effectful
source-fidelity experiment authorized by the Phase 8 architecture decision.
Its modules validate the frozen contracts, paired representations, corpus,
campaign configuration, deterministic scores, and pre-registration evidence.

The experiment is a new numbered planning stream, not a replacement for the
completed Phase 1–8 proof of concept. All executable validators here compile
to BEAM and run on ERTS.

## What belongs here

- OTP JSON decoding that rejects duplicate keys and bounded-input violations.
- Closed semantic, answer-key, representation, corpus, and campaign validators.
- Deterministic normalization, scoring, decision, and evidence modules.
- EUnit and integration tests for the numbered sections of the active plan.

Hosted provider adapters and live credentials do not belong in the default
test path. Generated evidence belongs under the ignored
`build/effectful-source-fidelity/` tree.

## Index

### Subdirectories

- None yet.

### Files

- [`alang_fidelity_contract.erl`](alang_fidelity_contract.erl) — validates the
  closed task-comprehension and representation-neutral answer-key contracts
  and computes canonical semantic digests.
- [`alang_fidelity_contract_tests.erl`](alang_fidelity_contract_tests.erl) —
  checks accepted records and rejects duplicate keys, unknown fields, dynamic
  operations, excess bounds, bad digests, and authority widening.
- [`alang_fidelity_decision.erl`](alang_fidelity_decision.erl) — validates the
  pre-registered metric and statistical rule and derives the closed experiment
  outcome from completed evidence.
- [`alang_fidelity_decision_tests.erl`](alang_fidelity_decision_tests.erl) —
  covers promotion, JSON replacement, stop, invalid-campaign, interval, and
  safety-veto outcomes.
- [`alang_fidelity_json.erl`](alang_fidelity_json.erl) — provides bounded,
  duplicate-aware OTP JSON decoding and deterministic SHA-256 term digests.

## Maintaining this index

Index every direct implementation or test file when it is added. Link nested
directories through their own README, keep generated evidence outside `src/`,
and update the matching phase section and reproducible test command together.
