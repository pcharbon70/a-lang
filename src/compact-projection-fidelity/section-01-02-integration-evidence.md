---
title: "Compact Projection Phase 1 Section 1.2 Integration Evidence"
kind: note
created: 2026-08-12
maturity: developing
tags:
  - evaluation
  - implementation-evidence
  - statistical-power
  - token-efficiency
aliases: []
---

# Compact Projection Phase 1 Section 1.2 Integration Evidence

## Conclusion

Section 1.2 is complete. The frozen paired-case simulation finds the original
24-case minimum underpowered for the central zero-loss/10%-discordance
scenario and selects the next balanced block: 48 independent semantic cases.
The confirmatory design therefore uses 16 cases per runtime family, two cases
in each family/stratum cell, and treats repetitions as nested observations.

The fixed schedule contains 2,304 primary cells: 1,152 six-condition
comprehension cells and 1,152 readable-versus-compact generation, diagnostic-
repair, and action/completion cells. Two model families and two repetitions
are balanced throughout. Exactly one transport-linked replacement per cell
sets the hard request ceiling at 4,608; definitive responses remain
nonretriable.

## Power boundary

The BEAM simulation freezes optimistic (4% discordance), central (10%), and
adverse (20%) paired scenarios, a −5-point non-inferiority margin, 95% one-
sided cluster-normal bound, 2,000 simulated campaigns per scenario/sample
size, and an 80% central power requirement. Candidate sizes are limited to
24, 48, and 72 so expansion occurs only in complete balanced blocks.

This is a design audit, not an efficacy result. Phase 4 must still exercise the
registered 20,000-resample case-stratified percentile analysis before any real
call.

| Scenario | 24 cases | 48 cases | 72 cases |
| --- | ---: | ---: | ---: |
| Optimistic | 95.20% | 99.90% | 100.00% |
| Central | 70.65% | 92.60% | 97.95% |
| Adverse | 47.30% | 71.65% | 85.55% |

The selection rule uses only the preregistered central scenario. The adverse
row remains visible as a limitation; it cannot expand the campaign after the
central rule has selected 48 cases.

## Schedule and leakage evidence

The scheduler uses seed `2026081103`, assigns opaque 12-byte trial identities,
materializes every unique case × model × protocol × eligible condition ×
repetition cell, and deterministically separates adjacent uses of one semantic
case. Validation detects wrong counts, duplicate identities, factor imbalance,
seed drift, digest drift, and an eligibility mismatch.

No case content, model output, provider adapter, network call, or credential is
used. The 48 identities and strata are fixed before Section 1.3 authors their
semantic contents.

## Reproduction

```bash
make test-compact-section-1-2
```

The command reruns Section 1.1, the deterministic power audit, sample-size
selection, schedule materialization, opacity, adjacency, balance, and mutation
tests on ERTS.

## Connections

- [Phase 1 plan](../../60-planning/03-compact-projection-fidelity/phase-01-campaign-contract-and-confirmatory-corpus.md)
- [Power design](../../assets/compact-projection-fidelity/campaign/power-design-v1.json)
- [Case design](../../assets/compact-projection-fidelity/campaign/case-design-v1.json)
- [Schedule policy](../../assets/compact-projection-fidelity/campaign/schedule-policy-v1.json)
