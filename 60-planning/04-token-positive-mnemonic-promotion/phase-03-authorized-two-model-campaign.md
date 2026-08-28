---
title: "Phase 3: Authorized Two-Model Campaign"
kind: note
created: 2026-08-25
maturity: developing
tags:
  - evaluation
  - implementation-planning
  - llm-agents
  - token-efficiency
aliases: []
---

# Phase 3: Authorized Two-Model Campaign

**Description:** After exact offline qualification and explicit authorization,
execute the paired `P0`/`P1` schedule against both frozen model artifacts,
retain authoritative provider usage and bounded response evidence, score every
trial deterministically, and reproduce the complete observation set offline.

## Section 3.1: Enforce Authorization and Durable Execution

**Description:** Make a live request possible only for the exact preregistered
digest, model artifacts, prompt bytes, schedule cell, and bounded opt-in state.

Implementation readiness is recorded in
[Section 3.1 readiness evidence](../../src/token-positive-mnemonic-promotion/section-03-01-readiness-evidence.md).
The completion box remains open because the exact Mixtral artifact and the
registered explicit live opt-in were unavailable; no hosted call occurred.

- [ ] **Section 3.1 Complete**

### Task 3.1.1: Validate the Live Gate Before Every Submission

**Description:** Recompute registration, candidate, corpus, prompt, profile,
schedule, code, and tokenizer identities and refuse the campaign before any
request if one value differs.

- [ ] **Task 3.1.1 Complete**

#### Subtask 3.1.1.1: Verify Exact Model Availability

**Description:** Require both registered Ollama artifact IDs and manifest
digests before the first call and before every resumed batch; missing or
changed artifacts produce an invalid-campaign record, never substitution.

- [ ] **Subtask 3.1.1.1 Complete**

#### Subtask 3.1.1.2: Require Explicit Bounded Opt-in

**Description:** Keep normal builds offline, accept only the registered live
authorization value, refuse undeclared endpoints or credentials, and enforce
request, byte, time, output-token, compute, and campaign ceilings.

- [ ] **Subtask 3.1.1.2 Complete**

### Task 3.1.2: Journal Every Trial Before and After Transport

**Description:** Persist the scheduled identity and pre-submit intent before
transport, then atomically retain bounded request metadata, definitive response
state, provider token usage, content digests, and scoring inputs.

- [ ] **Task 3.1.2 Complete**

#### Subtask 3.1.2.1: Preserve Pairing and Blinding

**Description:** Execute only the next registered cell, preserve
counterbalanced order and opaque identities, send one stateless turn, and
prevent condition roles, answer keys, digests, examples, or prior responses
from entering model-visible bytes.

- [ ] **Subtask 3.1.2.1 Complete**

#### Subtask 3.1.2.2: Apply the Frozen Replacement Rule

**Description:** Never retry a definitive response and permit one linked
replacement only when durable transport evidence proves no definitive response
exists; ambiguous submission state blocks the affected campaign rather than
spending an unregistered call.

- [ ] **Subtask 3.1.2.2 Complete**

## Section 3.2: Score and Reproduce Observations

**Description:** Normalize provider outputs into closed records, apply the
same deterministic semantic, validity, repair, safety, and token accounting to
both conditions, and make every score replayable without network access.

The deterministic implementation and fixture evidence are documented in
[Section 3.2 readiness evidence](../../src/token-positive-mnemonic-promotion/section-03-02-readiness-evidence.md).
Completion remains open until the authorized schedule supplies real provider
usage and first-response observations.

- [ ] **Section 3.2 Complete**

### Task 3.2.1: Validate Provider Usage as Operational Evidence

**Description:** Require nonestimated provider prompt, output, and total token
counts with exact arithmetic and bind them to the immutable trial identity and
response digest.

- [ ] **Task 3.2.1 Complete**

#### Subtask 3.2.1.1: Reject Missing or Inconsistent Usage

**Description:** Mark a trial and, where required, the campaign invalid when
usage is absent, estimated, negative, arithmetically inconsistent, detached
from a response, or reported under the wrong model identity.

- [ ] **Subtask 3.2.1.1 Complete**

#### Subtask 3.2.1.2: Materialize Paired Token Records

**Description:** Link each `P1` provider-input and total-token observation to
its exact `P0` case, model, protocol, and repetition counterpart and reject
unpaired token evidence.

- [ ] **Subtask 3.2.1.2 Complete**

### Task 3.2.2: Score Fidelity, Validity, Repair, and Safety

**Description:** Parse and check generation and repair results, compare closed
normalized semantics, classify action/completion answers, and record exact
component and safety outcomes without an LLM judge.

- [ ] **Task 3.2.2 Complete**

#### Subtask 3.2.2.1: Preserve First-response Outcomes

**Description:** Score refusals, malformed output, truncation, incomplete
semantics, invalid source, and definitive failures as observed rather than
repairing, re-prompting, or excluding them after condition disclosure.

- [ ] **Subtask 3.2.2.1 Complete**

#### Subtask 3.2.2.2: Detect Candidate-only Safety Failures

**Description:** Compare paired effects, scopes, budgets, child grants,
errors, terminal classes, and completion judgments and flag every `P1`-only
authority widening, unauthorized effect, or false completion as a veto.

- [ ] **Subtask 3.2.2.2 Complete**

### Task 3.2.3: Replay the Campaign Offline

**Description:** Reconstruct normalized observations and all deterministic
scores solely from retained redacted evidence, without a provider, network,
mutable clock, or hidden state.

- [ ] **Task 3.2.3 Complete**

#### Subtask 3.2.3.1: Reconcile Schedule Completeness

**Description:** Account for every primary cell as a definitive observation,
one valid linked replacement, or an explicit invalid-campaign cause; reject
duplicates, gaps, unscheduled trials, and pseudoreplication.

- [ ] **Subtask 3.2.3.1 Complete**

#### Subtask 3.2.3.2: Reproduce Observation Digests

**Description:** Require byte-identical normalized response, provider-usage,
score, safety, and campaign-completeness digests across clean ERTS replay
processes.

- [ ] **Subtask 3.2.3.2 Complete**

## Section 3.3: Phase 3 Integration Tests

**Description:** Exercise offline defaults, authorization, exact profiles,
transport journaling, replacement bounds, provider usage, deterministic
scoring, safety vetoes, ceiling enforcement, and replay before accepting the
hosted campaign evidence.

- [ ] **Section 3.3 Complete**

### Task 3.3.1: Run Fault and Mutation Campaigns

**Description:** Seed wrong digests, profile drift, duplicate submissions,
ambiguous transport, missing usage, estimated counts, swapped pairings,
altered responses, score drift, safety omissions, and replay gaps.

- [ ] **Task 3.3.1 Complete**

#### Subtask 3.3.1.1: Prove Network Isolation by Default

**Description:** Run all normal build, unit, mutation, scoring, and replay
commands with network disabled and prove that only the explicit authorized
runner can reach the registered loopback provider endpoint.

- [ ] **Subtask 3.3.1.1 Complete**

#### Subtask 3.3.1.2: Prove Ceiling and Replacement Enforcement

**Description:** Force byte, time, output-token, request, compute, and
replacement thresholds at their boundaries and reject the first excess before
an external effect occurs.

- [ ] **Subtask 3.3.1.2 Complete**

### Task 3.3.2: Publish Phase 3 Evidence

**Description:** Retain the exact registration digest, execution environment,
profile manifests, request accounting, replacement ledger, provider usage,
response and score digests, mutation results, and clean offline replay command.

- [ ] **Task 3.3.2 Complete**

#### Subtask 3.3.2.1: Separate Observation from Decision

**Description:** Publish condition-blinded observations and deterministic
scores without applying or narrating the final promotion outcome until Phase 4
runs the preregistered analysis.

- [ ] **Subtask 3.3.2.1 Complete**

#### Subtask 3.3.2.2: Index Retained and Excluded Evidence

**Description:** Document retention paths, redaction, excluded credentials and
provider internals, artifact digests, minimum retention period, and the exact
files required for independent replay.

- [ ] **Subtask 3.3.2.2 Complete**

## Phase 3 Completion Evidence

**Description:** Phase 3 is complete only when the authorized schedule is
fully accounted for and every observation, token record, semantic score, and
safety classification reproduces offline from retained evidence.

- [ ] Exact registration and model identities are verified before every submitted batch
- [ ] All calls obey the frozen request, transport, replacement, and campaign ceilings
- [ ] Every definitive response is retained and scored once
- [ ] Provider prompt, output, and total usage is exact, complete, and paired
- [ ] Every primary cell has one valid disposition
- [ ] Fidelity, validity, repair, robustness, and safety scores are deterministic
- [ ] Candidate-only authority and false-completion outcomes are explicit
- [ ] Fault and mutation campaigns detect transport, usage, pairing, score, and replay defects
- [ ] Two clean offline replays produce byte-identical observation evidence
- [ ] Published evidence contains observations but no unregistered decision override

## Connections

- [Phase 2](phase-02-mnemonic-candidate-and-offline-qualification.md) supplies
  the qualifying registration digest and explicit authorization boundary.
- [Campaign README](README.md) defines the exact token and safety evidence the
  runner must retain for the ordered decision.
