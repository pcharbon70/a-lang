---
title: "Token-Positive Mnemonic Promotion Section 2.2 Integration Evidence"
kind: note
created: 2026-08-28
maturity: developing
tags:
  - beam
  - implementation-evidence
  - token-accounting
  - token-efficiency
aliases: []
---

# Token-Positive Mnemonic Promotion Section 2.2 Integration Evidence

## Four deterministic protocols

The BEAM protocol materializer produces condition-symmetric, single-turn
comprehension, generation, diagnostic-repair, and action/completion records for
all 48 fresh cases. Each prompt freezes its opaque trial ID, common and
protocol instructions, condition legend, case material, and output contract in
the registered order. Model-visible bytes contain no condition role, answer
key, semantic digest, hidden example, or cross-trial state.

All 384 condition/protocol oracle responses score valid and exact without an
LLM judge. Seventeen field, negation, digit, unit, path, dependency, error,
child-authority, and completion mutations change the registered meaning and
are scored distinctly under both conditions.

## Exact offline token gate

The exact BEAM BPE implementations count 96 document pairs and 384 complete-
request pairs. Every P1 count is strictly lower than its paired P0 count.
Standalone attribution is complete for layout, vocabulary, identifiers,
facts, paths, budgets, authority, completion, legends, instructions, and
output scaffolding.

| Tokenizer profile | P0/P1 document tokens | Aggregate / median document savings | P0/P1 request tokens | Aggregate / median request savings |
| --- | ---: | ---: | ---: | ---: |
| `cl100k_base` | 12,905 / 11,901 | 7.78% / 7.99% | 64,726 / 60,550 | 6.45% / 6.41% |
| `o200k_base` | 12,627 / 11,715 | 7.22% / 7.26% | 63,663 / 59,754 | 6.14% / 6.20% |

The candidate-conformance digest is
`e6ee9636709f4f24cac2d6bc1f25c8e52ec6cf130721fd136b48a0952d55d8a8`,
the protocol-oracle digest is
`288fc67e4d2ca6383af75f6515b6f94fb3b6f61733974b762bc147e96856a0a9`,
and the complete token-report digest is
`8ea2bed9ba1948ef8ea5075aaab7133c2ff2a197d6a1f17dacea3e989214a253`.

## Registration and authorization

Fifty Phase 1 inputs, Phase 2 contracts, external digest-pinned assets, and
trusted source modules produce registration digest
`603236e56a2abfab85366d795253ea3353e6067bd6ea7371612d80bd6713f486`.
Together with candidate, protocol, token, and schedule evidence, they produce
qualification digest
`e00fe1b40807d052523a2999fc3584d9a4e5cf6736766cc4f0565f9c09c7417f`.

The authorization validator rebuilds that evidence before accepting the exact
`ALANG_ALLOW_MNEMONIC_MODEL_CALLS=1` opt-in. Missing or different opt-in values,
stale evidence, a failed gate, prior calls, or any registered file drift fail
closed. Producing an authorization token does not itself perform a request.

## Tests and reproduction

```bash
make test-mnemonic-section-2-2
```

The target writes two byte-identical qualification records, requires their
exact comparison, runs eleven Section 2.2 tests plus the inherited Phase 1 and
Section 2.1 suites, and performs zero provider, model, or network calls. The
evidence explicitly makes no model-fidelity claim.

## Connections

- [Phase 2 plan](../../60-planning/04-token-positive-mnemonic-promotion/phase-02-mnemonic-candidate-and-offline-qualification.md)
  defines the protocol, token, registration, and authorization gates.
- [Qualification contract](../../assets/token-positive-mnemonic-promotion/phase-02/contracts/qualification-contract-v1.json)
  freezes the exact thresholds and registration boundary.
