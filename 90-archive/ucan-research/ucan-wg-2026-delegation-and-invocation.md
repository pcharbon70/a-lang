---
title: "UCAN Delegation and Invocation Specifications"
kind: source
created: 2026-07-31
authors:
  - "UCAN Working Group"
published: 2026
citation_key: ucanWG2026DelegationInvocation
container: "UCAN Working Group specifications"
edition: "Version 1.0.0 on the main branches"
url: "https://github.com/ucan-wg/delegation"
accessed: 2026-07-31
tags:
  - authorization
  - capability-security
  - delegation
  - ucan
aliases:
  - "UCAN Delegation"
  - "UCAN Invocation"
---

# UCAN Delegation and Invocation Specifications

> **Archived 2026-07-31:** UCAN was removed from the active A-Lang
> architecture and proof-of-concept scope. This source note is retained only
> as provenance for the paused research.

## Reference

UCAN Working Group. “UCAN Delegation Specification.” Version 1.0.0 on
the main branch, 2026.
[Delegation specification](https://github.com/ucan-wg/delegation)

UCAN Working Group. “UCAN Invocation Specification.” Version 1.0.0 on
the main branch, 2026.
[Invocation specification](https://github.com/ucan-wg/invocation)

The Delegation authors are Brooklyn Zelenka, Daniel Holmgren, Irakli
Gozalishvili, Philipp Krüger, and Hugo Dias. The Invocation authors are
Brooklyn Zelenka, Irakli Gozalishvili, Zeeshan Lakhani, and Hugo Dias.

## Status read on 2026-07-31

Both main branches identify as version 1.0.0 and were updated on 2026-07-08.
They should be consumed together with a pinned version of the high-level UCAN
specification.

## Contribution

Delegation defines how a principal signs authority over to an audience.
Invocation defines a distinct signed request to exercise that authority. This
separation is analogous to the distinction between possessing a reference to a
function and calling it.

The Delegation payload includes `iss`, `aud`, `sub`, `cmd`, `pol`, `nonce`,
and time bounds. The Invocation payload includes the invoker, subject and
optional executor audience, a concrete command and arguments, proof CIDs,
nonce, expiry, and optional causal provenance.

## Findings

### Delegation and attenuation

- The subject is normally a DID that anchors the chain. An external resource
  is semantic rather than syntactic: it is usually named in policy arguments,
  and the executor must know how the subject owns or controls it.
- A `null` subject creates the “Powerline” pattern, which automatically carries
  future delegations across subjects. It must not root a resource and is much
  broader than an ordinary task grant.
- Commands are hierarchical paths. Delegating `/` grants all commands in the
  namespace and is consequently high risk.
- A policy is a predicate tree evaluated over invocation arguments. Its small
  language supports comparison, glob matching, Boolean connectives,
  quantification, and jq-like selectors.
- The top-level policy array is an implicit conjunction. Semantic or stateful
  conditions that cannot be decided from arguments are explicitly left to the
  executor.
- Principal alignment requires the audience of each proof to match the issuer
  of the next link.

An important executable interpretation appears in the current reference
implementations: each ancestor policy remains in force and all are evaluated
against the invocation arguments. Attenuation therefore does not require a
general theorem prover for arbitrary predicate implication; a descendant can
add restrictions but cannot erase an ancestor's restrictions.

### Invocation and execution

- An invocation requests execution; a delegation by itself should not be
  treated as a request.
- The invocation must identify the entire direct proof path from the subject
  to the invoker using CIDs.
- The arguments must have the shape defined for the command and satisfy the
  policies of all delegation proofs.
- A random nonce distinguishes non-idempotent tasks. An empty nonce is
  recommended when repeated invocations intentionally identify the same
  idempotent task.
- The content-derived task identifier covers subject, command, arguments, and
  nonce. It can therefore be used in deduplication and provenance, but an
  executor still needs replay state and effect-specific idempotency rules.
- Invocation expiry should normally be measured in minutes.
- The optional `cause` link connects an invocation to the receipt that
  requested it, preserving causal provenance.
- An executor may accept invocations to public resources without a closed
  proof loop, but the specification says this should not be the default.

## Relevance

The two artifacts map naturally to A-Lang:

- the compiler calculates an authority requirement;
- a trusted broker issues an attenuated Delegation to an agent session;
- a typed effect request becomes an Invocation with concrete arguments;
- the executor verifies the chain and applies the effect.

This permits a language-level `requires` declaration to remain declarative
while a separately signed runtime grant proves that one particular principal
may exercise it. It also makes invocations useful durable intent records at an
effect boundary, provided A-Lang adds result journaling and deduplication.

## Limits

- The policy language deliberately cannot decide stateful budgets, current
  resource ownership, approvals, rate limits, or whether a path resolves
  through a symlink. A reference monitor still has to enforce these facts.
- Glob and string rules are unsafe substitutes for canonical resource
  semantics. A-Lang should normalize typed resource identifiers before policy
  evaluation.
- Powerline and root command delegations are too broad for ordinary subagent
  grants.
- The formats prove a chain of assertions; they do not make an executor's
  interpretation of a command correct.

## Derived notes

- [UCAN capabilities for A-Lang](ucan-capabilities-for-agent-language.md)
- [Can UCAN enforce A-Lang agent capabilities?](can-ucan-enforce-a-lang-agent-capabilities.md)
