---
title: "Token-Positive Mnemonic Promotion Section 2.1 Integration Evidence"
kind: note
created: 2026-08-28
maturity: developing
tags:
  - beam
  - implementation-evidence
  - source-maps
  - token-efficiency
aliases: []
---

# Token-Positive Mnemonic Promotion Section 2.1 Integration Evidence

## Exact candidate binding

P0 delegates to registered R0 and P1 delegates directly to registered R2.
The campaign wrapper neither rewrites nor post-processes the returned model-
visible bytes. Its contract pins the renderer, vocabulary, surface registry,
source-map implementation, and source-map contract by SHA-256; the candidate
contract itself has SHA-256
`5d2dd3ce50c7b38c39c608b702a9499636e79139604c2169041bf21c60ff1bba`.

The test suite compares P1 with a direct R2 render over 136 valid semantic
oracles: 24 development cases, 48 prior confirmatory cases, 48 new prospective
cases, and 16 deterministically generated cases. Every pair is byte-identical,
and P0, P1, and their decoders reproduce the same origin-free checked semantic
digest.

## Acceptance, aliases, and bounds

P1 decoding is the exact R2 decoder call with the frozen
`alang-source-v2-alias-v1` version. Valid, cross-group, unknown-alias,
malformed, invalid-UTF-8, oversized, and wrong-version inputs have identical
P1/R2 acceptance classes; successful decodes have identical semantic digests.
The candidate validator verifies the six frozen alias groups, unique readable
and compact terms within each group, the 32,768-byte bound, and fail-closed
version and reference identities.

## Source maps and diagnostics

Both conditions receive complete source maps from the pinned BEAM map builder.
Tests require contiguous byte coverage, every security-relevant field, readable
spans or explicit witnesses, and byte-identical maps after recursive input-map
order reversal. Diagnostics name readable source as their edit target and
retain candidate spans only as additional context.

## Tests and boundary

```bash
make test-mnemonic-section-2-1
```

Six Section 2.1 EUnit tests cover exact references, all 136 oracle pairs,
acceptance/decode conformance, version and bounds failures, stable source maps,
readable diagnostics, and trusted `.beam` residency. The command also reruns
all 29 Phase 1 tests. It performs no provider, model, or network call and makes
no model-fidelity claim.

## Connections

- [Phase 2 plan](../../60-planning/04-token-positive-mnemonic-promotion/phase-02-mnemonic-candidate-and-offline-qualification.md)
  defines the conformance and mapping gates satisfied here.
- [Candidate contract](../../assets/token-positive-mnemonic-promotion/phase-02/contracts/candidate-contract-v1.json)
  freezes the exact reused implementation boundary.
