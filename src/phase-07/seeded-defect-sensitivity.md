---
title: "Phase 7 Seeded-Defect Sensitivity"
kind: note
created: 2026-08-04
maturity: developing
tags:
  - mutation-testing
  - property-based-testing
  - runtime-validation
  - security-testing
aliases: []
---

# Phase 7 Seeded-Defect Sensitivity

## Purpose

Passing properties can be vacuous, coupled to the implementation, or aimed at
the wrong boundary. This test-only mutation harness therefore introduces one
controlled bad behavior for every principal Phase 7 semantic, backend,
authorization, and recovery claim and requires a named detector to distinguish
it from the accepted behavior.

The mutants are local functions in `alang_phase7_mutation`; they are never
selected by the compiler, runtime, broker, adapter, or release path. Each
result records the detector, expected and mutant observations, and a small
counterexample. This is sensitivity evidence, not a general mutation score.

## Semantic and backend mutations

Eight mutations break identity, composition order, result branching, effect
union, manifest requirements, product serialization, effect evaluation order,
and the runtime ABI-to-adapter mapping. Their detectors correspond to the
categorical, manifest, canonicalization, differential, trace, and adversarial
checks in Sections 7.1 and 7.3.

## Authorization and recovery mutations

Nine mutations widen a child restriction, disjoin accumulated policy, ignore
expiry, ignore session and generation bindings, accept revocation, authorize
two requests against budget one, use textual instead of segment-aware path
containment, reorder a journal before validation, and retry an uncertain
submission. The finite authority, grant lifecycle, broker/history, resource,
journal, and recovery detectors reject all nine.

## Limits

The seeded examples show that each intended observation can detect its chosen
fault. They do not estimate the fraction of all possible implementation faults
that Phase 7 would detect, and they do not replace independent review of the
test oracles.

## Reproduce

```bash
make test-section-7-5
```

See the [Phase 7 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-07-law-security-fault-and-performance-validation.md)
and [typed law observations](typed-generators-and-law-observations.md).
