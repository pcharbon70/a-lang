---
title: "Phase 4 Local Capability Broker and Effect Boundary"
kind: map
created: 2026-08-03
tags:
  - beam
  - capability-security
  - directory-index
  - effect-systems
aliases:
  - "Phase 4 implementation index"
---

# Phase 4 Local Capability Broker and Effect Boundary (`src/phase-04`)

## Purpose

This directory implements the local capability broker and the first bounded
external effect path for A-Lang. The trusted registry, grant store, reference
monitor, supervision, and protocol components are Erlang modules compiled to
BEAM and executed by ERTS. A generated A-Lang module can name only a closed
effect identity and can reach an external adapter only through that broker.

## What belongs here

- The closed effect registry and its compiler, manifest, broker, adapter, and
  trace views.
- Opaque local grant state, restriction laws, ownership, revocation, and
  lifetime enforcement.
- The supervised BEAM reference monitor and its bounded audit trail.
- The isolated workspace adapter, framed sidecar protocol, and adversarial
  integration evidence.

Generated `.beam` files, temporary workspaces, traces, and other test evidence
remain under the ignored repository `build/` directory.

## Index

### Subdirectories

- None yet.

### Files

- [`alang_phase4_effect_registry.erl`](alang_phase4_effect_registry.erl) — the
  single closed definition of effect identities, schemas, adapters, trace
  names, request decoders, and manifest binding.
- [`alang_phase4_effect_registry_tests.erl`](alang_phase4_effect_registry_tests.erl)
  — view-consistency, typed-decoding, dynamic-dispatch, bounds, atom-safety,
  and artifact-manifest tests.
- [`alang_phase4_grants.erl`](alang_phase4_grants.erl) — broker-owned opaque
  reference state, structural invocation scopes, restriction and intersection
  laws, shared budgets, lifetime binding, and cascading revocation.
- [`alang_phase4_grants_tests.erl`](alang_phase4_grants_tests.erl) — generated
  restriction-law cases plus combination, budget, revocation, opacity, scope,
  and runtime-lifetime evidence.

## Maintaining this index

Index every direct Phase 4 source, protocol document, and evidence file. Keep
the compiler and runtime path BEAM-resident; an OS process may appear only as a
bounded external effect adapter and never as an A-Lang interpreter or compiler.
