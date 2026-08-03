---
title: "Phase 5 Durable BEAM Sessions and Recovery"
kind: map
created: 2026-08-03
tags:
  - beam
  - directory-index
  - durable-execution
  - fault-tolerance
aliases:
  - "Phase 5 implementation index"
---

# Phase 5 Durable BEAM Sessions and Recovery (`src/phase-05`)

## Purpose

This directory implements explicit durable progress and recovery for compiled
A-Lang sessions. It separates authoritative semantic state from disposable
BEAM process state, journals transitions and effects, rebuilds fresh supervised
runtime generations, restores no more authority than was durably accepted, and
reconciles uncertain workspace writes without assuming exactly-once delivery.

## What belongs here

- The closed persisted-session contract and checkpoint gates.
- The append-oriented integrity journal and bounded durable store adapter.
- Deterministic recovery, fresh supervision, and runtime-generation fencing.
- Capability restoration and operation-specific effect reconciliation.
- Process, adapter, store, and isolated-node crash-recovery evidence.

Generated `.beam` files, temporary stores, workspaces, traces, and fault
fixtures remain under the ignored repository `build/` directory.

## Index

### Subdirectories

- None yet.

### Files

- [`alang_phase5_state.erl`](alang_phase5_state.erl) — the closed, versioned
  durable-session value, recursive node-local-term exclusion, typed load
  compatibility checks, semantic transitions, and checkpoint gates.
- [`alang_phase5_state_tests.erl`](alang_phase5_state_tests.erl) — durable and
  ephemeral separation, compatibility rejection, transition-ordering, and
  terminal-completion evidence for Section 5.1.
- [Durable semantic state contract](durable-state-contract.md) — the persisted
  record, excluded live state, checkpoint boundaries, and failure semantics.
- [`alang_phase5_journal.erl`](alang_phase5_journal.erl) — the closed record
  vocabulary, canonical digest chain, stable transition and operation
  identities, and strict replay validation.
- [`alang_phase5_journal_tests.erl`](alang_phase5_journal_tests.erl) — complete
  record-kind, stable-identity, gap, conflict, and integrity evidence.
- [`alang_phase5_store.erl`](alang_phase5_store.erl) — the bounded BEAM storage
  adapter with conditional synced append, atomic checkpoint publication,
  restart validation, deadlines, and typed backpressure.
- [`alang_phase5_store_tests.erl`](alang_phase5_store_tests.erl) — commit,
  duplicate, conditional sequence, checkpoint, restart, limit, failure, and
  corruption tests.
- [Journal and storage contract](journal-and-storage-contract.md) — canonical
  record semantics, stable identities, durability acknowledgements, bounds,
  and local-filesystem assumptions.
- [`alang_phase5_recovery.erl`](alang_phase5_recovery.erl) — independent
  journal/checkpoint/artifact validation, safe suffix folding, quarantine
  classification, and fresh-generation derivation.
- [`alang_phase5_runtime_process.erl`](alang_phase5_runtime_process.erl) —
  fresh coordinator, inbox, and trace workers with bounded runtime-envelope
  admission, generation fencing, and duplicate/conflict decisions.
- [`alang_phase5_session_sup.erl`](alang_phase5_session_sup.erl) — the
  one-for-all fresh session subtree containing store, broker/adapter, and
  runtime roles, plus typed topology inspection.
- [`alang_phase5_resume.erl`](alang_phase5_resume.erl) — the fail-closed
  preflight, recovered-generation checkpoint publication, and supervised
  startup coordinator.
- [`alang_phase5_recovery_tests.erl`](alang_phase5_recovery_tests.erl) — valid
  reconstruction, fresh process/timer evidence, generation fencing, duplicate
  decisions, suffix folding, and invalid-input quarantine tests.
- [Supervised resume protocol](resume-protocol.md) — recovery ordering, fresh
  supervision semantics, runtime generations, and late-message rules.
- [`alang_phase5_authority.erl`](alang_phase5_authority.erl) — validation and
  fail-closed reconstruction of fresh, generation-bound local grants from
  durable structural authority.
- [`alang_phase5_authority_tests.erl`](alang_phase5_authority_tests.erl) —
  budget, expiry, revocation, subset, fresh-reference, and stale-reference
  recovery evidence.
- [`alang_phase5_effect_recovery.erl`](alang_phase5_effect_recovery.erl) —
  pending-effect classification, stable adapter lookup, missing result-record
  repair, and durable pause for irreconcilable outcomes.
- [`alang_phase5_effect_recovery_tests.erl`](alang_phase5_effect_recovery_tests.erl)
  — sidecar crash-window, cross-restart receipt, not-submitted, divergent,
  result-repair, no-second-write, and pause-checkpoint tests.
- [Effect and capability recovery](effect-and-capability-recovery.md) — durable
  authority descriptors, fresh-reference rules, receipt ordering, and pending
  effect decisions.

## Maintaining this index

Index every direct Phase 5 source, protocol document, and evidence file. Keep
serialized values semantic and portable across fresh ERTS processes: PIDs,
ports, monitors, timers, references, functions, and opaque grants never become
durable authority merely because the Erlang external term format can encode
some of them.
