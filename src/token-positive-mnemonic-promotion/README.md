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
`build/token-positive-mnemonic-promotion/` directory. Phase 3 adds a separately
gated loopback adapter; normal builds and tests remain offline.

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
- [`alang_mnemonic_authorization.erl`](alang_mnemonic_authorization.erl) —
  rebuilds qualification evidence and requires its exact frozen digest plus
  the registered explicit opt-in before issuing a bounded authorization token.
- [`alang_mnemonic_authorization_tests.erl`](alang_mnemonic_authorization_tests.erl)
  — tests the exact handshake and fail-closed digest, opt-in, and contract
  behavior without performing a request.
- [`alang_mnemonic_execution_tests.erl`](alang_mnemonic_execution_tests.erl) —
  tests exact live identities, bounded requests, schedule order, replacement
  rules, Ollama decoding, and durable journal integrity without network use.
- [`alang_mnemonic_journal.erl`](alang_mnemonic_journal.erl) — maintains a
  qualification- and schedule-bound append-only record chain around each
  transport attempt.
- [`alang_mnemonic_live_gate.erl`](alang_mnemonic_live_gate.erl) — rebuilds the
  frozen qualification and requires exact opt-in, model IDs, manifests,
  parameters, prompts, and ceilings before every prepared submission.
- [`alang_mnemonic_ollama.erl`](alang_mnemonic_ollama.erl) — contains the only
  Phase 3 loopback transport path and validates exact provider response usage.
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
- [`alang_mnemonic_observation.erl`](alang_mnemonic_observation.erl) — closes
  provider usage, first-response scores, normalized semantics, paired token
  records, and candidate-only safety classifications.
- [`alang_mnemonic_observation_tests.erl`](alang_mnemonic_observation_tests.erl)
  — tests exact and invalid usage, deterministic scores, safety widening,
  pairing, replay ordering, gaps, and duplicates.
- [`alang_mnemonic_phase1_worker.erl`](alang_mnemonic_phase1_worker.erl) —
  writes canonical Phase 1 evidence from a clean offline ERTS process.
- [`alang_mnemonic_phase2_worker.erl`](alang_mnemonic_phase2_worker.erl) —
  writes canonical Phase 2 qualification evidence in an isolated ERTS process.
- [`alang_mnemonic_phase2_evidence.erl`](alang_mnemonic_phase2_evidence.erl) —
  reconciles qualification with all-corpus replay, mutation results, trusted
  residency, authorization, and the final zero-call evidence digest.
- [`alang_mnemonic_phase2_integration_tests.erl`](alang_mnemonic_phase2_integration_tests.erl)
  — verifies clean evidence equality, 136 replay pairs, 18 mutants, 16 trusted
  modules, and qualification/authorization digest agreement.
- [`alang_mnemonic_phase2_integration_worker.erl`](alang_mnemonic_phase2_integration_worker.erl)
  — writes final Phase 2 evidence in an isolated offline ERTS process.
- [`alang_mnemonic_phase2_mutation.erl`](alang_mnemonic_phase2_mutation.erl) —
  seeds candidate, alias, map, token, oracle, prompt, authorization, profile,
  schedule, source, and runtime-import defects.
- [`alang_mnemonic_phase2_residency.erl`](alang_mnemonic_phase2_residency.erl)
  — hashes the trusted source and BEAM closure and rejects foreign sources,
  ports, NIFs, shell commands, interpreted forms, and forbidden imports.
- [`alang_mnemonic_power.erl`](alang_mnemonic_power.erl) — applies the frozen
  paired case-cluster audit and prevents selection below the 48-case minimum.
- [`alang_mnemonic_preregister.erl`](alang_mnemonic_preregister.erl) — closes
  schemas and traceability, audits trusted-source scope, reconciles every
  registration dimension, and builds the 21-file evidence record.
- [`alang_mnemonic_protocol.erl`](alang_mnemonic_protocol.erl) — materializes
  four frozen paired prompts and scores comprehension, generation, repair, and
  action/completion responses deterministically without an LLM judge.
- [`alang_mnemonic_protocol_tests.erl`](alang_mnemonic_protocol_tests.erl) —
  tests all 384 prompt/oracle cells, leakage exclusions, malformed responses,
  condition symmetry, and seventeen semantic and authority mutations.
- [`alang_mnemonic_qualification.erl`](alang_mnemonic_qualification.erl) —
  runs exact document and complete-request counts, closed attribution, hard
  token gates, registration hashing, and canonical qualification evidence.
- [`alang_mnemonic_qualification_tests.erl`](alang_mnemonic_qualification_tests.erl)
  — verifies every pair, aggregate and median thresholds, drift rejection,
  zero-call state, and trusted tokenizer residency.
- [`alang_mnemonic_registration.erl`](alang_mnemonic_registration.erl) —
  validates exact model/tokenizer profiles, prompt bytes, offline defaults,
  request ceilings, replacement, retention, and zero-call state.
- [`alang_mnemonic_replay.erl`](alang_mnemonic_replay.erl) — reconstructs
  complete ordered observations, token pairs, scores, safety outcomes, and
  byte-stable evidence digests without network or provider state.
- [`alang_mnemonic_runner.erl`](alang_mnemonic_runner.erl) — advances only the
  next registered cell and enforces pending-intent, request, disposition, and
  one-replacement state.
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
- [Section 2.2 integration evidence](section-02-02-integration-evidence.md) —
  records four deterministic protocols, exact token-positive results, the
  50-file registration, qualification digest, and explicit authorization gate.
- [Section 2.3 integration evidence](section-02-03-integration-evidence.md) —
  records all-corpus replay, 18/18 named mutants, the 16-module trusted BEAM
  closure, clean final reproduction, and the zero-call Phase 2 boundary.
- [Section 3.1 readiness evidence](section-03-01-readiness-evidence.md) —
  records the implemented authorization, journal, transport, and replacement
  boundary while retaining the visible live-prerequisite block.
- [Section 3.2 readiness evidence](section-03-02-readiness-evidence.md) —
  records closed provider usage, deterministic semantic and safety scoring,
  paired token materialization, and offline replay readiness.

## Maintaining this index

Inventory every direct implementation and evidence file, keep trusted modules
BEAM-resident, and complete a planning checkbox only from reproducible positive
and negative evidence.
