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
home for the native compiler, Abstract Format adapter, BEAM runtime kernel,
and supporting code developed from the research archive and implementation
plans. Accepted A-Lang programs execute as loaded BEAM modules and supervised
ERTS processes; no host-language evaluator is an A-Lang runtime.

Keeping implementation source here separates claims and proposed work from
the code that tests them. Research belongs in the archive directories, while
ordered implementation work and its evidence remain under `60-planning`.

## What belongs here

- Native lexer, parser, type checker, intermediate representation, and
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

- [Phase 1 BEAM vertical slice](phase-01/README.md) — the executable runtime
  contract, pinned OTP compiler boundary, deterministic artifact builder, and
  isolated ERTS validation harness for the first proof-of-concept phase.

### Files

- None yet.

## Maintaining this index

Index every direct source file and subdirectory when it is added, linking a
subdirectory through its own README and briefly stating its role. Keep names
aligned with the architecture established by the active plan, and update the
relevant phase evidence when source code begins satisfying a planned gate.
