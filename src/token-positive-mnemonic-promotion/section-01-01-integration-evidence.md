---
title: "Token-Positive Mnemonic Promotion Section 1.1 Integration Evidence"
kind: note
created: 2026-08-27
maturity: developing
tags:
  - beam
  - evaluation
  - implementation-evidence
  - token-efficiency
aliases: []
---

# Token-Positive Mnemonic Promotion Section 1.1 Integration Evidence

## Implemented boundary

Section 1.1 introduces a separate P0/P1 contract without changing the
historical stream-03 registration. P0 is the nonpromotable readable R0 surface;
P1 is the sole candidate and points to the exact R2 representation and version.

The contract pins SHA-256 identities for the existing BEAM surface renderer,
projection vocabulary, and surface registry. It requires byte-for-byte
rendering, accept-or-reject, and checked-semantic decode conformance. The
validator recomputes all three hashes from repository files and fails closed
on a mismatch.

## Ordered decision evidence

The BEAM decision applies five mutually exclusive outcomes in this order:
campaign validity, token eligibility, safety, fidelity, and promotion. Exact
offline document and full-request savings are required per tokenizer;
provider-input savings and total-token nonregression are required per model
family and protocol. Fidelity cannot offset a token failure.

Twelve EUnit tests cover exact R2 identity, the historical nonpromotable role,
threshold mutation, reference mutation, every decision branch, strict
non-inferiority, provider pair regression, unknown evidence, and precedence.
The compiled validator loads from a deterministic `.beam` artifact on ERTS.

## Reproduction

```bash
make test-mnemonic-section-1-1
```

The command performs no network, provider, or model call. Generated BEAM files
remain under the ignored `build/token-positive-mnemonic-promotion/` tree.

## Connections

- [Phase 1 plan](../../60-planning/04-token-positive-mnemonic-promotion/phase-01-token-positive-contract-and-fresh-corpus.md)
  defines the tasks this evidence satisfies.
- [Campaign contract](../../assets/token-positive-mnemonic-promotion/contracts/campaign-contract-v1.json)
  is the machine-readable source for the roles, gates, and outcomes.
