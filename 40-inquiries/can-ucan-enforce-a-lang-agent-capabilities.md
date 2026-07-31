---
title: "Can UCAN enforce A-Lang agent capabilities?"
kind: inquiry
created: 2026-07-31
status: open
tags:
  - agent-programming
  - authorization
  - beam
  - capability-security
  - ucan
aliases:
  - "UCAN feasibility for A-Lang"
---

# Can UCAN enforce A-Lang agent capabilities?

## Why this matters

A-Lang's current design declares effects and required authority, but a
declaration is not an enforceable grant. Distributed agents also need to pass
narrow authority across BEAM processes, nodes, sidecars, and organizational
boundaries without exposing root credentials to an LLM.

UCAN offers signed, attenuated Delegations and signed Invocations, but it has
no confinement guarantee, leaves resource semantics to executors, and has
version and implementation maturity risks. The question is whether a bounded
UCAN profile adds enough portable authority and provenance to justify this
complexity while A-Lang retains a trusted reference monitor.

## Operational question

Compared with an opaque broker-handle baseline, can a pinned UCAN profile:

- preserve inferred least authority across nested subagents;
- bind typed concrete effect requests to a verifiable principal and proof path;
- validate consistently in independent implementations;
- survive replay, process failure, proof unavailability, and stale revocation
  state without unsafe effects;
- keep keys and raw authorization material outside LLM context;
- improve cross-runtime portability and auditability enough to offset proof,
  identity, storage, and version-management cost?

## Provisional answer

Probably, but only as one layer. UCAN appears well suited to portable grants
and effect invocations. It cannot replace A-Lang's effect checker, typed
resource semantics, stateful policy, durable journal, cancellation,
compensation, or sandbox. Broker-owned session keys can stop model-controlled
subagents from redelegating, but UCAN alone cannot confine an external
principal that owns its signing key.

The inquiry remains open until a version-pinned, adversarial prototype exists.

## Working hypotheses

### H1 — attenuation safety

Every broker-produced child grant will denote a subset of both its parent's
authority and its compiler-inferred requirement. Generated command, policy,
and time changes will never expand the accepted invocation set.

### H2 — validator agreement

Two independent implementations will agree on canonical encoding, CIDs,
signatures, principal alignment, command coverage, accumulated policies, time
bounds, and negative fixtures for the A-Lang profile.

### H3 — key isolation

An LLM agent can complete representative tasks using only typed effect
operations and an opaque `CapabilityRef`, without seeing private keys, raw
root grants, or a general delegation primitive.

### H4 — execution safety

The BEAM effect gateway can validate authority, apply dynamic policy, journal
intent, and execute adapters without duplicate acknowledged effects under
worker and node fault injection.

### H5 — bounded adversarial cost

Fixed limits on container size, proof depth, policy complexity, DID methods,
algorithms, resolution, and decompression will make validation resource use
predictable under malformed input.

### H6 — resource coherence

The policy engine and each adapter will derive identical canonical resource
identities for paths, URLs, accounts, and tool instances, preventing a valid
string-level policy from authorizing a different semantic resource.

### H7 — revocation clarity

The UI and audit model can show that revocation removes a proof path rather
than necessarily removing equivalent authority, and the runtime can invalidate
all cached decisions that depend on the revoked CID.

### H8 — deployment value

Portable UCAN proofs will add measurable value when authority crosses a BEAM
node, sidecar, or organization. For same-node work, opaque broker handles will
remain the cheaper representation.

## Paths to explore

1. Pin the high-level, Delegation, and Invocation specification commits and
   publish an `alang-ucan-profile/0` compatibility document.
2. Define typed schemas and canonical resource semantics for workspace read,
   workspace write, web fetch, message send, and budgeted model invocation.
3. Create positive and negative fixtures and run them through the official Rust
   and Go implementations.
4. Implement an isolated signer and validator behind a framed BEAM port.
5. Give each task an ephemeral session DID and a short, broker-controlled grant.
6. Generate nested delegations and verify subset laws with PropEr.
7. Model replay, revocation, expiry, alternate proof paths, and cache
   invalidation as a state machine.
8. Inject process, port, and node failures around an intent/result journal.
9. Attack path traversal, symlinks, redirects, proof-resolution cycles,
   decompression, policy depth, clock skew, and algorithm confusion.
10. Compare latency, state, usability, and audit quality with a broker-only
    opaque-handle system.
11. Seek independent cryptographic and authorization review before enabling
    high-impact effects.

## Findings

- The 2026 main specifications cleanly distinguish Delegation from Invocation,
  which matches the language distinction between possessing authority and
  calling an effect.
- Attenuation has a tractable set interpretation: descendant commands narrow,
  policies accumulate by conjunction, and time intervals intersect.
- UCAN validation cannot establish external-resource ownership or dynamic
  policy facts; these remain execution-time responsibilities.
- Certificate chains do not provide confinement. Practical non-redelegation
  for model agents depends on broker key custody and a restricted signing API.
- Revocation is irreversible, path-specific, and potentially eventually
  consistent. It is not cancellation or compensation.
- The current ecosystem contains version skew, an explicitly unaudited Rust
  library, an incomplete implementation spread, and no official BEAM
  implementation located in this pass.
- The Invocation prose and current Go validator appear to use opposite proof
  ordering. A-Lang cannot freeze a profile until official fixtures or a
  clarification establish the intended canonical order.
- The full synthesis is in
  [UCAN capabilities for A-Lang](../20-notes/ucan-capabilities-for-agent-language.md),
  and the selective evidence trail is in the
  [UCAN map](../10-maps/ucan-and-delegated-agent-authority.md).

## Resolution criteria

Resolve positively only if:

- every generated delegation preserves the subset property;
- independent validators agree on the pinned profile;
- no model-visible interface can sign arbitrary delegations or invocations;
- canonical resource checks resist the adversarial suite;
- replay and fault-injection tests do not duplicate acknowledged effects;
- validation remains within declared resource bounds;
- portable proof gives a demonstrated benefit over local opaque handles;
- the remaining implementation risk is accepted after independent review.

Resolve negatively or narrow the design if persistent validator disagreement,
resource ambiguity, operational complexity, performance, or revocation needs
erase the portability advantage.

## Outcome

Open. The protocol-to-language mapping is promising and specific enough to
prototype, but no implementation or adversarial evaluation has yet established
that UCAN is the correct production authorization backend for A-Lang.
