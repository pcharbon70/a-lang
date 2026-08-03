---
title: "Phase 5 Durable Semantic State Contract"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - beam
  - durable-execution
  - fault-tolerance
  - state-machines
aliases: []
---

# Phase 5 Durable Semantic State Contract

## Authority boundary

The `alang_session_state_v1` value is the complete authoritative semantic
state from which a compiled A-Lang session may resume. A running BEAM tree may
cache or derive additional state, but losing that tree must not lose an
accepted observation, refund a budget, forget an effect intent, or turn a
paused or terminal session back into a running one.

The record contains a session identity, runtime generation, accepted program
identity and ABI, logical A-Lang state, observations, remaining budgets,
deadline, pending effect, terminal status, evidence digests, durable authority
descriptions, revocations, and the next transition sequence. Its deterministic
encoding and SHA-256 digest identify the precise checkpointed value.

A pending workspace effect also carries only the normalized workspace, path,
and expected artifact digest required for recovery lookup. It does not contain
an adapter PID, seal, Port, or opaque grant.

## Durable and ephemeral fields

Durable values may contain bounded integers, floats, binaries, lists, tuples,
maps, and only the closed set of compiler-owned A-Lang data-tag atoms. Map keys
and enum-like source values are binaries; source-controlled atoms are rejected.
Recursive validation also rejects PIDs, ports, references, functions, improper
lists, non-byte bitstrings, excessive depth, excessive collections, and
oversized encodings. Runtime process identifiers, monitors, timer references,
mailbox positions, Port handles, ETS identifiers, and opaque local grant
references therefore cannot cross the checkpoint boundary.

The artifact is named by a hexadecimal SHA-256 digest, a bounded binary module
name, the accepted runtime ABI version, and the A-Lang state schema version.
Loading rejects an unknown persisted format, state schema, ABI, artifact
digest, or module name as `{recovery_rejected, Reason, Evidence}`. Recovery
preloads only the closed state and journal protocol vocabulary, then uses safe
external-term decoding. It never coerces an old record or dynamically creates
an atom from persisted input.

## Checkpoint boundaries

A clean running state requires a matching durable checkpoint acknowledgement
before the runtime accepts another observation. Beginning an effect produces a
pending `intent` state; a matching checkpoint acknowledgement is mandatory
before dispatch. Authorization and submission may advance only through the
declared state ordering.

An effect result acknowledgement names the same session, operation, and
transition and commits the result digest. Only that acknowledgement permits
the logical state and remaining budgets to advance and clears the pending
intent. A session may become `completed` only with no pending effect and at
least one evidence digest. Completion is externally visible only after a
matching checkpoint acknowledgement of the terminal state.

These gates deliberately distinguish process supervision from durability. A
BEAM restart can recreate live machinery; it cannot manufacture an
acknowledgement or infer whether an external mutation committed.

## Failure semantics

Malformed records and impossible transitions return typed errors and leave the
input state unchanged. Unknown schemas and artifacts are operator-visible
recovery rejections. An unresolved submitted effect prevents completion. Later
sections add the journal acknowledgements, bounded storage adapter, fresh
supervision tree, and operation-specific reconciliation that satisfy this
contract.

See the [Phase 5 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-05-durable-beam-sessions-and-recovery.md)
and [Phase 5 implementation index](README.md).
