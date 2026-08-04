---
title: "Phase 7 Typed Generators and Law Observations"
kind: note
created: 2026-08-04
maturity: developing
tags:
  - beam
  - categorical-semantics
  - property-based-testing
  - proper
aliases: []
---

# Phase 7 Typed Generators and Law Observations

## Boundary

PropEr 1.5.0 is a pinned, test-only BEAM dependency. It does not interpret
A-Lang, enter the deployable runtime, or satisfy an execution gate. Generated
A-Lang artifacts still pass through the Phase 2 frontend and Phase 3 backend,
are inspected, and execute as loaded BEAM modules on ERTS.

Every generated case carries an integer replay seed. The seed determines the
entire source or typed-IR case, so a reported counterexample can be rebuilt by
`alang_phase7_generators:case_from_seed/2` even when PropEr selected it during
a nondeterministic campaign.

## Generated domains

- `source` cases vary bounded integer inputs and additions, then exercise text
  parsing, deterministic ETF, static checking, IR lowering, and the
  nondeployable Phase 2 reference view.
- `pure_ir` cases cover application, products and projections, result
  injection and matching, bind, sequence, verifier nodes, and source origins.
- `effect_ir` cases cover a fixture-backed typed request and compare its result
  and normalized effect observation with compiled BEAM execution.

Shrinking changes the replay seed and reconstructs the complete case. It never
deletes an arbitrary node or rewrites a type in isolation; every emitted
candidate is revalidated against the Phase 3 IR contract.

## Equality and observations

Pure values use ordinary structural equality. Effectful comparisons retain
the result, verifier outcome, operation names, and causal trace order while
removing timestamps and canonicalizing fresh PIDs, references, and ports by
first occurrence. No scheduler trace is compared byte-for-byte.

The categorical campaign covers left and right identity, associativity,
product projections, result elimination, deterministic normalization, and
commutative set union for effect and requirement manifests. These generated
checks are falsification evidence, not mathematical proof.

## Reproduce

```bash
make test-section-7-1
```

This section implements the first part of the
[Phase 7 plan](../../60-planning/01-minimal-proof-of-concept/phase-07-law-security-fault-and-performance-validation.md)
and follows the archive's
[BEAM property-testing model](../../20-notes/beam-runtime-for-native-agent-language.md).
