---
title: "Phase 6 Fidelity Decision and Handoff Evidence"
kind: note
created: 2026-08-06
maturity: developing
tags:
  - architecture-decision
  - beam
  - implementation-evidence
  - llm-evaluation
  - offline-testing
aliases: []
---

# Phase 6 Fidelity Decision and Handoff Evidence

## Conclusion

Phase 6 closes the effectful-source-fidelity stream through its
pre-registered invalid-campaign branch. Two clean ERTS processes independently
rebuild the schedule-expanded freeze, canonical decision, and human report
from committed redacted inputs and emit byte-identical replay bundles. The
machine outcome is
`stop-invalid-campaign-no-efficacy-conclusion`.

This is a conservative disposition, not a comparative result. No hosted
authorization was granted, no hosted request was made, and the retained
evidence contains no OpenAI, Anthropic, pooled, task-family, component,
safety-difference, effect-size, interval, or sensitivity result.

## Campaign validity and accounting

The committed no-run closure is expanded against the immutable 288-cell
schedule. Every cell is represented explicitly as missing with cause
`live-authorization-not-granted`; none is silently excluded, replaced, or
treated as a zero-fidelity provider response.

| Accounted item | Value |
| --- | ---: |
| Scheduled primary cells | 288 |
| Observed primary cells | 0 |
| Missing primary cells | 288 |
| Attempts | 0 |
| Hosted calls | 0 |
| Repairs | 0 |
| Replacements | 0 |
| Input tokens | 0 |
| Output tokens | 0 |
| Cost | 0 micro-USD |
| Call ceiling | 576 |
| Cost ceiling | 200,000,000 micro-USD |

The mechanical validity gate fails exactly these frozen predicates:

- `live_authorization`;
- `reproducible_scores`; and
- `three_scorable_primary_observations_per_cell`.

The freeze therefore sets primary and secondary analysis tables and bootstrap
intervals to `null`, marks analysis as `suppressed-invalid-campaign`, and
forbids an efficacy conclusion.

## Ordered decision coverage

The decision module validates and applies the ordered rule independently to
the two model-family inputs when a campaign is valid. Deterministic fixtures
cover promotion, the exact five-percentage-point margin, the strict positive
interval boundary, JSON replacement, family disagreement, ordinary stop, and
the safety veto. Inputs that pool families or attach metrics to an invalid
campaign fail closed.

For the retained campaign, validity fails before any efficacy predicate can be
evaluated. The canonical report explains every ordered predicate, records the
inherited implementation gates separately, sets sensitivity analysis to
`not-run`, and cannot use sensitivity to change the disposition.

## Mutation and negative gates

The Phase 6 suite rejects fifteen mutations even when the mutant recomputes
its outer bundle or record digest: freeze-digest corruption, deletion of a
missing cell, a changed request digest, model aliasing, cost-ceiling violation,
decision-digest corruption, a changed decision basis, promotion of an invalid
campaign, efficacy smuggling, removal of the invalid-campaign safety veto,
predicate flipping, a sensitivity override, an artifact-digest change, an OTP
identity change, and incomplete module-residency evidence.

It also reruns the inherited Phase 5 semantic mutants for promoting a repair
to primary evidence, ignoring an omission, swapping a condition,
undercounting cost, changing the bootstrap seed, and deleting a journal
record. Corrupt safe-ETF input and an unregistered model alias are rejected.

## Reproducibility identities

| Evidence | SHA-256 |
| --- | --- |
| Frozen schedule content | `bb4b1544a038acd1c845d6575f326b890064f414678dd3a0ce1e175e0bdc07f7` |
| Campaign freeze content | `c08454cf2887639d5012633472c36445cdc7467711686d865835d1a99f9a16a0` |
| Canonical decision content | `185756c9b9dcec2c63a5d03f14085fa39e957e6d242869eee778db81014bbb06` |
| Generated freeze JSON artifact | `c9d011f175a883567e0af67ef62bc9015d627590492d8c4d8b7c65a68e69f3dc` |
| Generated decision JSON artifact | `7a31dba4177b5bb09a2bb741350a02eac7dc754cd97935c481b7d5b65a2f9f75` |
| Generated human report artifact | `5bd32fd2e9bf98e56a5f1adcc05b306585158d9f85688a837b82762791cfb0eb` |
| Replay bundle content | `a89f9d1ad7453716fa45368fa9b7037de57e3b8443aea985ca7b4764d3be503b` |
| Each generated replay ETF artifact | `018660aef1be6ea0e70833728024e2c08a939d9d100f94db6b28812e383f9fe5` |

The two replay artifacts compare byte-for-byte equal. Generated JSON,
Markdown, and ETF evidence stays below the ignored
`build/effectful-source-fidelity/phase-06/evidence/` directory; the committed
closure remains the sole retained campaign input.

## BEAM, archive, and security gates

Freeze, decision, report, mutation, and replay modules load from `.beam` files
under OTP 29. The replay path imports neither `erlang:open_port/2` nor
`os:cmd/1`, runs with networking disabled, invokes no provider adapter, and
records zero hosted calls. The default repository test target includes the
complete Phase 6 gate and remains offline.

The final gate also validates archive metadata, local links, directory README
inventories, the decision handoff, safe ETF decoding, owned evidence paths,
and absence of credentials, authorization headers, raw HTTP envelopes, hidden
reasoning, and provider request or response identifiers from retained
artifacts.

## Limitations and later authorization

The completed implementation proves deterministic closure, validation,
decision, and handoff mechanics. It does not prove that either representation
improves agent comprehension, that either registered provider behaves as the
offline fixtures do, or that the prototype is production-ready or easier for
humans to use.

Any hosted comparison is a new experiment requiring explicit authorization,
a new numbered planning stream, refreshed model and price verification, and a
new pre-registration. This stream authorizes no live retry or additional
language surface.

## Reproduction

From the repository root, run:

```bash
make test-fidelity-section-6-4
```

The target reruns every inherited effectful-source-fidelity gate, rebuilds the
freeze and decision, performs two clean offline ERTS replays, compares their
bytes, executes decision and mutation tests, and validates the archive
handoff.

## Connections

- [Phase 6 implementation plan](../../60-planning/02-effectful-source-fidelity/phase-06-fidelity-decision-and-roadmap-handoff.md)
- [Effectful source fidelity roadmap](../../60-planning/02-effectful-source-fidelity/README.md)
- [Architecture decision](effectful-source-fidelity-architecture-decision.md)
- [Phase 5 offline evidence](phase-05-offline-integration-evidence.md)
- [Implementation index](README.md)
