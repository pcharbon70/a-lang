---
title: "SPKI Certificate Theory"
kind: source
created: 2026-07-31
authors:
  - "Carl M. Ellison"
  - "Bill Frantz"
  - "Butler Lampson"
  - "Ron Rivest"
  - "Brian Thomas"
  - "Tatu Ylonen"
published: 1999
citation_key: ellison1999SPKI
container: "RFC 2693"
edition: "Experimental"
url: "https://www.rfc-editor.org/rfc/rfc2693.html"
accessed: 2026-07-31
tags:
  - authorization
  - capability-security
  - delegation
  - spki
aliases:
  - "RFC 2693"
  - "SPKI/SDSI certificate theory"
---

# SPKI Certificate Theory

## Reference

Carl M. Ellison, Bill Frantz, Butler Lampson, Ron Rivest, Brian Thomas, and
Tatu Ylonen. “SPKI Certificate Theory.” RFC 2693, Experimental, September
1999. [RFC](https://www.rfc-editor.org/rfc/rfc2693.html)

## Contribution

SPKI defines authorization certificates that bind permissions directly to
public keys and permits a key holder to pass all or part of that authorization
to another key. Its tuple-reduction rules compose certificate chains by
intersecting authorization and validity constraints.

## Findings

- Authorization can be carried by certificates without deriving it from a
  globally meaningful personal name.
- Delegation is explicit. An authorization certificate states whether the
  grantee may further delegate its authorization.
- Chaining narrows rather than expands authority: authorization intersections
  and validity intersections are central reduction operations.
- A verifier still needs application semantics for interpreting the
  authorization expression and deciding whether it covers a requested action.

## Relevance

UCAN explicitly presents itself as a modern, web- and native-friendly relative
of SPKI/SDSI. SPKI makes the set-theoretic structure of certificate delegation
clear: each grant denotes permitted operations; composing a chain intersects
those sets and validity intervals.

It also exposes a consequential difference. SPKI has a delegation-control bit,
whereas current UCAN certificate chains do not provide confinement and permit
downstream delegation. A-Lang can simulate nondelegable grants only while its
trusted broker retains the delegate's signing key and refuses to issue further
delegations; it cannot impose that property on an external principal that owns
its key using UCAN alone.

## Limits

- RFC 2693 is an Experimental RFC from 1999 and does not specify the current
  UCAN encoding, DID integration, invocation format, or policy language.
- Its authorization-expression algebra does not by itself solve the semantic
  interpretation or external-resource ownership problem.
- The useful relationship here is conceptual ancestry and comparison, not
  protocol compatibility.

## Derived notes

- [UCAN capabilities for A-Lang](../20-notes/ucan-capabilities-for-agent-language.md)
- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
