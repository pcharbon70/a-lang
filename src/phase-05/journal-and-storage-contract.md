---
title: "Phase 5 Journal and Storage Contract"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - beam
  - durable-execution
  - fault-tolerance
  - journaling
aliases: []
---

# Phase 5 Journal and Storage Contract

## Journal records

The append-oriented `alang_journal_record_v1` format has a closed record-kind
set: session creation, observation, transition, effect intent, authorization,
submission, effect result, checkpoint, cancellation, failure, and completion.
Each kind has an exact payload shape. Records contain the session and runtime
generation, a zero-based sequence, a stable correlation identity, a wall-clock
timestamp, the previous record digest, and their own digest.

Sequence is the only ordering authority. The timestamp is an operator-facing
UTC Unix millisecond observation and is never used to break ties, authorize an
effect, or repair a gap. The digest covers a deterministic external-term
encoding of every field except the digest itself. Replay rejects malformed
records, gaps, wrong sessions, broken previous-digest links, altered payloads,
and conflicting identities.

Transition and operation identifiers are SHA-256 derivations of a trusted
session identity and runtime-assigned ordinal. They contain no PID, reference,
port, timer, model-supplied identity, or newly interned atom. Related intent,
authorization, submission, and result records carry the operation identity as
their correlation identity.

## Storage boundary

`alang_phase5_store` is the only Phase 5 component that owns journal and
checkpoint paths. It is a bounded BEAM `gen_server`; generated A-Lang modules
never call it or filesystem primitives. Each record is written to a new
sequence-named file, synced, renamed into the records directory, and followed
by directory sync through a bounded invocation of the fixed operating-system
`sync -d` utility before the adapter returns `durability: synced`. This Port is
a storage effect helper; it never compiles or interprets A-Lang.

Appending is conditional on the next sequence and head digest. Repeating an
already committed record returns its prior acknowledgement; a different record
at that sequence is a conflict. There is no automatic retry. Maximum record
and checkpoint bytes, call deadline, mailbox admission, and on-disk record
count are bounded. Expiry, saturation, or injected unavailability returns
backpressure or a typed storage error.

A checkpoint is validated with the durable state contract, written and synced,
then published through an atomically replaced pointer. The checkpoint
acknowledgement names its state digest and journal sequence. On restart the
adapter validates the complete record chain and published checkpoint before it
accepts another write. Orphan temporary and unpublished checkpoint files never
become authoritative.

## Commit and read semantics

An append acknowledgement means the exact canonical record is discoverable by
a subsequent read or store restart. A checkpoint acknowledgement means the
pointer and referenced state passed validation and were durably published.
Reads return one validated chain and at most one validated checkpoint. A
corrupt chain or checkpoint prevents startup; the adapter does not truncate,
skip, or repair evidence automatically.

These guarantees are local-filesystem proof-of-concept semantics. They assume
the filesystem honors synced file data, atomic same-filesystem rename, and
directory sync. Replication, remote consensus, disk-controller guarantees, and
operator repair remain outside the proof of concept.

See the [durable state contract](durable-state-contract.md), the
[Phase 5 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-05-durable-beam-sessions-and-recovery.md),
and the [Phase 5 implementation index](README.md).
