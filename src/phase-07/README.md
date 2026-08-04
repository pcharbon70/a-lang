---
title: "Phase 7 Validation Harness"
kind: map
created: 2026-08-04
tags:
  - beam
  - directory-index
  - property-based-testing
  - runtime-validation
aliases: []
---

# Phase 7 Validation Harness (`src/phase-07`)

## Purpose

This directory contains the BEAM-native conformance, security, fault, and
performance harness for Phase 7 of the minimal proof of concept. Its test-only
reference models and PropEr properties may falsify implementation claims, but
they are not a deployable A-Lang interpreter and do not replace compiled BEAM
acceptance evidence.

## What belongs here

- Typed source, IR, capability, history, fault, and hostile-input generators.
- Explicit pure, trace, authority, durability, and completion observations.
- PropEr laws, state-machine properties, adversarial tests, fault injection,
  benchmarks, mutation checks, and reproducible evidence.
- Erlang bootstrap modules that compile to BEAM and execute on the pinned ERTS
  toolchain.

Generated dependencies and build products belong in the ignored `_build/` and
`build/` directories.

## Index

### Subdirectories

- None yet.

### Files

- [`alang_phase7_generators.erl`](alang_phase7_generators.erl) — replayable
  PropEr generators and validity-preserving semantic shrink candidates for
  source, promoted pure IR, and fixture-backed effect IR.
- [`alang_phase7_observation.erl`](alang_phase7_observation.erl) — explicit
  value, manifest, fresh-identity, and effect-trace normalization rules.
- [`alang_phase7_law_tests.erl`](alang_phase7_law_tests.erl) — generated
  categorical, serialization, shrinking, and reference-to-BEAM properties.
- [`alang_phase7_authority_model.erl`](alang_phase7_authority_model.erl) — the
  finite resource universe and set observation used to check grant
  restriction independently of the implementation.
- [`alang_phase7_history_model.erl`](alang_phase7_history_model.erl) — a small
  effect-transition oracle with safety and bounded-settlement invariants.
- [`alang_phase7_state_property_tests.erl`](alang_phase7_state_property_tests.erl)
  — generated grant, binding, budget, journal, recovery, and liveness histories.
- [`alang_phase7_adversarial.erl`](alang_phase7_adversarial.erl) — bounded
  binary mutation, exception classification, and recursive secret/runtime-
  identity leak scanning utilities.
- [`alang_phase7_adversarial_tests.erl`](alang_phase7_adversarial_tests.erl) —
  generated parser, IR, forms, artifact, ABI, effect, and model attacks plus
  targeted size, atom, grant, path, adapter, context, and disclosure cases.
- [`alang_phase7_fault_campaign.erl`](alang_phase7_fault_campaign.erl) — the
  complete component-by-transition fault manifest, monitored process probes,
  and post-recovery invariant checks.
- [`alang_phase7_bench.erl`](alang_phase7_bench.erl) — reproducible BEAM-native
  latency, typed-control baseline, concurrency, grant, and payload-pressure
  measurements with runtime environment evidence.
- [`alang_phase7_fault_performance_tests.erl`](alang_phase7_fault_performance_tests.erl)
  — executable completeness, percentile, baseline, and pressure assertions for
  Section 7.4.
- [Typed generators and law observations](typed-generators-and-law-observations.md)
  — the dependency boundary, generated domains, equality rules, and
  reproduction command for Section 7.1.
- [Authorization and runtime state properties](authorization-and-state-properties.md)
  — the finite-set capability oracle, generated histories, invariants, limits,
  and reproduction command for Section 7.2.
- [Adversarial boundary testing](adversarial-boundary-testing.md) — the
  implemented boundary inventory, attack classes, explicit limits, leak gate,
  and Section 7.3 reproduction command.
- [Fault and performance characterization](fault-and-performance-characterization.md)
  — the 63-case campaign, measured operations, comparison baseline, pressure
  scenarios, limits, and Section 7.4 reproduction command.

## Maintaining this index

Index every direct file and subdirectory when it is added. Keep generated
case counts, replay rules, observations, limits, and evidence synchronized
with the Phase 7 roadmap and executable test targets.
