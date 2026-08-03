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
- [`alang_phase4_broker.erl`](alang_phase4_broker.erl) — the bounded BEAM
  reference monitor with ordered authorization, typed decisions, redacted
  audit events, owner monitoring, and no-replay authorization lifecycles.
- [`alang_phase4_broker_sup.erl`](alang_phase4_broker_sup.erl) — one-for-one
  supervision and lookup for a broker that restarts without implicit grants.
- [`alang_phase4_broker_tests.erl`](alang_phase4_broker_tests.erl) — ordered
  decision, backpressure, audit-redaction, owner-death, timeout, and fail-closed
  restart evidence.
- [`alang_phase4_workspace_adapter.erl`](alang_phase4_workspace_adapter.erl) —
  the sealed BEAM manager for bounded framed Port calls, OS isolation, typed
  results, fault containment, and sidecar replacement.
- [`alang_phase4_workspace_sidecar.erl`](alang_phase4_workspace_sidecar.erl) —
  the fixed BEAM sidecar implementing normalized, symlink-safe, atomic,
  digesting, and lifetime-idempotent workspace writes.
- [`alang_phase4_workspace_adapter_tests.erl`](alang_phase4_workspace_adapter_tests.erl)
  — workspace scope, idempotence, isolation, bypass, crash, malformed-frame,
  timeout, replacement, and redaction evidence.
- [Workspace adapter contract](workspace-adapter-contract.md) — the sealed
  protocol, Bubblewrap and resource-limit profile, filesystem rules, outcome
  model, and explicitly deferred durability claims.
- [`alang_phase4_integration_fixture.erl`](alang_phase4_integration_fixture.erl)
  — typed workspace-effect IR promoted through the Phase 3 BEAM backend.
- [`alang_phase4_integration_tests.erl`](alang_phase4_integration_tests.erl) —
  loaded-artifact success, correlated trace, BEAM ownership, least-authority
  rejection, stale-grant, bypass, and no-side-effect phase gates.
- [Phase 4 integration evidence](phase-04-integration-evidence.md) — the
  reproducible authorized path, denial matrix, BEAM-residency observations,
  and boundary of the completed phase claim.

## Maintaining this index

Index every direct Phase 4 source, protocol document, and evidence file. Keep
the compiler and runtime path BEAM-resident; an OS process may appear only as a
bounded external effect adapter and never as an A-Lang interpreter or compiler.
