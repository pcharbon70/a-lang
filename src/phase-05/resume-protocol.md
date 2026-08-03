---
title: "Phase 5 Supervised Resume Protocol"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - beam
  - durable-execution
  - fault-tolerance
  - supervision
aliases: []
---

# Phase 5 Supervised Resume Protocol

## Recovery order

Recovery is a validation pipeline, not replayed execution. The store first
returns a complete integrity-checked journal and published checkpoint. The
recovery module independently validates the chain, pointer digest, session
identity, state schema, runtime ABI, and program identity. It then reads the
trusted artifact path, verifies its SHA-256 digest, and applies the Phase 3
generated-BEAM inspector before considering any journal suffix.

Records after the checkpoint may reconstruct only decisions that carry enough
semantic information: effect intent, authorization, submission, result
identity, or a matching terminal record. A logical transition with only a
digest cannot reconstruct its value and is quarantined as an unpublished
transition. Gaps, impossible effect ordering, incompatible generations,
missing artifacts, corrupt checkpoints, unknown schemas, and conflicting
terminal states all return `recovery_rejected` without starting a broker or
external adapter.

## Fresh runtime generation

A successful fold increments the durable generation and publishes that fresh
state before accepting runtime messages. `alang_phase5_session_sup` then starts
a one-for-all subtree containing the durable store, Phase 4 broker, its owned
workspace adapter when configured, and fresh coordinator, bounded-inbox, and
trace workers. Supervisors, PIDs, Port handles, monitors, timers, mailboxes,
opaque grants, and deduplication caches are recreated; none are deserialized
from the checkpoint.

If a child cannot start, the subtree does not become a resumed session. If a
child later fails, one-for-all restart prevents a new coordinator from quietly
continuing with an old broker or inbox. Section 5.4 adds explicit grant
reconstruction rather than relying on the broker restart policy.

## Generation fencing and duplicates

Every runtime envelope has a closed version, durable generation, stable
correlation identity, payload digest, and bounded semantic payload. A worker
accepts only its current generation. An older generation is stale; a future
generation is invalid. Repeating a known correlation identity and digest
returns the prior typed result, while the same identity with different content
is an audited conflict. The bounded cache is ephemeral because durable effect
decisions remain in the journal.

The generation is trusted runtime state derived from a validated checkpoint,
not a model argument. Old process messages can therefore be recognized after
both a worker restart and a complete ERTS-node restart.

See the [journal and storage contract](journal-and-storage-contract.md), the
[Phase 5 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-05-durable-beam-sessions-and-recovery.md),
and the [Phase 5 implementation index](README.md).
