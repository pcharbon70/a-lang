---
title: "Token-Positive Mnemonic Promotion Section 1.2 Integration Evidence"
kind: note
created: 2026-08-27
maturity: developing
tags:
  - beam
  - corpus
  - experiment-design
  - implementation-evidence
aliases: []
---

# Token-Positive Mnemonic Promotion Section 1.2 Integration Evidence

## Power and sampling unit

The deterministic paired case-cluster audit retains all four protocols and
both repetitions inside each semantic case. With seed `2026082504`, 2,000
simulations per scenario, a five-point non-inferiority margin, and an 80%
central-scenario floor, central estimated power is 0.696 at 24 cases and 0.925
at 48 cases. The audit therefore selects the registered 48-case minimum. The
adverse scenario reaches 0.8575 only at 72 cases and remains a published
sensitivity analysis rather than an outcome-driven resizing rule.

The power-audit digest is
`c2abe700ff4315cbde0c62c847b5fff1f91bcc89067933fc4adf6a25615273b8`.

## Fresh corpus and authority

The corpus contains 48 new semantic cases: three runtime families by eight
strata by two replicates. Exact content scans find no overlap with the 24
effectful-source cases or the 48 compact-projection confirmatory cases. All 48
neutral oracles validate through the existing A-Lang semantic contract, have
unique semantic digests, and preserve model, workspace, path, budget, error,
completion, and child-attenuation bounds.

The corpus explicitly covers near-prefix paths, negation, numeric-value
perturbation, irrelevant context, and prompt injection. Requests and untrusted
context contain no P0/P1 or R2 labels, representation versions, semantic
digests, or answer-key markers. The corpus-evidence digest is
`d0ada49f5f8ff62b2f961ce3af8ddbae1544b6232001008eef711575c484fda7`.

## Profiles, prompts, schedule, and ceilings

The campaign retains the exact registered Ornith and Mixtral Ollama artifact
IDs, manifest hashes, request parameters, and the two pinned tokenizer
profiles. Prompt policy freezes four single-turn, example-free protocols and
both P0/P1 legends under SHA-256
`1adfed75683c6da2867f4666bbb0502b1b6d5705147b7a61a76ead09fbc7df11`.

The deterministic schedule contains 1,536 unique cells:

```text
48 cases × 2 conditions × 4 protocols × 2 models × 2 repetitions = 1,536
```

Every model, protocol, runtime-family, stratum, and repetition cell contains
equal P0/P1 counts. Trial IDs are opaque, adjacent cells never reuse a semantic
case, definitive responses are not retriable, at most one evidence-linked
transport replacement is allowed, and the hard request ceiling is 3,072. The
cell digest is
`ca8ac92d529c34ac45d4bef07718f4582bfddaad94406701fd611d52cd7e549e`.

## Tests and reproduction

Eleven Section 1.2 EUnit tests cover power selection and seed drift, fresh-
corpus balance and all-72-case separation, semantic and authority validity,
condition leakage, deterministic schedule shape and mutations, exact profiles,
offline policy, prompt closure, and trusted BEAM residency. Eight Section 1.2
JSON inputs also validate against their closed schemas.

```bash
make test-mnemonic-section-1-2
```

The command performs zero network, provider, or model calls. The combined
registration-evidence digest at this section boundary is
`26af3a4868ef03ae96a7a6b6bca3955766d579419ddda8a5badc3d363459e6b3`.

## Connections

- [Phase 1 plan](../../60-planning/04-token-positive-mnemonic-promotion/phase-01-token-positive-contract-and-fresh-corpus.md)
  defines the power, corpus, profile, prompt, schedule, and resource gates.
- [Fresh corpus](../../assets/token-positive-mnemonic-promotion/corpus/confirmatory-corpus-v1.json)
  is design evidence until the later authorized campaign produces model
  observations.
