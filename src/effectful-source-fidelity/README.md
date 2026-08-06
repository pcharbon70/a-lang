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

- [`alang_fidelity_artifact_v2.erl`](alang_fidelity_artifact_v2.erl) — inspects
  generated IR v2 BEAM containers, permits only the fixed module, exports,
  imports, chunks, compiler profile, and metadata contract, and binds loaded
  artifacts back to exact compiler evidence.
- [`alang_fidelity_ast.erl`](alang_fidelity_ast.erl) — validates every v2 AST
  node against exact fields, closed values, collection and budget bounds,
  source origins, and safe workspace paths.
- [`alang_fidelity_ast_tests.erl`](alang_fidelity_ast_tests.erl) — exercises
  exact-shape, origin, path, canonical ETF, legacy compatibility, atom-growth,
  and malformed-input rejection gates.
- [`alang_fidelity_anthropic_adapter.erl`](alang_fidelity_anthropic_adapter.erl)
  — renders the fixed Claude Messages request, keeps the API key inside the
  adapter boundary, rejects model substitution, and maps bounded provider
  envelopes into the shared result algebra without retaining raw responses.
- [`alang_fidelity_authority.erl`](alang_fidelity_authority.erl) — infers exact
  registered effects, least static resource requirements, child attenuation,
  and finite direct-plus-delegated usage bounds without embedding grants.
- [`alang_fidelity_body_tests.erl`](alang_fidelity_body_tests.erl) — exercises
  ordered effect and repair steps, explicit error results, attenuated child
  declarations, completion predicates, clarification, and terminal classes.
- [`alang_fidelity_campaign.erl`](alang_fidelity_campaign.erl) — materializes
  the frozen 288-cell paired campaign, uses seed `2026080501` to balance
  conditions and task families within each model, assigns opaque identities,
  and renders byte-stable requests containing the common result schema.
- [`alang_fidelity_campaign_journal.erl`](alang_fidelity_campaign_journal.erl)
  — persists bounded hash-chained intent, result, replacement, and closure
  records as canonical ETF in an append-only stream and safely reconstructs
  the stream after restart.
- [`alang_fidelity_campaign_runner.erl`](alang_fidelity_campaign_runner.erl) —
  enforces the frozen call and cost ceilings, exact trial order, one eligible
  retry, repair, or linked replacement, and deterministic state reconstruction
  without selective reruns.
- [`alang_fidelity_campaign_tests.erl`](alang_fidelity_campaign_tests.erl) —
  freezes the balanced schedule shape and tests opaque identities, request
  leakage, order mutation, retry/repair/replacement bounds, durable replay,
  and duplicate-result rejection.
- [`alang_fidelity_backend_v2.erl`](alang_fidelity_backend_v2.erl) — lowers
  checked IR v2 actions into static calls in allowlisted Abstract Format,
  compiles deterministically on BEAM with strong validation, and emits
  representation-local backend diagnostics.
- [`alang_fidelity_backend_v2_tests.erl`](alang_fidelity_backend_v2_tests.erl)
  — compiles all 48 frozen representations, compares paired executable
  identities, and detects forbidden calls, metadata tampering, bad imports,
  nondeterminism, and diagnostic-origin loss.
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
- [`alang_fidelity_completion.erl`](alang_fidelity_completion.erl) — evaluates
  source-declared artifact, digest, byte, UTF-8, Markdown, journal, and
  clarification predicates and combines them with the independent Phase 6
  filesystem verifier into a content-addressed completion witness.
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
- [`alang_fidelity_https.erl`](alang_fidelity_https.erl) — provides the single
  OTP HTTPS transport with peer and hostname verification, disabled redirects,
  campaign deadlines, bounded response envelopes, and conservative submission
  certainty for errors.
- [`alang_fidelity_forms_v2.erl`](alang_fidelity_forms_v2.erl) — owns the
  deterministic metadata envelope and recursively validates the small
  Abstract Format subset and four fixed runtime ABI calls accepted for
  generated effectful programs.
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
- [`alang_fidelity_live_gate.erl`](alang_fidelity_live_gate.erl) — computes the
  price-provenanced maximum campaign projection and requires exact profiles,
  both adapter-owned credentials, explicit live opt-in, and confirmation of
  that projection before issuing a content-addressed authorization token.
- [`alang_fidelity_lowering_tests.erl`](alang_fidelity_lowering_tests.erl) —
  checks paired IR equality, exact authority, limit bounds, stable nodes and
  effect ordinals, deterministic ETF, seeded mutants, and campaign gates.
- [`alang_fidelity_offline.erl`](alang_fidelity_offline.erl) — compiles and
  executes every A-Lang/typed-JSON pair independently with deterministic model
  fixtures, normalizes runtime observations, and checks trusted counter
  accounting before producing the offline matrix.
- [`alang_fidelity_offline_tests.erl`](alang_fidelity_offline_tests.erl) —
  compares all 24 paired executions, exercises matched failure, incomplete,
  cancellation, and uncertain outcomes, detects v2-specific mutants, and
  reasserts the inherited BEAM-resident implementation boundary.
- [`alang_fidelity_openai_adapter.erl`](alang_fidelity_openai_adapter.erl) —
  renders the fixed text-only Responses API request, keeps the API key inside
  the adapter boundary, rejects model substitution, and normalizes only
  bounded output text and usage metadata.
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
- [`alang_fidelity_phase4_evidence.erl`](alang_fidelity_phase4_evidence.erl) —
  aggregates all 48 inspected executions, paired failure classes,
  clean-process reproduction, BEAM residency, compiler-boundary checks,
  inherited gates, mutants, and retained limitations into deterministic ETF.
- [`alang_fidelity_phase4_integration_tests.erl`](alang_fidelity_phase4_integration_tests.erl)
  — freezes the Phase 4 evidence identities and verifies the complete matrix,
  exact negative classes, cross-process bytes, residency, and owned evidence
  paths.
- [`alang_fidelity_phase4_mutation.erl`](alang_fidelity_phase4_mutation.erl) —
  seeds ignored manifests, JSON frontend bypass, widened runtime limits,
  skipped repair accounting, swapped source maps, widened child authority, and
  condition-specific runtime-handler defects for the Phase 4 gate.
- [`alang_fidelity_phase4_worker.erl`](alang_fidelity_phase4_worker.erl) —
  recompiles and executes one pair per family in a fresh ERTS process and
  writes safely decodable deterministic evidence containing actual BEAM,
  metadata, trace, artifact, and completion-witness bytes.
- [`alang_fidelity_preregister.erl`](alang_fidelity_preregister.erl) — validates
  the complete frozen input set and writes deterministic, content-addressed
  pre-registration evidence under the ignored build tree.
- [`alang_fidelity_provider_protocol.erl`](alang_fidelity_provider_protocol.erl)
  — defines the closed provider-neutral request/result algebra, exact profile
  identities, transport certainty, retry eligibility, cost arithmetic,
  redaction, and deterministic result digests.
- [`alang_fidelity_provider_tests.erl`](alang_fidelity_provider_tests.erl) —
  proves fixed text-only payloads, exact profile probes, conservative transport
  handling, secret non-retention, and the live authorization and ceiling gate.
- [`alang_fidelity_representation.erl`](alang_fidelity_representation.erl) —
  decodes the typed-JSON control with JSON Pointer origins, normalizes away
  presentation metadata, and enforces the frozen source and trial contracts.
- [`alang_fidelity_representation_tests.erl`](alang_fidelity_representation_tests.erl)
  — verifies source-v1 preservation, forbidden features, closed controls,
  semantic equality, origin separation, opaque scheduling, and leakage rules.
- [`alang_fidelity_runtime.erl`](alang_fidelity_runtime.erl) — binds inspected
  artifact metadata to exact operator resources, opaque broker grants, static
  counters and deadlines, durable workspace state, bounded repair, attenuated
  children, and verifier-only completion.
- [`alang_fidelity_runtime_abi.erl`](alang_fidelity_runtime_abi.erl) — exposes
  the four fixed calls available to generated BEAM while validating the opaque
  runtime context and containing process failure or timeout.
- [`alang_fidelity_runtime_tests.erl`](alang_fidelity_runtime_tests.erl) — runs
  direct, repair, delegation, and clarification programs through generated
  BEAM and rejects binding widening, supplied limits, out-of-order ABI calls,
  and model-authored completion or authority claims.
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
- [Phase 4 source-to-BEAM enforcement evidence](phase-04-integration-evidence.md)
  — records all 48 inspected executions, paired positive and negative
  observations, inherited gates, v2 mutants, compiler residency, and
  byte-identical clean-process reproduction.

## Maintaining this index

Index every direct implementation or test file when it is added. Link nested
directories through their own README, keep generated evidence outside `src/`,
and update the matching phase section and reproducible test command together.
