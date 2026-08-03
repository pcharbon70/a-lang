---
title: "Phase 5 Effect and Capability Recovery"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - beam
  - capability-security
  - durable-execution
  - fault-tolerance
aliases: []
---

# Phase 5 Effect and Capability Recovery

## Restoring local authority

Durable state contains structural authority descriptors, never an opaque
reference. A descriptor names a stable grant identity, closed invocations,
remaining budgets, UTC expiry, task identity, and intersection policy.
Revocations are a separate durable set. On resume, the runtime validates every
descriptor and removes revoked, expired, and exhausted authority.

The fresh broker issues a new opaque reference owned by the new coordinator
and bound to its runtime instance and generation. The monotonic deadline is
derived from the remaining UTC lifetime and capped at the broker's 24-hour
local maximum. The restored grant is inspected to confirm its invocation set
is a subset of the descriptor and each budget is no greater. A suffix
authorization record may only reduce the matching durable grant budget.
Unknown grants or a purported larger remaining budget quarantine recovery.

This mechanism is local restoration from trusted policy, not portable signed
delegation. Old references remain unknown to the new broker even when their
durable descriptor is still active.

## Durable workspace identities

The fixed BEAM workspace sidecar now reserves `.alang-operations` beneath the
authorized workspace. A generated task cannot target that prefix. Before an
external mutation, the sidecar syncs an intent receipt containing the stable
operation identity, normalized path, payload digest, expected artifact digest,
size, and prior target state. After the atomic target write and directory sync,
it atomically publishes and syncs a completed receipt.

On restart, an adapter lookup supplies the expected operation, path, payload,
and artifact digests. No receipt proves the operation was not submitted. A
completed receipt plus matching target proves the existing result. An intent
receipt plus the expected target closes the crash window and is promoted to
completed. An intent plus the recorded prior target is safe to retry. A
receipt conflict, corrupt receipt, or divergent target is outcome-unknown.

The receipt protocol uses the fixed BEAM sidecar and bounded `sync -d` helper
inside the existing Bubblewrap and resource-limit boundary. It is not an
A-Lang interpreter or compiler component.

## Recovery decisions

An intent or authorization without submission is retryable. A durable effect
result is returned through the prior typed result acknowledgement. A submitted
operation without a result is queried by stable identity. A matching completed
write causes the runtime to append the missing result record; it never writes
again. A proved non-submission permits an explicit retry by the coordinator.

Irreconcilable evidence appends a recovery-failure record, changes the session
to `paused`, and publishes that checkpoint before the temporary supervision
tree is stopped. Adapter or store unavailability is deferred as backpressure
rather than being mislabeled as proof of failure.

See the [workspace adapter contract](../phase-04/workspace-adapter-contract.md),
the [supervised resume protocol](resume-protocol.md), and the
[Phase 5 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-05-durable-beam-sessions-and-recovery.md).
