---
title: "Phase 5: Durable BEAM Sessions and Recovery"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - beam
  - durable-execution
  - fault-tolerance
  - implementation-planning
aliases: []
---

# Phase 5: Durable BEAM Sessions and Recovery

**Description:** This phase makes semantic progress survive BEAM process and
node failure without pretending that supervision or message delivery is a
durable workflow system. It defines explicit checkpoints, intent and result
records, idempotent effect recovery, local grant restoration, and a supervised
resume protocol for compiled A-Lang sessions.

**Status:** In progress — Sections 5.1–5.2 complete.

**Dependencies:** Phase 4 complete with A-Lang code running as supervised BEAM
processes, a closed effect registry, opaque local capability references, a
fail-closed broker, and one bounded idempotent workspace adapter.

## Section 5.1: Durable Semantic State Contract

**Description:** Define exactly which A-Lang state is authoritative across
restart and which BEAM process state is only a disposable live cache.

- [x] **Section 5.1 Complete** — implemented by the
  [durable state contract](../../src/phase-05/durable-state-contract.md),
  [`alang_phase5_state`](../../src/phase-05/alang_phase5_state.erl), and its
  [Section 5.1 tests](../../src/phase-05/alang_phase5_state_tests.erl).

### Task 5.1.1: Version the Persisted Session State

**Description:** Specify a closed record containing the program artifact,
schema version, logical state, accepted observations, budgets, deadlines,
pending work, and terminal status.

- [x] **Task 5.1.1 Complete**

#### Subtask 5.1.1.1: Separate Durable and Ephemeral Fields

**Description:** Persist semantic identifiers and values while excluding PIDs,
ports, monitors, timers, mailbox positions, opaque runtime references, and
other node-local terms.

- [x] **Subtask 5.1.1.1 Complete**

#### Subtask 5.1.1.2: Define State Migration Failure

**Description:** Reject unknown program or state-schema versions with a typed
operator-visible result rather than coercing or partially loading old state.

- [x] **Subtask 5.1.1.2 Complete**

### Task 5.1.2: Define Checkpoint Boundaries

**Description:** Mark the transitions at which a compiled BEAM process must
commit state before accepting new work, issuing an effect, or reporting
completion.

- [x] **Task 5.1.2 Complete**

#### Subtask 5.1.2.1: Specify Pre-Effect and Post-Effect Gates

**Description:** Require a durable intent before dispatch and a durable result
before advancing logical state or exposing the effect as complete.

- [x] **Subtask 5.1.2.1 Complete**

#### Subtask 5.1.2.2: Specify Terminal Completion Gates

**Description:** Require final state, evidence digests, remaining budgets, and
no unresolved effect intents before a session becomes durably complete.

- [x] **Subtask 5.1.2.2 Complete**

## Section 5.2: Intent and Result Journal

**Description:** Implement an append-oriented record of semantic transitions
and external effect attempts with replay-safe identities and integrity checks.

- [x] **Section 5.2 Complete** — implemented by the
  [journal and storage contract](../../src/phase-05/journal-and-storage-contract.md),
  [canonical journal](../../src/phase-05/alang_phase5_journal.erl), and
  [bounded store adapter](../../src/phase-05/alang_phase5_store.erl).

### Task 5.2.1: Define Journal Records

**Description:** Create versioned records for session creation, observation,
transition, effect intent, authorization decision, submission, result,
checkpoint, cancellation, failure, and completion.

- [x] **Task 5.2.1 Complete**

#### Subtask 5.2.1.1: Assign Stable Correlation Identities

**Description:** Derive session, transition, and operation identifiers from
trusted runtime state so retries and late replies can be recognized without
using PIDs or model-generated values.

- [x] **Subtask 5.2.1.1 Complete**

#### Subtask 5.2.1.2: Protect Ordering and Integrity

**Description:** Record sequence numbers, previous-record digests, timestamps
with stated semantics, and canonical encodings, and reject gaps, conflicts,
and malformed records during replay.

- [x] **Subtask 5.2.1.2 Complete**

### Task 5.2.2: Implement the Storage Boundary

**Description:** Put journal and checkpoint I/O behind a bounded adapter whose
acknowledgements state exactly what has become durable.

- [x] **Task 5.2.2 Complete**

#### Subtask 5.2.2.1: Define Commit and Read Semantics

**Description:** Specify atomic append, conditional sequence checks, durable
acknowledgement, checkpoint publication, read-after-commit behavior, and
classified storage failures.

- [x] **Subtask 5.2.2.1 Complete**

#### Subtask 5.2.2.2: Bound Storage Load and Failure

**Description:** Limit record and checkpoint sizes, concurrent requests,
retries, and timeouts, and propagate store unavailability as backpressure
instead of unbounded BEAM mailbox growth.

- [x] **Subtask 5.2.2.2 Complete**

## Section 5.3: Supervised Resume Protocol

**Description:** Reconstruct a fresh BEAM supervision subtree from durable
state and replay only the semantic decisions needed to resume safely.

- [ ] **Section 5.3 Complete**

### Task 5.3.1: Implement Deterministic Recovery

**Description:** Load the accepted artifact and runtime ABI, validate the
journal, restore the latest checkpoint, fold subsequent records, and derive a
single resumable state or classified failure.

- [ ] **Task 5.3.1 Complete**

#### Subtask 5.3.1.1: Rebuild BEAM Runtime State

**Description:** Spawn fresh coordinator, inbox, broker, tracing, and adapter
processes and recreate monitors, timers, and bounded queues from semantic state
rather than serialized runtime terms.

- [ ] **Subtask 5.3.1.1 Complete**

#### Subtask 5.3.1.2: Quarantine Invalid Recovery Inputs

**Description:** Refuse corrupted journals, missing artifacts, incompatible
ABIs, unknown schemas, impossible transitions, and conflicting terminal states
without executing an external effect.

- [ ] **Subtask 5.3.1.2 Complete**

### Task 5.3.2: Handle Late and Duplicate Messages

**Description:** Make the resumed session recognize messages produced by old
process generations and decide whether to accept, deduplicate, or reject them.

- [ ] **Task 5.3.2 Complete**

#### Subtask 5.3.2.1: Add Runtime Generation Fencing

**Description:** Include a trusted generation and correlation identity in
runtime envelopes so stale replies cannot advance a newly restored session.

- [ ] **Subtask 5.3.2.1 Complete**

#### Subtask 5.3.2.2: Record Duplicate Decisions

**Description:** Return the prior typed result for known completed operations,
ignore harmless duplicate signals, and audit conflicts where the same identity
arrives with different content.

- [ ] **Subtask 5.3.2.2 Complete**

## Section 5.4: Effect and Capability Recovery

**Description:** Restore local least authority and resolve uncertain external
effect outcomes without converting retries into duplicate mutations.

- [ ] **Section 5.4 Complete**

### Task 5.4.1: Reissue Local Grants from Durable Policy

**Description:** Reconstruct new opaque references from persisted typed scope,
budgets, deadlines, ownership, and revocation records instead of serializing or
reusing old references.

- [ ] **Task 5.4.1 Complete**

#### Subtask 5.4.1.1: Preserve or Reduce Authority

**Description:** Prove that each recovered grant denotes a subset of the last
durably accepted authority and cannot regain spent budget, expired time, or
revoked scope.

- [ ] **Subtask 5.4.1.1 Complete**

#### Subtask 5.4.1.2: Bind Grants to the New Generation

**Description:** Issue fresh references for the restored runtime generation
and reject every reference retained by a crashed process or stale message.

- [ ] **Subtask 5.4.1.2 Complete**

### Task 5.4.2: Reconcile Pending Effects

**Description:** Classify each intent without a durable result as definitely
not submitted, submitted with known adapter identity, or outcome unknown, then
apply the operation-specific recovery rule.

- [ ] **Task 5.4.2 Complete**

#### Subtask 5.4.2.1: Query Idempotent Adapter State

**Description:** Ask the workspace adapter for the stable operation identity,
verify payload and artifact digests, and record the existing result instead of
writing twice when completion already occurred.

- [ ] **Subtask 5.4.2.1 Complete**

#### Subtask 5.4.2.2: Fail Closed on Irreconcilable Outcomes

**Description:** Pause the session with operator-visible evidence when an
external outcome cannot be proven, rather than guessing, retrying a
non-idempotent action, or reporting completion.

- [ ] **Subtask 5.4.2.2 Complete**

## Section 5.5: Crash-Recovery Integration Test

**Description:** Run the compiled A-Lang effect workflow on BEAM while killing
processes, adapters, the node, and the storage connection at every durable
transition.

- [ ] **Section 5.5 Complete**

### Task 5.5.1: Exercise the Recovery Matrix

**Description:** Inject failures before and after intent commit, authorization,
adapter submission, external mutation, result commit, checkpoint, and terminal
completion.

- [ ] **Task 5.5.1 Complete**

#### Subtask 5.5.1.1: Recover Process and Node Failures

**Description:** Restart individual workers and the complete isolated BEAM node
and assert that a fresh supervision tree resumes from the same durable semantic
state.

- [ ] **Subtask 5.5.1.1 Complete**

#### Subtask 5.5.1.2: Recover Adapter and Store Failures

**Description:** Exercise delayed replies, adapter crashes, store timeouts,
partial availability, duplicate acknowledgements, and reconnection without
unbounded retry or mailbox growth.

- [ ] **Subtask 5.5.1.2 Complete**

### Task 5.5.2: Prove Recovery Safety Properties

**Description:** Verify durable progress, no unauthorized authority widening,
no duplicate logical workspace effect, no acceptance of stale messages, and no
false completion across the full failure matrix.

- [ ] **Task 5.5.2 Complete**

#### Subtask 5.5.2.1: Compare Artifacts and Journals

**Description:** Assert exactly one expected output digest, one logical
operation identity, a valid journal chain, a valid final checkpoint, and no
unresolved effect intent after successful recovery.

- [ ] **Subtask 5.5.2.1 Complete**

#### Subtask 5.5.2.2: Capture Minimal Counterexamples

**Description:** Reduce any failing injection sequence to the shortest process,
node, adapter, or store event history that violates a recovery invariant.

- [ ] **Subtask 5.5.2.2 Complete**

## Phase 5 Completion Evidence

**Description:** Phase 5 is complete only when the repository contains
reproducible evidence for all items below.

- [ ] Durable and ephemeral state are explicitly separated and versioned
- [ ] Journal, checkpoint, commit, and integrity semantics are documented and tested
- [ ] Fresh BEAM supervision trees resume only from validated durable state
- [ ] Runtime generations fence stale and duplicate messages
- [ ] Recovered local grants preserve or reduce prior authority
- [ ] Pending effects reconcile through stable operation identities
- [ ] The crash matrix produces no duplicate logical effect or false completion
- [ ] Irreconcilable outcomes pause with evidence instead of being guessed
