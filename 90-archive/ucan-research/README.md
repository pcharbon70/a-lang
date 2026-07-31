---
title: "Archived UCAN Research"
kind: map
created: 2026-07-31
tags:
  - archive-navigation
  - capability-security
  - directory-index
  - ucan
aliases:
  - "Paused UCAN research"
---

# Archived UCAN Research (`90-archive/ucan-research`)

## Purpose

This directory preserves the UCAN research bundle that was removed from the
active A-Lang architecture and minimal proof-of-concept scope on 2026-07-31.
It keeps the evidence and reasoning recoverable without allowing UCAN-specific
assumptions to shape the current BEAM-first implementation plan.

There is no active replacement protocol. The proof of concept now uses a
small, local, BEAM-resident capability broker with opaque references and a
closed effect registry. Portable signed delegation is explicitly deferred.

## What belongs here

- The paused UCAN synthesis, map, and feasibility inquiry.
- Source notes collected specifically to evaluate UCAN and its alternatives.
- Historical reasoning useful if portable cross-trust-domain authorization is
  reconsidered after the BEAM proof of concept.

New active authorization research does not belong here. Create it in the
normal archive directories and link this bundle only when the historical
comparison is materially relevant.

## Index

### Subdirectories

- None yet.

### Documents

- [UCAN and delegated agent authority](ucan-and-delegated-agent-authority.md) —
  the archived map through the protocol and its proposed A-Lang integration.
- [UCAN capabilities for A-Lang](ucan-capabilities-for-agent-language.md) — the
  archived synthesis and design recommendation.
- [Can UCAN enforce A-Lang agent capabilities?](can-ucan-enforce-a-lang-agent-capabilities.md)
  — the paused feasibility and evaluation inquiry.
- [SPKI Certificate Theory](ellison-et-al-1999-spki-certificate-theory.md) —
  comparative certificate-capability foundations gathered for the study.
- [UCAN Revocation](ucan-wg-2025-revocation.md) — revocation semantics and
  their consistency limitations.
- [UCAN Delegation and Invocation](ucan-wg-2026-delegation-and-invocation.md) —
  the delegation and concrete invocation format evidence.
- [UCAN implementations and container](ucan-wg-2026-implementations-and-container.md)
  — implementation maturity, compatibility, audit, and transport evidence.
- [UCAN specification](ucan-wg-2026-ucan-specification.md) — the high-level
  certificate-capability and proof-chain model.

## Maintaining this index

Keep this bundle inactive unless a later decision explicitly reopens portable
delegation research. If that happens, create new active documents rather than
silently treating these dated conclusions as current, and link the new work
back here for provenance.
