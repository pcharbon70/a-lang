---
title: "UCAN Revocation Specification"
kind: source
created: 2026-07-31
authors:
  - "Brooklyn Zelenka"
  - "Irakli Gozalishvili"
  - "Philipp Krüger"
published: 2025
citation_key: ucanWG2025Revocation
container: "UCAN Working Group specification"
edition: "Version 1.0.0-rc.1"
url: "https://github.com/ucan-wg/revocation"
accessed: 2026-07-31
tags:
  - authorization
  - capability-security
  - revocation
  - ucan
aliases:
  - "UCAN revocation"
---

# UCAN Revocation Specification

## Reference

Brooklyn Zelenka, Irakli Gozalishvili, and Philipp Krüger. “UCAN Revocation
Specification.” Version 1.0.0-rc.1, UCAN Working Group, main branch last
updated in 2025.
[Specification](https://github.com/ucan-wg/revocation)

## Contribution

The specification defines an immutable, signed message that invalidates a
particular Delegation CID when that delegation is used as a proof. It is
designed for the local-first and partition-tolerant operating assumptions of
UCAN rather than for globally synchronous invalidation.

## Findings

- Revocations are irreversible and form a monotonically growing, append-only
  set. An erroneous revocation is repaired by issuing a different delegation,
  not by retracting the revocation.
- Validation checks every proof CID against the applicable revocation cache.
- Revoking one proof path does not necessarily remove the authority. The same
  principal may possess another valid chain for an equivalent capability.
- Resource-controlling subjects must maintain their relevant revocation cache;
  other agents may gossip and cache revocations.
- The consistency model may be merely eventual. The protocol does not promise
  that every executor learns a revocation before the next invocation.
- Revocation authority can itself be delegated.
- Revocation cannot undo an irreversible effect such as a sent message. The
  specification prefers narrow scope and short expiry, with revocation as a
  fallback.

## Relevance

A-Lang must distinguish three operations that are easy to conflate:

1. cancelling work that has not executed;
2. revoking one future authorization proof;
3. compensating for an effect that already occurred.

UCAN Revocation addresses only the second. In a BEAM deployment, executors
need a revocation store and a dependency index so cached validation results can
be invalidated transitively. High-risk centralized effects should additionally
require an online decision from the A-Lang capability broker, because eventual
revocation is not a hard real-time kill switch.

## Limits

- This sub-specification remains at `v1.0.0-rc.1` and has terminology and
  examples that do not fully track the 2026 version-1 main specifications.
- Eventual dissemination creates an explicit post-revocation exposure window.
- Revoking a proof does not prove that all equivalent authority has disappeared.
- The mechanism cannot recover secrets already disclosed or compensate prior
  external mutations.

## Derived notes

- [UCAN capabilities for A-Lang](../20-notes/ucan-capabilities-for-agent-language.md)
- [Can UCAN enforce A-Lang agent capabilities?](../40-inquiries/can-ucan-enforce-a-lang-agent-capabilities.md)
