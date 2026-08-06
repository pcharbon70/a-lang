---
title: "Phase 5: Hosted Multi-Model Fidelity Evaluation"
kind: note
created: 2026-08-05
maturity: developing
tags:
  - beam
  - evaluation
  - implementation-planning
  - llm-agents
  - reproducibility
aliases: []
---

# Phase 5: Hosted Multi-Model Fidelity Evaluation

**Description:** Run the frozen A-Lang-versus-typed-JSON comprehension
experiment against the two declared hosted model families through bounded
BEAM sidecars, then retain enough redacted evidence for deterministic offline
scoring and replay. Hosted variability may affect observations, but it may not
change the corpus, prompts, answer keys, metrics, thresholds, or runtime path.

**Status:** In progress; Sections 5.1–5.2 are implemented and reproducible
offline. The hosted campaign remains separately gated and has not been
authorized.

**Dependencies:** Phase 4 complete with all 48 representation files compiling
to inspected BEAM and producing matched offline observations. Phase 1's frozen
pre-registration digest, exact model profiles, 576-call ceiling, USD 200
ceiling, and decision contract are immutable inputs to this phase.

## Section 5.1: Bounded Provider Sidecars and Live-Run Authorization

**Description:** Implement one provider-neutral trial protocol and two fixed
BEAM adapters while keeping credentials, transport details, and live network
access outside the compiler and default test path.

- [x] **Section 5.1 Complete**

### Task 5.1.1: Define the Provider-Neutral Sidecar Protocol

**Description:** Give the campaign runner one bounded request/result contract
covering model identity, prompt bytes, effort, token ceiling, deadline, usage,
latency, cost inputs, transport certainty, and normalized provider errors.

- [x] **Task 5.1.1 Complete**

#### Subtask 5.1.1.1: Implement the OpenAI Responses Adapter

**Description:** Use OTP HTTPS from a fixed BEAM module to call exactly
`gpt-5.6-terra` with medium effort, text input/output, no tools, no provider
structured-output constraint, an 8,192-token output ceiling, bounded body
bytes, strict TLS verification, and a campaign-owned deadline.

- [x] **Subtask 5.1.1.1 Complete**

#### Subtask 5.1.1.2: Implement the Anthropic Messages Adapter

**Description:** Use the same normalized protocol and bounds for exactly
`claude-sonnet-5`, map Anthropic usage and stop metadata without leaking raw
envelopes, and prove that provider-specific response shapes cannot alter task
semantics or scoring.

- [x] **Subtask 5.1.1.2 Complete**

### Task 5.1.2: Enforce Explicit Live Authorization and Preflight

**Description:** Refuse all hosted traffic unless the operator deliberately
enables it, both provider profiles pass preflight, and the projected request
and cost bounds fit the frozen campaign ceilings.

- [x] **Task 5.1.2 Complete**

#### Subtask 5.1.2.1: Isolate Secrets and Reject Profile Substitution

**Description:** Read keys only inside the owning sidecar from
`ALANG_OPENAI_API_KEY` and `ALANG_ANTHROPIC_API_KEY`, require
`ALANG_ALLOW_LIVE_MODEL_CALLS=1`, redact secret-bearing values and headers from
all diagnostics, and fail closed if an endpoint returns or resolves to a model
identifier other than the registered exact profile.

- [x] **Subtask 5.1.2.1 Complete**

#### Subtask 5.1.2.2: Confirm Availability, Prices, and Campaign Ceilings

**Description:** Perform non-content profile checks, capture the operator's
declared per-token prices with provenance and time, show projected primary and
maximum call counts and cost, require explicit confirmation, and stop before a
request that would exceed 576 calls or USD 200.

- [x] **Subtask 5.1.2.2 Complete**

## Section 5.2: Frozen Trial Materialization and Durable Orchestration

**Description:** Materialize, randomize, execute, and resume the 288 primary
cells without revealing pair identity to a model or permitting selective
reruns to improve an experimental result.

- [x] **Section 5.2 Complete**

### Task 5.2.1: Materialize the Opaque-Identity Paired Campaign

**Description:** Expand 24 cases by two representations, two model families,
and three repetitions into immutable trial manifests whose opaque identifiers
do not disclose condition names, semantic pairs, answer keys, or expected
outcomes beyond the necessarily visible representation treatment itself.

- [x] **Task 5.2.1 Complete**

#### Subtask 5.2.1.1: Generate the Fixed Randomized Schedule

**Description:** Use a registered deterministic seed to randomize within each
model family while balancing representation and task family over time. Fix the
schedule seed to `2026080501`, record the resulting schedule digest, and make
order changes invalidate the campaign rather than silently creating a new
schedule.

- [x] **Subtask 5.2.1.1 Complete**

#### Subtask 5.2.1.2: Render Byte-Stable Model-Visible Requests

**Description:** Combine the common instruction, one original surface
document, and the common `alang_task_comprehension_v1` result schema with fixed
encoding and line endings; prove that condition-specific wording, filenames,
comments, or answer-key data do not leak into the request.

- [x] **Subtask 5.2.1.2 Complete**

### Task 5.2.2: Execute with Durable Accounting and Conservative Retry Rules

**Description:** Journal every call intent and outcome before advancing the
schedule so interruption can resume exactly once without discarding difficult
responses or duplicating uncertain effects.

- [x] **Task 5.2.2 Complete**

#### Subtask 5.2.2.1: Persist Trial State and Resume Deterministically

**Description:** Record request digest, opaque trial identity, attempt class,
provider/model identity, timestamps, transport certainty, normalized response
digest, token usage, latency, price inputs, and cost in an append-only bounded
journal that reconstructs the next legal action after restart.

- [x] **Subtask 5.2.2.1 Complete**

#### Subtask 5.2.2.2: Bound Retries, Repairs, and Replacement Slots

**Description:** Retry at most once only when the sidecar proves the request
was not submitted; never replay an uncertain submission; retain every
definitive model response; allow at most one registered syntax-or-schema repair
per eligible response; score a refusal, truncation, malformed JSON, or schema
failure as the first-attempt fidelity result; and use a new linked replacement
identity only when no definitive model response exists, while counting every
attempt toward 576 calls and USD 200.

- [x] **Subtask 5.2.2.2 Complete**

## Section 5.3: Deterministic Scoring, Statistics, and Redacted Evidence

**Description:** Turn immutable provider observations into representation-
neutral comprehension records, exact scores, uncertainty intervals, and a
repository-safe evidence bundle without an LLM judge or post-hoc exclusions.

- [ ] **Section 5.3 Complete**

### Task 5.3.1: Normalize Responses Without Hiding First-Attempt Failure

**Description:** Decode accepted UTF-8 JSON under the frozen schema and byte
limits, preserve the first-attempt result as the primary observation, and
classify every response or provider failure through a closed outcome taxonomy.
A definitive non-record response remains a zero-fidelity primary observation
and can never be converted into missing data.

- [ ] **Task 5.3.1 Complete**

#### Subtask 5.3.1.1: Apply the Registered Single-Repair Boundary

**Description:** Offer only the prior diagnostic and original immutable
request to the same exact model profile after a definitive syntax-or-schema
failure, derive a new operation identity, forbid semantic coaching, and report
repaired fidelity separately rather than replacing the primary score.

- [ ] **Subtask 5.3.1.1 Complete**

#### Subtask 5.3.1.2: Canonicalize and Classify Every Observation

**Description:** Produce deterministic canonical JSON and digests for valid
records and closed classifications for refusal, truncation, schema failure,
transport failure, uncertain submission, repair failure, and missing cell;
never infer absent fields or hand-correct a response.

- [ ] **Subtask 5.3.1.2 Complete**

### Task 5.3.2: Score the Frozen Metrics and Build Replayable Evidence

**Description:** Compare canonical records with representation-neutral answer
keys, compute the pre-registered per-model statistics, and retain only bounded
redacted material needed to reproduce those results.

- [ ] **Task 5.3.2 Complete**

#### Subtask 5.3.2.1: Compute Exact, Component, Safety, and Cost Results

**Description:** Report exact semantic fidelity and every registered component,
omission, invention, authority-widening, false-completion, validity, repair,
token, latency, and cost metric by model, condition, family, case, and
repetition; pooled results remain descriptive only.

- [ ] **Subtask 5.3.2.1 Complete**

#### Subtask 5.3.2.2: Compute Paired Intervals and Emit Redacted Records

**Description:** For each model family, run 10,000 paired bootstrap resamples
with seed `20260805`, resampling the eight semantic cases within each task
family and retaining all three paired repetitions for each selected case; emit
the 95% percentile interval and write the frozen corpus, answer keys, prompts,
schedules, normalized responses, scores, bounded usage metadata, provenance,
and digests while excluding keys, authorization headers, raw HTTP envelopes,
hidden reasoning, and unrelated provider identifiers.

- [ ] **Subtask 5.3.2.2 Complete**

## Section 5.4: Phase 5 Integration Tests

**Description:** Prove the adapter, scheduler, accounting, repair, scoring,
redaction, and replay path under deterministic faults before running the
separately authorized hosted campaign, then reconcile every live trial.

- [ ] **Section 5.4 Complete**

### Task 5.4.1: Run Offline Adapter and Campaign Fault Suites

**Description:** Exercise both adapters through local scripted HTTPS fixtures
and run the complete 288-cell schedule with deterministic responses and faults
so all state transitions and scoring can be tested without credentials or
network access.

- [ ] **Task 5.4.1 Complete**

#### Subtask 5.4.1.1: Detect Transport, Identity, Secret, and Bound Failures

**Description:** Test TLS and certificate rejection, wrong model identity,
redirects, timeouts before and after submission, malformed and oversized
bodies, rate limits, partial usage, budget exhaustion, secret-bearing errors,
and sidecar crashes; require fail-closed classifications and zero secret
retention.

- [ ] **Subtask 5.4.1.1 Complete**

#### Subtask 5.4.1.2: Prove Resume, Retry, Repair, and Scoring Determinism

**Description:** Inject interruption at every journal transition, resume from
copies, reject duplicate or selective trials, detect seeded scorer defects,
and require byte-identical normalized records, scores, intervals, accounting,
and decisions across clean ERTS processes.

- [ ] **Subtask 5.4.1.2 Complete**

### Task 5.4.2: Run and Replay the Authorized Hosted Campaign

**Description:** Execute the fixed schedule only after explicit operator
authorization, then prove that repository-safe retained evidence independently
reconstructs the complete result without provider access.

- [ ] **Task 5.4.2 Complete**

#### Subtask 5.4.2.1: Account for Every Hosted Campaign Cell

**Description:** Require three scorable primary observations for every
case/condition/model cell, counting closed definitive-failure classifications
as zero fidelity, or record the campaign invalid; disclose all retries,
repairs, uncertain calls, linked replacements, missingness, exclusions, model
IDs, price inputs, and cost, and stop rather than shrink or substitute the
design when ceilings prevent completion.

- [ ] **Subtask 5.4.2.1 Complete**

#### Subtask 5.4.2.2: Reproduce Results from Redacted Evidence Offline

**Description:** On a clean checkout with network and credentials absent,
validate all content digests and regenerate every normalized observation,
metric table, safety count, bootstrap interval, call/cost total, and campaign
validity result byte-for-byte.

- [ ] **Subtask 5.4.2.2 Complete**

## Phase 5 Completion Evidence

**Description:** Authorize the architecture decision only when the fixed
hosted experiment is complete and replayable, or when its invalidity is fully
accounted for without manufacturing a comparative conclusion.

- [ ] Both fixed provider adapters are BEAM modules using OTP HTTPS and the shared sidecar protocol
- [ ] Default builds and tests make no hosted request and require no credential
- [ ] Preflight rejects aliases, substitutions, unavailable profiles, and ceiling violations
- [ ] The frozen schedule contains exactly 288 primary cells with a reproducible digest
- [ ] Every call, retry, repair, uncertain effect, replacement, token, and cost is durably accounted for
- [ ] No selective rerun, silent exclusion, or post-response corpus change is possible
- [ ] Exact and component metrics preserve first-attempt and repaired results separately
- [ ] Per-model paired bootstrap intervals reproduce with 10,000 resamples and seed `20260805`
- [ ] Redacted evidence contains no credential, header, raw envelope, hidden reasoning, or unrelated identifier
- [ ] Offline replay reproduces all scores and campaign-validity evidence byte-for-byte
- [ ] The campaign has all required scorable cells or is explicitly marked invalid
