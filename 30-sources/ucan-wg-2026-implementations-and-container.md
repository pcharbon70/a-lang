---
title: "UCAN Implementations and Transport Container"
kind: source
created: 2026-07-31
authors:
  - "UCAN Working Group"
published: 2026
citation_key: ucanWG2026Implementations
container: "Official UCAN Working Group repositories"
edition: null
url: "https://github.com/ucan-wg"
accessed: 2026-07-31
tags:
  - authorization
  - capability-security
  - implementation
  - ucan
aliases:
  - "UCAN implementation survey"
---

# UCAN Implementations and Transport Container

## Reference

UCAN Working Group. Official implementation and transport repositories,
inspected 2026-07-31:

- [Rust implementation](https://github.com/ucan-wg/rs-ucan)
- [Go implementation](https://github.com/ucan-wg/go-ucan)
- [TypeScript implementation](https://github.com/ucan-wg/ts-ucan)
- [Transport-independent container](https://github.com/ucan-wg/container)

## Method

This is a version-and-maturity reading of the official repositories, not an
independent security audit or implementation benchmark. Repository metadata,
README compatibility statements, release tags, and implemented features were
compared with the current specification family.

## Findings

### Rust

`rs-ucan` is active and uses a workspace built for `no_std` contexts, forbids
unsafe code in its principal crate, and includes property-based tests. Its
README says that the libraries conform to `v1.0.0-rc.1` and explicitly warns
that the code has not been formally audited. Version references across README,
crate workspace, and repository tags are not fully aligned.

### Go

`go-ucan` has a `v1.1.0` release from 2025 and implements the required
high-level, Delegation, and Invocation specifications. Its documentation still
references the release-candidate specification profile, and it does not yet
claim implementation of Revocation or Promise.

The validator's chain-walking behavior is especially relevant to A-Lang: it
checks that each command covers its descendant and evaluates the conjunction
of policies accumulated along the proof chain against the invocation
arguments.

It also exposes a current interoperability question. The 1.0.0 Invocation
text says that the `prf` array starts with the root Delegation and follows the
direct line toward the invoker. The Go `Token.New` documentation and
`verifyProofs` implementation instead require and walk the leaf matching the
invocation first, then proceed toward the root. This study does not choose one
by assumption: an A-Lang profile must settle the canonical order against
official fixtures or a specification clarification and reject the other order.

### TypeScript

`ts-ucan` describes UCAN 0.8.1 as JWTs with the older `att`/`with`/`can`
vocabulary. It is not a compatible implementation of the current 1.0
DAG-CBOR envelope and must not be used as a version-1 implementation guide.

### Container and transport

The current UCAN specification leaves proof resolution and transport open. The
separate container repository defines a CBOR container for transmitting token
bytes, with optional compression and text encoding. It deliberately carries
token content rather than claimed CIDs, allowing the receiver to calculate and
verify CIDs instead of trusting an index supplied by the sender.

Older UCAN HTTP Bearer and JWT examples belong to an earlier protocol model.
For version 1, an A-Lang transport must carry or resolve DAG-CBOR tokens and
their proof CIDs and must place resource bounds on chain depth, token size,
policy complexity, decompression, and resolution work.

### BEAM availability

No official version-1 BEAM implementation was found in the UCAN Working Group
organization during this research pass. This is evidence about the official
organization on the access date, not a claim that no third-party experiment
exists anywhere.

## Relevance

The safest first integration is a version-pinned validator and signer behind a
small port or sidecar protocol. Rust is attractive for a contained validator;
Go is attractive for comparing chain semantics. Neither should define
A-Lang's internal capability IR.

Starting with a port or sidecar preserves BEAM fault isolation and avoids
letting unaudited parsing and cryptography run as a native implemented function
inside ERTS. A later native implementation can be justified by profiling and
cross-checked against shared fixtures and an independent validator.

## Limits

- Repository activity and README claims do not establish security.
- Compatibility labels trail the current main specifications, and proof order
  currently appears inconsistent between the Invocation text and Go code.
- The implementation survey found no reported independent audit and no
  official BEAM implementation.
- Promise and receipt specifications are not mature enough to define A-Lang's
  durable workflow semantics; A-Lang needs its own intent/result journal.

## Derived notes

- [UCAN capabilities for A-Lang](../20-notes/ucan-capabilities-for-agent-language.md)
- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
