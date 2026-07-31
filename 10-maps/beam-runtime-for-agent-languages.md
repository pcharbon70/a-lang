---
title: "BEAM runtime for agent languages"
kind: map
created: 2026-07-31
tags:
  - agent-programming
  - beam
  - compiler-design
  - runtime-systems
aliases:
  - "BEAM for A-Lang"
---

# BEAM runtime for agent languages

## Scope

This map covers using ERTS and BEAM as the execution substrate for a new native
agent language. It separates the language's own syntax and categorical IR from
Core Erlang, supported OTP compiler interfaces, BEAM instructions, and the
runtime's process model.

The design explicitly excludes Erlang, Elixir, Gleam, or another BEAM language
as the main interpreter. Programs are compiled into BEAM modules and executed
by ERTS.

## Start here

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
  — the architecture, tradeoffs, validation strategy, and verdict.
- [Can BEAM support a native agent language safely?](../40-inquiries/can-beam-support-a-native-agent-language.md)
  — the open engineering hypotheses and prototype gates.

## Compiler boundary

- [OTP compiler guidance for language implementors](../30-sources/erlang-otp-2026-language-implementors.md)
  establishes Abstract Format as the preferred production target and warns
  against Core Erlang and BEAM assembly as external compiler contracts.
- [Core Erlang specification](../30-sources/carlsson-et-al-2004-core-erlang-specification.md)
  supplies a small explicit semantic model, but not a stable backend ABI.
- [BEAM execution](../30-sources/erlang-otp-2026-beam-execution.md) connects
  opcodes, loading, custom chunks, BeamAsm, and hot-code constraints.
- [Leex and Yecc](../30-sources/erlang-otp-2026-leex-and-yecc.md) can provide a
  bootstrap or differential parser, but generate Erlang modules and are not
  VM-level language-neutral parsing facilities.

## Agent execution model

- [Processes, signals, scheduling, and memory](../30-sources/erlang-otp-2026-process-runtime.md)
  explains why BEAM suits numerous waiting state machines and where mailbox,
  ordering, memory, and atom constraints appear.
- [Supervision and release handling](../30-sources/erlang-otp-2026-supervision-and-releases.md)
  provides fault-topology and code-version mechanics while clarifying why a
  restart is not a semantic retry.
- [Interoperability and secure coding](../30-sources/erlang-otp-2026-interoperability-and-security.md)
  places model servers and untrusted tools behind ports or sidecars and rejects
  same-node process isolation as a security sandbox.
- [UCAN capabilities for A-Lang](../20-notes/ucan-capabilities-for-agent-language.md)
  gives the broker-held `CapabilityRef` a concrete portable representation:
  keys remain in an isolated signer, while typed effects become short-lived
  signed invocations at execution boundaries.

## Laws and validation

- [PropEr](../30-sources/papadakis-sagonas-2011-proper.md) provides generators,
  shrinking, and state-machine testing on BEAM.
- [Concurrent Core Erlang formalisation](../30-sources/bereczky-et-al-2024-formalisation-concurrent-core-erlang.md)
  motivates trace observations and bisimulation instead of literal execution
  equality.
- [Categorical foundations for agent languages](categorical-foundations-for-agent-languages.md)
  defines the semantic laws whose implementation the BEAM backend must
  preserve.

## Recommended path

1. Own a small typed, effect-aware categorical IR.
2. Implement the source frontend outside existing BEAM languages.
3. Lower to a deliberately small Erlang Abstract Format subset.
4. Validate and compile through a pinned OTP toolchain.
5. run generated modules against a closed, capability-aware runtime ABI.
6. use ports or sidecars for inference, tools, and untrusted code.
7. make durability, deduplication, backpressure, and state migration explicit.
8. combine proof of the semantic core with property and model testing of the
   BEAM realization.

## Open questions

- Can the Abstract Format subset remain maintainable across OTP major releases?
- Which BEAM primitives should the IR expose directly, and which should remain
  behind runtime operations?
- Can generated agent supervision trees outperform a conventional durable
  workflow runtime without duplicating it?
- What observational equivalence is strong enough for categorical laws but
  tolerant of valid scheduler interleavings?
- How should dynamic modules be bounded when module names consume permanent
  atoms?
- Where is the correct trust boundary between signed BEAM artifacts and
  OS-sandboxed execution?
- Can a port-isolated UCAN validator remain version-compatible, bounded under
  hostile proof input, and consistent with the broker's typed resource model?
