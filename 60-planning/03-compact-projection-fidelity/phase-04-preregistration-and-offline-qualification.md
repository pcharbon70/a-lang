---
title: "Phase 4: Preregistration and Offline Qualification"
kind: note
created: 2026-08-11
maturity: developing
tags:
  - beam
  - evaluation
  - implementation-planning
  - security
  - token-efficiency
aliases: []
---

# Phase 4: Preregistration and Offline Qualification

**Description:** Prove the projection, protocols, runner, statistics, safety
gates, and replay path under offline faults and mutations, then freeze every
model-visible byte and decision input in one preregistration digest before
live authorization can be considered.

**Status:** Planned; this phase is the hard boundary between development and
confirmatory observation.

**Dependencies:** Phases 1–3 must provide validated contracts, cases, surfaces,
profiles, schedules, protocols, oracles, and scorers. No material may have been
sent to a model under the new campaign identity.

## Section 4.1: Durable Runner and Evidence Algebra

**Description:** Implement a resumable, bounded campaign whose state and
records make missing, repeated, replaced, or altered trials mechanically
detectable.

- [ ] **Section 4.1 Complete**

### Task 4.1.1: Implement the Hash-Chained Campaign Journal

**Description:** Persist campaign start, call intent, submission state,
definitive result, uncertain transport, linked replacement, abort, and close
events with monotonic sequence numbers and content digests.

- [ ] **Task 4.1.1 Complete**

#### Subtask 4.1.1.1: Make Resume Deterministic

**Description:** Reconstruct the exact next cell, attempt count, ceilings, and
profile block from the journal alone; reject gaps, forks, reordering, digest
mismatch, duplicate definitive responses, and schedule substitution.

- [ ] **Subtask 4.1.1.1 Complete**

#### Subtask 4.1.1.2: Enforce Conservative Replacement

**Description:** Permit one linked replacement only after proof of no
submission or an uncertain transport outcome, retain both attempts, and never
replace a refusal, truncation, invalid output, semantic failure, or safety
failure.

- [ ] **Subtask 4.1.1.2 Complete**

### Task 4.1.2: Implement Redacted Evidence and Offline Replay

**Description:** Normalize provider observations into bounded records that
retain the bytes and usage needed for exact rescoring while excluding secrets,
raw transport envelopes, hidden reasoning, and unrelated provider metadata.

- [ ] **Task 4.1.2 Complete**

#### Subtask 4.1.2.1: Freeze Evidence Schemas and Content Digests

**Description:** Version request, response, score, token, interval, validity,
and provenance records; digest exact model-visible inputs and accepted outputs
and reject unknown or missing fields.

- [ ] **Subtask 4.1.2.1 Complete**

#### Subtask 4.1.2.2: Recompute Every Derived Result Offline

**Description:** Starting from retained normalized observations, reproduce
parsing, checking, semantic scores, safety flags, token summaries, bootstrap
intervals, validity, and the ordered disposition without network or
credentials.

- [ ] **Subtask 4.1.2.2 Complete**

## Section 4.2: Statistical, Safety, and Invalidity Qualification

**Description:** Test the analysis and ordered decision code against every
threshold boundary, unsafe outcome, incomplete schedule, and misleading
aggregation that could change the architecture decision.

- [ ] **Section 4.2 Complete**

### Task 4.2.1: Implement the Registered Paired Analysis

**Description:** Retain model families separately, resample semantic cases
within runtime family with both repetitions and protocols nested, and produce
the registered one-sided non-inferiority interval and descriptive ablations.

- [ ] **Task 4.2.1 Complete**

#### Subtask 4.2.1.1: Reproduce the Seeded Bootstrap

**Description:** Run 20,000 resamples with seed `2026081103`, verify complete
stratum coverage in every draw, and produce byte-stable interval and point-
estimate records across clean ERTS processes.

- [ ] **Subtask 4.2.1.1 Complete**

#### Subtask 4.2.1.2: Keep Repetitions and Pools Descriptive

**Description:** Prevent calls or repetitions from becoming independent sample
units, forbid one model or task from compensating for another gate, and label
pooled, per-repetition, and ablation tables as secondary context.

- [ ] **Subtask 4.2.1.2 Complete**

### Task 4.2.2: Implement Veto and Validity Precedence

**Description:** Evaluate campaign identity and completeness first, then
deterministic and safety vetoes, then token and non-inferiority promotion
predicates, with no manual override.

- [ ] **Task 4.2.2 Complete**

#### Subtask 4.2.2.1: Exercise Every Safety Boundary

**Description:** Seed compact-only unauthorized effects, wider scopes and
budgets, wider child grants, false completion, lost negation, decoder drift,
and inherited runtime regression; require each to produce unsafe rejection.

- [ ] **Subtask 4.2.2.1 Complete**

#### Subtask 4.2.2.2: Exercise Every Invalid-Campaign Boundary

**Description:** Seed missing and extra cells, wrong profile, schedule drift,
changed prompt, ceiling breach, digest mismatch, development-data leakage,
unlinked replacement, corrupt journal, and unavailable replay; require
stop-invalid without an efficacy conclusion.

- [ ] **Subtask 4.2.2.2 Complete**

## Section 4.3: Offline Fault, Security, and Regression Gates

**Description:** Qualify the model boundary and reassert the entire inherited
compiler/runtime trust contract before authorization can expose a prompt.

- [ ] **Section 4.3 Complete**

### Task 4.3.1: Run Adapter and Runner Fault Campaigns

**Description:** Drive each fixed provider adapter through local scripted
identity, TLS, redirect, timeout, truncation, malformed response, usage,
rate-limit, crash, resume, and uncertain-submission outcomes without network
or credentials.

- [ ] **Task 4.3.1 Complete**

#### Subtask 4.3.1.1: Prove Identity, Secret, and Bound Enforcement

**Description:** Reject model aliases, changed revisions, missing usage,
oversized inputs or outputs, expired deadlines, excess calls, secret-bearing
diagnostics, authorization absence, and raw-envelope retention.

- [ ] **Subtask 4.3.1.1 Complete**

#### Subtask 4.3.1.2: Prove Every-Transition Resume Behavior

**Description:** Interrupt before and after every journal transition, rebuild
state, and show exactly-once logical accounting, conservative replacement, and
identical final evidence for every recoverable point.

- [ ] **Subtask 4.3.1.2 Complete**

### Task 4.3.2: Reassert Compiler, Runtime, and Archive Gates

**Description:** Run all inherited frontend, IR, backend, broker, durability,
child, workspace, completion, law, adversarial, fault, mutation, and archive
validation suites with the projection modules present.

- [ ] **Task 4.3.2 Complete**

#### Subtask 4.3.2.1: Reprove BEAM Residency and No Authority Bypass

**Description:** Inspect module closure and execution paths, reject foreign
compiler components and direct effect paths, and prove decoded compact tasks
reach the same checker, backend, broker, and completion verifier as readable
source.

- [ ] **Subtask 4.3.2.1 Complete**

#### Subtask 4.3.2.2: Validate Archive and Secret Hygiene

**Description:** Validate frontmatter, schemas, links, directory inventories,
placeholders, evidence indexes, ignored paths, and secret scans; keep default
tests offline and retained records free of credentials and headers.

- [ ] **Subtask 4.3.2.2 Complete**

## Section 4.4: Phase 4 Integration Tests

**Description:** Reproduce the entire offline source-to-decision pipeline,
freeze its immutable registration inputs, and prove the live entry point is
closed unless the exact digest receives explicit operator authorization.

- [ ] **Section 4.4 Complete**

### Task 4.4.1: Run the Full Synthetic Campaign

**Description:** Execute all 1,152 cells with deterministic fixtures spanning
exact success, semantic miss, invalid generation, failed repair, unsafe
judgment, refusal, transport uncertainty, replacement, and abort.

- [ ] **Task 4.4.1 Complete**

#### Subtask 4.4.1.1: Reproduce Every Ordered Outcome

**Description:** Produce promote, retain-readable, reject-unsafe, and stop-
invalid fixtures at exact token, interval, task-regression, and safety
boundaries and require the machine explanation to name every predicate.

- [ ] **Subtask 4.4.1.1 Complete**

#### Subtask 4.4.1.2: Replay from Redacted Evidence Only

**Description:** Remove network and credentials, rebuild in a clean checkout,
and require the journal, observations, scores, token tables, intervals,
validity, and final fixture decisions to reproduce byte-for-byte.

- [ ] **Subtask 4.4.1.2 Complete**

### Task 4.4.2: Freeze and Authorize the Preregistration Digest

**Description:** Hash the complete contracts, corpora, oracles, surfaces,
maps, tokenizers, prompts, legends, profiles, schedule, ceilings, scorers,
statistics, decisions, and trusted implementation closure into one manifest.

- [ ] **Task 4.4.2 Complete**

#### Subtask 4.4.2.1: Prove the Live Gate Is Fail-Closed

**Description:** Require both an exact manifest digest and an explicit live-
call authorization value; fail before submission on absent or mismatched
authority, changed input, profile drift, dirty generated evidence, or ceiling
misconfiguration.

- [ ] **Subtask 4.4.2.1 Complete**

#### Subtask 4.4.2.2: Publish Phase 4 Evidence

**Description:** Record all commands, digests, coverage, faults, mutants,
synthetic outcomes, replay results, inherited gates, and the explicit statement
that offline qualification is not campaign efficacy evidence.

- [ ] **Subtask 4.4.2.2 Complete**

## Phase 4 Completion Evidence

**Description:** Permit live execution only when a clean checkout proves the
entire campaign in advance and one immutable digest binds every decision input.

- [ ] Durable journal and resume logic account for every logical and physical request
- [ ] Definitive failures cannot be retried, discarded, or replaced
- [ ] Redacted evidence is sufficient for exact offline rescoring and contains no secrets
- [ ] Bootstrap and decision outputs reproduce under the registered seed and sampling unit
- [ ] Safety rejection precedes all benefit calculations and invalidity precedes efficacy
- [ ] Adapter, transport, interruption, ceiling, and evidence faults are covered
- [ ] All inherited compiler/runtime/security gates remain green with projection code present
- [ ] The complete 1,152-cell fixture campaign and all four dispositions replay byte-for-byte
- [ ] One registration digest binds every model-visible byte, profile, threshold, and implementation input
- [ ] Live execution fails closed without exact digest authorization and no live call has yet occurred
