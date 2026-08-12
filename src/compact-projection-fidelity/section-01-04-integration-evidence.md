---
title: "Compact Projection Phase 1 Section 1.4 Integration Evidence"
kind: note
created: 2026-08-12
maturity: developing
tags:
  - evaluation
  - implementation-evidence
  - preregistration
  - token-efficiency
aliases: []
---

# Compact Projection Phase 1 Section 1.4 Integration Evidence

## Conclusion

Phase 1 is complete. Twelve closed schemas and BEAM validators reconcile the
scientific contract, power selection, 48 held-out cases and oracles, exact
provider and tokenizer identities, projection vocabulary, protocol prompts,
legends, traceability, request ceilings, and deterministic 2,304-cell
schedule. The canonical record contains zero hosted calls, zero efficacy
observations, and no network authorization.

This record authorizes Phase 2 projection implementation against fixed design
inputs. It does not authorize a model-visible request. Phase 4 must still
qualify the implemented projectors and protocol materialization, freeze their
exact bytes, and satisfy the explicit call gate.

## Canonical identity

The ordered registration contains 23 JSON inputs. File identity uses raw-byte
SHA-256; ordered bundles and derived values use deterministic Erlang terms and
`sha-256-canonical-etf-v1`.

| Evidence | Digest |
| --- | --- |
| Registration bundle | `b63beacc39ae35e76002acac4a2e7c0a53741db9af0d5928b16c7481cebb1839` |
| Canonical evidence | `764798a90f6ea465123b36a1aea386737b8250271656d7ac14814c11f9f86734` |
| Oracle bundle | `896117d38eb07b4da0044fd01c5f1eb39842bfb82909b8ec397f1bc8eb2abcd6` |
| Power audit | `3d2858f974b98293ccaffd7c2928858e1545d900f4af005f0f7c695ec68dee16` |
| Schedule cells | `72aca835d079fceab15c6ec87861f0b6afd52751a2cf4d49a7883ff77d440ac6` |
| Full schedule record | `32cdef4b898e9bdb04d2a9d3034d075ff30803c1761072b622cc777527fdb549` |
| Cross-contract validation | `27d21411889845c952ddd20428bc654210f35fea397606edad5691a8c852c79f` |

Two clean ERTS invocations reproduce the same file order, file hashes,
semantic-oracle bundle, simulation, schedule, validation record, registration
digest, and evidence digest.

## Contract and mutation coverage

The integration suite mechanically reconciles 48 selected and authored cases,
two replicates in each family/stratum cell, 2,304 primary cells, a 4,608 hard
request ceiling, two exact model manifests, two screening tokenizers, six
condition legends, four task protocols, all registered metrics, and `R3` as
the sole promotion candidate.

Positive validators and focused mutants cover:

- missing and duplicate schedule cells, changed seeds, adjacency, imbalance,
  and repetition pseudoreplication;
- copied development wording, leaked condition vocabulary, family mismatch,
  duplicate semantic digests, and child-scope widening;
- changed token and non-inferiority thresholds, pooled model gates,
  promotable controls, positional authority, unknown aliases, and unsafe
  derivations;
- model substitution, manifest drift, enabled network defaults, unbounded
  requests or replacements, protocol/condition mismatch, and scope expansion.

All trusted Phase 1 modules load from deterministic `.beam` files on ERTS.
The build uses Erlang source only and has no tokenizer process, provider SDK,
port, NIF, interpreter, or foreign executable in the validation path.

## Traceability and prior boundary

Six condition hypotheses, all fourteen metrics, and four rationale groups link
to the synthesis, active inquiry, language contract, implementation boundary,
and prior campaign. Included scope is limited to compiler-produced reversible
representations, fixed vocabulary, a nonpromotable opacity control, typed JSON
context, and deterministic single-turn scoring. Authored compact syntax,
learned macros, training, human usability, production readiness, unrelated
language features, and model effect execution remain excluded.

The independent Stream 02 asset registration still contains exactly 86 files
with digest
`dcf8187fa20eb440784901b25d453ba729abb134c865abf29b5b868da2afb3dd`.
Its complete assets, implementation, evidence, and planning boundary contains
182 files with digest
`3dc60f80fa2bc0730af9d4b42f145b0663704a8a75f1fece3a76638d73c56f78`.
A changed byte, missing file, added file, or substituted expected digest fails
Phase 1 validation.

## Reproduction

```bash
make test-compact-phase-1
make build-compact-phase-1-evidence
```

The first command executes all 29 Section 1.1–1.4 tests. The second writes the
inspectable generated record to
`build/compact-projection-fidelity/phase-01/evidence/pre-registration-evidence.json`.
The build tree is ignored; registered source inputs and this evidence summary
remain in the archive.

## Connections

- [Phase 1 plan](../../60-planning/03-compact-projection-fidelity/phase-01-campaign-contract-and-confirmatory-corpus.md)
- [Campaign overview](../../60-planning/03-compact-projection-fidelity/README.md)
- [Projection vocabulary](../../assets/compact-projection-fidelity/campaign/projection-vocabulary-v1.json)
- [Protocol registry](../../assets/compact-projection-fidelity/campaign/protocol-registry-v1.json)
- [Traceability registration](../../assets/compact-projection-fidelity/campaign/traceability-v1.json)
- [Evidence schema](../../assets/compact-projection-fidelity/contracts/preregistration-evidence-v1.schema.json)
