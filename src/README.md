---
title: "A-Lang Source Code"
kind: map
created: 2026-07-31
tags:
  - compiler-implementation
  - directory-index
  - source-code
aliases:
  - "Source index"
---

# A-Lang Source Code (`src`)

## Purpose

This directory contains the executable implementation of A-Lang. It is the
home for the BEAM-resident compiler, Abstract Format adapter, BEAM runtime
kernel, and supporting code developed from the research archive and
implementation plans. Both trusted compiler passes and accepted A-Lang
programs execute as loaded BEAM modules on ERTS; no host-language evaluator is
an A-Lang runtime.

Keeping implementation source here separates claims and proposed work from
the code that tests them. Research belongs in the archive directories, while
ordered implementation work and its evidence remain under `60-planning`.

## What belongs here

- BEAM-resident lexer, parser, type checker, intermediate representation, and
  build-time compiler pipeline source.
- Erlang Abstract Format lowering, OTP compilation, artifact inspection, and
  loading components that produce executable BEAM modules.
- Generated coordinator behavior and supervised ERTS runtime processes for
  A-Lang sessions.
- Runtime, capability broker, authorization, durability, and agent-execution
  components.
- Shared implementation libraries and narrowly scoped build-time support.

Generated artifacts, dependency caches, and build outputs do not belong here.
Create a subdirectory only when an implemented architectural boundary needs
one, and give every new subdirectory its own local `README.md`.

A test-only IR evaluator may live here when it provides differential evidence,
but it must be clearly nondeployable and cannot satisfy a proof-of-concept
execution gate. A-Lang runtime results must come from loaded BEAM artifacts.

## Index

### Subdirectories

- [Effectful source fidelity implementation](effectful-source-fidelity/README.md)
  — the BEAM-native experiment contracts, paired corpus validators,
  deterministic scorer, and pre-registration evidence for the next
  architecture decision.
- [Phase 1 BEAM vertical slice](phase-01/README.md) — the executable runtime
  contract, pinned OTP compiler boundary, deterministic artifact builder, and
  isolated ERTS validation harness for the first proof-of-concept phase.
- [Phase 2 BEAM-resident compiler frontend and typed task IR](phase-02/README.md)
  — the OTP 29 compiler modules, minimal static semantics, normalized typed IR,
  test-only semantic views, and fail-closed bridge into the proven BEAM
  execution path.
- [Phase 3 Abstract Format backend and BEAM runtime kernel](phase-03/README.md)
  — the generalized BEAM-resident backend contract, OTP compilation path,
  closed runtime ABI, supervised task kernel, and artifact load policy.
- [Phase 4 local capability broker and effect boundary](phase-04/README.md) —
  the closed effect registry, opaque local authority, supervised reference
  monitor, and isolated workspace-effect boundary.
- [Phase 5 durable BEAM sessions and recovery](phase-05/README.md) — the
  versioned semantic state, integrity journal, supervised resume protocol,
  authority restoration, and crash-recovery evidence.
- [Phase 6 bounded LLM task and subagent execution](phase-06/README.md) — the
  typed model boundary, deterministic task control, structured repair,
  completion verification, and mechanically attenuated child-task runtime.
- [Phase 7 law, security, fault, and performance validation](phase-07/README.md)
  — the BEAM-native PropEr harness, explicit semantic observations, generated
  laws, adversarial cases, fault injection, and bounded measurements.
- [Phase 8 demonstration and proof-of-concept decision](phase-08/README.md) —
  the offline source-to-evidence package, matched ablations, architecture
  decision, risk ledger, and final acceptance gate.

### Files

- None yet.

## Maintaining this index

Index every direct source file and subdirectory when it is added, linking a
subdirectory through its own README and briefly stating its role. Keep names
aligned with the architecture established by the active plan, and update the
relevant phase evidence when source code begins satisfying a planned gate.
