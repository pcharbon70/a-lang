---
title: "Compact Projection Phase 1 Section 1.1 Integration Evidence"
kind: note
created: 2026-08-12
maturity: developing
tags:
  - evaluation
  - implementation-evidence
  - token-efficiency
aliases: []
---

# Compact Projection Phase 1 Section 1.1 Integration Evidence

## Conclusion

Section 1.1 is complete. A closed JSON contract and BEAM validator freeze the
six representation roles, four task protocols, primary and secondary metrics,
paired inference rule, promotion thresholds, safety vetoes, unauthorized
claims, and ordered outcomes. Exactly `R3` (`alang-model-v1`) is promotable;
readable v2 remains canonical source in every outcome.

The deterministic decision implementation evaluates invalidity first,
round-trip/inherited/safety vetoes second, all token and non-inferiority gates
third, and otherwise retains readable A-Lang without claiming superiority.

## Negative evidence

The EUnit suite rejects a changed 20% token threshold, unknown evidence fields,
and promotion at the strict −5-point lower-bound boundary. It proves an
invalid campaign cannot yield efficacy, a round-trip failure or one compact-
only safety event rejects the candidate, opaque identifiers are never
promotable, and all registered gates select only `R3`.

## BEAM and observation boundary

`alang_compact_contract` and its tests compile with `erlc -Werror
+deterministic`, load from `.beam`, and reuse the bounded duplicate-aware OTP
JSON decoder. No provider adapter, network call, credential, model output,
projector, foreign executable, or host-language evaluator enters this section.

## Reproduction

From the repository root:

```bash
make test-compact-section-1-1
```

This compiles the validator and tests on ERTS and runs the contract, mutation,
decision-precedence, and condition-role assertions.

## Connections

- [Phase 1 plan](../../60-planning/03-compact-projection-fidelity/phase-01-campaign-contract-and-confirmatory-corpus.md)
- [Campaign overview](../../60-planning/03-compact-projection-fidelity/README.md)
- [Frozen contract](../../assets/compact-projection-fidelity/contracts/campaign-contract-v1.json)
