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

## Maintaining this index

Index every direct Phase 5 source, protocol document, and evidence file. Keep
serialized values semantic and portable across fresh ERTS processes: PIDs,
ports, monitors, timers, references, functions, and opaque grants never become
durable authority merely because the Erlang external term format can encode
some of them.
