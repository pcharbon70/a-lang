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
Its modules validate the frozen contracts and corpus, parse the effectful
source surface, preserve a closed canonical AST, and produce deterministic
phase evidence.

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

- [`alang_fidelity_ast.erl`](alang_fidelity_ast.erl) — validates every v2 AST
  node against exact fields, closed values, collection and budget bounds,
  source origins, and safe workspace paths.
- [`alang_fidelity_ast_tests.erl`](alang_fidelity_ast_tests.erl) — exercises
  exact-shape, origin, path, canonical ETF, legacy compatibility, atom-growth,
  and malformed-input rejection gates.
- [`alang_fidelity_authority.erl`](alang_fidelity_authority.erl) — infers exact
  registered effects, least static resource requirements, child attenuation,
  and finite direct-plus-delegated usage bounds without embedding grants.
- [`alang_fidelity_body_tests.erl`](alang_fidelity_body_tests.erl) — exercises
  ordered effect and repair steps, explicit error results, attenuated child
  declarations, completion predicates, clarification, and terminal classes.
- [`alang_fidelity_canonical.erl`](alang_fidelity_canonical.erl) — encodes the
  v2 AST in a distinct deterministic ETF envelope, safely decodes and
  revalidates it, rejects compressed or trailing data, and preserves v1 bytes.
- [`alang_fidelity_control.erl`](alang_fidelity_control.erl) — decodes the
  bounded typed-JSON condition into the representation-neutral semantic-input
  envelope and converts schema failures into stable JSON-local diagnostics.
- [`alang_fidelity_control_tests.erl`](alang_fidelity_control_tests.erl) —
  checks all frozen controls, precise pointer/byte origins, duplicate and
  escape-field rejection, bounded failures, and source-controlled atom safety.
- [`alang_fidelity_compiler.erl`](alang_fidelity_compiler.erl) — composes both
  accepted frontend paths with the shared checker and lowering pass, and
  enforces source-byte, frontend, and semantic-digest campaign provenance.
- [`alang_fidelity_contract.erl`](alang_fidelity_contract.erl) — validates the
  closed task-comprehension and representation-neutral answer-key contracts
  and computes canonical semantic digests.
- [`alang_fidelity_contract_tests.erl`](alang_fidelity_contract_tests.erl) —
  checks accepted records and rejects duplicate keys, unknown fields, dynamic
  operations, excess bounds, bad digests, and authority widening.
- [`alang_fidelity_corpus.erl`](alang_fidelity_corpus.erl) — validates all 24
  family×variant cells, representation and answer-key hashes, reviewed semantic
  equality, exact provider profiles, offline consent, ceilings, and retention.
- [`alang_fidelity_corpus_tests.erl`](alang_fidelity_corpus_tests.erl) — checks
  corpus balance, paired digests, exact model IDs, request bounds, campaign
  ceilings, offline defaults, replacement policy, and credential exclusion.
- [`alang_fidelity_decision.erl`](alang_fidelity_decision.erl) — validates the
  pre-registered metric and statistical rule and derives the closed experiment
  outcome from completed evidence.
- [`alang_fidelity_decision_tests.erl`](alang_fidelity_decision_tests.erl) —
  covers promotion, JSON replacement, stop, invalid-campaign, interval, and
  safety-veto outcomes.
- [`alang_fidelity_frontend_tests.erl`](alang_fidelity_frontend_tests.erl) —
  checks the versioned source lexer, closed task declarations, input bounds,
  stable origins, rejection diagnostics, and unchanged v1 delegation.
- [`alang_fidelity_frontend_evidence.erl`](alang_fidelity_frontend_evidence.erl)
  — builds path-independent Phase 2 corpus, AST, source-map, compatibility,
  robustness, negative-case, and BEAM-residency evidence.
- [`alang_fidelity_integration_tests.erl`](alang_fidelity_integration_tests.erl)
  — runs the complete contract/corpus gate, mutant matrix, BEAM residency
  check, frozen-scope audit, and byte-for-byte digest reproduction.
- [`alang_fidelity_ir.erl`](alang_fidelity_ir.erl) — lowers checked meaning and
  inferred manifests to deterministic `alang_typed_task_ir_v2`, keeps source
  maps separate, and safely validates and round-trips its ETF envelope.
- [`alang_fidelity_json.erl`](alang_fidelity_json.erl) — provides bounded,
  duplicate-aware OTP JSON decoding and deterministic SHA-256 term digests.
- [`alang_fidelity_json_pointer.erl`](alang_fidelity_json_pointer.erl) — scans
  bounded JSON structure without atom creation to retain member order,
  duplicate evidence, JSON Pointers, and original byte offsets.
- [`alang_fidelity_lexer.erl`](alang_fidelity_lexer.erl) — tokenizes the frozen
  `alang-source-v2` surface with byte and line-column origins, bounded UTF-8
  strings, binary identifiers, and no source-controlled atoms.
- [`alang_fidelity_lowering_tests.erl`](alang_fidelity_lowering_tests.erl) —
  checks paired IR equality, exact authority, limit bounds, stable nodes and
  effect ordinals, deterministic ETF, seeded mutants, and campaign gates.
- [`alang_fidelity_parser.erl`](alang_fidelity_parser.erl) — dispatches v1
  source unchanged and parses v2 task declarations, authority, scopes, and
  limits, ordered actions, errors, child attenuation, and completion into the
  stream-owned AST boundary.
- [`alang_fidelity_phase2_integration_tests.erl`](alang_fidelity_phase2_integration_tests.erl)
  — round-trips all 24 sources, freezes aggregate identities, reruns the v1
  suite, detects seeded mutants, and exercises PropEr-generated boundaries.
- [`alang_fidelity_phase3_evidence.erl`](alang_fidelity_phase3_evidence.erl) —
  builds and writes deterministic paired-digest, negative-case, law, mutation,
  campaign-gate, and BEAM-residency evidence for the completed Phase 3 gate.
- [`alang_fidelity_phase3_integration_tests.erl`](alang_fidelity_phase3_integration_tests.erl)
  — freezes the Phase 3 evidence identities and checks all pairs, equivalent
  rejections, IR laws, bounds, provenance, mutations, and generated cases.
- [`alang_fidelity_phase3_mutation.erl`](alang_fidelity_phase3_mutation.erl) —
  seeds effect inference, child limit, completion preservation, frontend
  default, node identity, and direct-IR defects and records their detection.
- [`alang_fidelity_preregister.erl`](alang_fidelity_preregister.erl) — validates
  the complete frozen input set and writes deterministic, content-addressed
  pre-registration evidence under the ignored build tree.
- [`alang_fidelity_representation.erl`](alang_fidelity_representation.erl) —
  decodes the typed-JSON control with JSON Pointer origins, normalizes away
  presentation metadata, and enforces the frozen source and trial contracts.
- [`alang_fidelity_representation_tests.erl`](alang_fidelity_representation_tests.erl)
  — verifies source-v1 preservation, forbidden features, closed controls,
  semantic equality, origin separation, opaque scheduling, and leakage rules.
- [`alang_fidelity_semantics.erl`](alang_fidelity_semantics.erl) — resolves both
  semantic-input envelopes through one checker, assigns stable task and binding
  identities, proves the action graph, types closed operations, and validates
  child, completion, path, and terminal contracts.
- [`alang_fidelity_semantics_tests.erl`](alang_fidelity_semantics_tests.erl) —
  compares all 24 checked meanings and exercises stable identities, unresolved
  dependencies, reachability, completion paths and digests, child depth, and
  clarification control.
- [`alang_fidelity_source.erl`](alang_fidelity_source.erl) — translates the
  closed v2 AST into the representation-neutral semantic-input envelope while
  preserving source-local origins for every semantic field.
- [Phase 1 experiment freeze evidence](phase-01-integration-evidence.md) —
  records the final digest, corpus and profile inventory, campaign ceilings,
  negative gates, scope audit, limitations, and reproduction commands.
- [Phase 2 effectful source frontend evidence](phase-02-integration-evidence.md)
  — records corpus and source-map identities, canonical and v1 compatibility,
  negative and generative gates, BEAM residency, and reproduction commands.
- [Phase 3 matched lowering evidence](phase-03-integration-evidence.md) — records
  the paired semantic and IR identities, exact authority and limits, equivalent
  negative classes, law and mutant results, residency, and reproduction gate.

## Maintaining this index

Index every direct implementation or test file when it is added. Link nested
directories through their own README, keep generated evidence outside `src/`,
and update the matching phase section and reproducible test command together.
