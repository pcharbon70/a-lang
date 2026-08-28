---
title: "Token-Positive Mnemonic Promotion Section 2.3 Integration Evidence"
kind: note
created: 2026-08-28
maturity: developing
tags:
  - beam
  - implementation-evidence
  - mutation-testing
  - token-efficiency
aliases: []
---

# Token-Positive Mnemonic Promotion Section 2.3 Integration Evidence

## Complete replay

The Phase 2 verifier replays exact P0/P1 rendering, semantic decoding, and
source mapping across 136 pairs: 24 development cases, 48 prior confirmatory
cases, 48 fresh prospective cases, and 16 generated cases. It validates 272
source maps and six valid and adversarial acceptance-class comparisons against
direct R2. The replay digest is
`fd54ce23908c3d2f4b478f7f87db67244df406dab01a4c7315eb766387eb72d9`.

The replay reconciles qualification digest
`e00fe1b40807d052523a2999fc3584d9a4e5cf6736766cc4f0565f9c09c7417f`
and final 50-file registration digest
`351f07c0d0b91f1d34426cc74789b782b3249650a3ed38f2ebd14e10176e4d05`
with the authorization contract, token report, protocol oracles, and seeded
schedule.

## Mutation adequacy

All 18 named mutants are detected: candidate reference and byte drift,
cross-group and unknown aliases, version drift, a source-map gap, token-
negative documents and requests, missing attribution, threshold relaxation,
semantic-oracle drift, prompt-policy drift, authorization-digest drift, a
missing live opt-in, model-profile drift, schedule-seed drift, a foreign
trusted source, and a forbidden runtime import.

These are local gate mutations. Their 18/18 result demonstrates coverage of
the named Phase 2 hazards; it is not a global estimate of mutation adequacy.

## Trusted BEAM closure

The residency audit records source and deterministic BEAM SHA-256 identities
for 16 lexer, parser, checker, renderer, decoder, tokenizer, map, protocol,
qualification, and authorization modules. Their BEAM import tables contain no
port, NIF, shell, interpreted-form, or other registered forbidden mechanism.
All trusted sources are Erlang files and execute on ERTS.

## Clean evidence and boundary

```bash
make test-mnemonic-phase-2
```

The command runs 52 EUnit tests across Phases 1 and 2, independently rebuilds
qualification and final evidence twice, and requires byte-identical output
pairs. Final Phase 2 evidence digest
`9e1d5d6f9174839ac3a44fa0d1629aad51d88d97528108ecd603940d792470c8`
records zero hosted calls, zero efficacy observations, disabled network access,
and no model-fidelity claim.

Phase 2 qualifies the campaign for the separately explicit Phase 3 live
authorization path. It does not execute that path or claim that P1 preserves
model fidelity.

## Connections

- [Phase 2 plan](../../60-planning/04-token-positive-mnemonic-promotion/phase-02-mnemonic-candidate-and-offline-qualification.md)
  defines the completed conformance, token, mutation, and residency gates.
- [Phase 3 plan](../../60-planning/04-token-positive-mnemonic-promotion/phase-03-authorized-two-model-campaign.md)
  owns all hosted observations and provider token usage.
