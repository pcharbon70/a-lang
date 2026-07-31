---
title: "UCAN and delegated agent authority"
kind: map
created: 2026-07-31
tags:
  - agent-programming
  - authorization
  - capability-security
  - ucan
aliases:
  - "UCAN for agents"
---

# UCAN and delegated agent authority

## Scope

This map connects UCAN's certificate-capability protocol to A-Lang's
declarative effects, set-and-category semantics, BEAM runtime, and open
security questions. It distinguishes a task's authority requirement from a
signed grant and from the execution-time decision to permit an effect.

## Start here

- [UCAN capabilities for A-Lang](../20-notes/ucan-capabilities-for-agent-language.md)
  — the complete design, security analysis, and implementation proposal.
- [Can UCAN enforce A-Lang agent capabilities?](../40-inquiries/can-ucan-enforce-a-lang-agent-capabilities.md)
  — the active hypotheses and prototype gates.

## Protocol trail

- [UCAN specification](../30-sources/ucan-wg-2026-ucan-specification.md)
  defines the high-level certificate-capability system, proof chain, principals,
  time semantics, and execution-time validation requirement.
- [Delegation and Invocation](../30-sources/ucan-wg-2026-delegation-and-invocation.md)
  separates holding attenuated authority from requesting a concrete action.
- [Revocation](../30-sources/ucan-wg-2025-revocation.md) invalidates a proof CID
  but is eventually consistent, cannot remove alternate proof paths, and
  cannot undo an effect.
- [Implementations and container](../30-sources/ucan-wg-2026-implementations-and-container.md)
  identifies the current version skew, unaudited Rust implementation, Go
  comparison point, obsolete JWT-era TypeScript model, and lack of an official
  BEAM implementation.
- [SPKI Certificate Theory](../30-sources/ellison-et-al-1999-spki-certificate-theory.md)
  supplies the historical authorization-chain and intersection model while
  exposing UCAN's lack of a delegation-control bit.

## Language-semantics trail

- [Task languages for LLM agents](../20-notes/llm-agent-task-languages-deep-dive.md)
  introduces declarative effects, permissions, and runtime enforcement. UCAN
  gives the runtime grant and invocation layers a concrete interoperable form.
- [Set and category principles](../20-notes/set-and-category-principles-for-agent-programming-language.md)
  treats required authority as an annotation on typed task arrows. A UCAN
  capability denotes a set of accepted invocations; attenuation is subset
  inclusion, chain restrictions intersect, and independent grants unite.
- [Categorical foundations map](categorical-foundations-for-agent-languages.md)
  places those laws in the broader work on composition, effects, state, and
  interpreters.

## Runtime trail

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
  defines the compiler and runtime boundary. UCAN fits behind its
  `CapabilityRef` as broker-held authority rather than model-visible data.
- [BEAM runtime map](beam-runtime-for-agent-languages.md) connects ports,
  isolation, durability, supervision, and PropEr validation to the proposed
  authorization gateway.
- [PropEr](../30-sources/papadakis-sagonas-2011-proper.md) can generate command
  hierarchies, proof chains, policies, revocations, and replay traces to test
  attenuation and state-machine laws.
- [AgentSpec](../30-sources/wang-et-al-2026-agentspec.md) reinforces why the
  execution-time reference monitor remains necessary even when authority is
  cryptographically portable.

## Design boundary

The recommended flow is:

```text
effect declaration
  → inferred capability requirement
  → broker-held grant
  → signed UCAN Delegation
  → concrete signed Invocation
  → execution-time UCAN validation
  → stateful A-Lang policy
  → durable effect adapter
```

UCAN owns signed delegation and invocation. A-Lang owns the effect model,
resource semantics, broker, stateful policy, replay protection, durability,
compensation, and sandboxing.

## Open questions

- Can two independent version-1 validators agree on every A-Lang profile
  fixture?
- Does UCAN provide useful portability beyond an opaque broker handle in the
  actual deployment topology?
- Can broker key custody provide enough practical confinement for LLM-created
  subagents?
- How should external-resource ownership be specified and verified for each
  command namespace?
- Can revocation and replay state remain correct across BEAM nodes and
  partitions?
- Are authorization summaries understandable without revealing proof-chain
  secrets or graph topology?
