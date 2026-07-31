---
title: "User Controlled Authorization Network (UCAN) Specification"
kind: source
created: 2026-07-31
authors:
  - "Irakli Gozalishvili"
  - "Daniel Holmgren"
  - "Philipp Krüger"
  - "Brooklyn Zelenka"
published: 2026
citation_key: ucanWG2026Specification
container: "UCAN Working Group specification"
edition: "Version 1.0.0 on the main branch"
url: "https://github.com/ucan-wg/spec"
accessed: 2026-07-31
tags:
  - authorization
  - capability-security
  - distributed-systems
  - ucan
aliases:
  - "UCAN specification"
---

# User Controlled Authorization Network (UCAN) Specification

## Reference

Irakli Gozalishvili, Daniel Holmgren, Philipp Krüger, and Brooklyn Zelenka.
“User Controlled Authorization Network (UCAN) Specification.” Version 1.0.0
on the main branch, UCAN Working Group, 2026.
[Specification](https://github.com/ucan-wg/spec)

Brooklyn Zelenka is also the specification editor.

## Status read on 2026-07-31

The main branch identifies itself as version 1.0.0 and was last changed on
2026-07-08. The repository's newest tag is still `v1.0-rc.1`, from 2024, and
there is no corresponding GitHub release for 1.0.0. This note cites the main
branch as read on the access date rather than implying that a final tagged
release exists.

## Contribution

UCAN defines a public-key-verifiable, delegable certificate-capability scheme.
Principals are represented by decentralized identifiers (DIDs); a chain of
signed delegations carries authority from a subject to the eventual invoker;
and an executor validates that proof chain when an invocation is executed.

The high-level capability model is a triple:

```text
subject × command × policy
```

Commands form slash-delimited hierarchies. A delegation for `/crypto` covers
nested commands such as `/crypto/sign`, while a delegation for the nested
command does not expand back to its parent. Policy further constrains the
arguments with which the command may be invoked.

## Findings

- UCAN is closer to SPKI-style certificate capabilities than to in-process
  object capabilities. It supports self-verifying delegation across machines
  and partitions, but does not itself provide object-capability confinement.
- Authority is the union of the capabilities a principal can prove. Along one
  delegation chain, every link must preserve or attenuate the claimed
  authority.
- Validation is required at execution time, even when a delegation was checked
  earlier.
- The effective validity interval is the intersection of the chain's time
  bounds: the latest `nbf` through the earliest `exp`.
- Private keys should remain in their original contexts. The specification
  recommends separate keys by device and use case, and short validity windows
  and minimal authority for delegates.
- A structurally and cryptographically valid chain may still be semantically
  invalid. The executor must verify the subject's relationship to external
  resources and understand the relevant command and policy semantics.
- Certificate chains do not provide confinement. A delegate can further
  delegate its authority without informing the original delegator.
- Proof resolution is transport-specific. If a referenced content identifier
  cannot be resolved, validation fails.
- Signed metadata is authenticated but is not part of delegated authority.

The current envelope profile uses canonical DAG-CBOR and content identifiers,
not the JWT representation found in early UCAN tutorials. The specification
requires support for `did:key` and describes Ed25519, P-256, and secp256k1
cryptographic suites.

## Relevance

UCAN supplies a concrete wire format and verification model for the portable
runtime grants anticipated by A-Lang's declarative capability design. It does
not replace A-Lang's effect types, requirement inference, dynamic policy
checks, durable execution, or operating-system isolation.

Its most important architectural contribution is to separate authority from
identity-server lookup: an agent can present a signed, attenuated proof chain
to an executor without asking a central authorization server on every action.
That is useful for delegated subagents and distributed BEAM nodes if keys and
proofs remain outside model-visible context.

## Limits

- The final-version label on the main branch is newer than the published tag,
  so implementers must pin a commit or explicit compatibility profile.
- “Trustless” does not mean free of trust. Correctness still depends on root
  authority, DID and key handling, clocks, command semantics, proof resolution,
  revocation knowledge, and executor behavior.
- The specification provides neither confinement nor compensation for effects
  already executed.
- No independent formal security proof or third-party audit was located during
  this research pass. That absence is a maturity signal, not proof that no such
  work exists.

## Derived notes

- [UCAN capabilities for A-Lang](../20-notes/ucan-capabilities-for-agent-language.md)
- [Can UCAN enforce A-Lang agent capabilities?](../40-inquiries/can-ucan-enforce-a-lang-agent-capabilities.md)
- [UCAN and delegated agent authority](../10-maps/ucan-and-delegated-agent-authority.md)
