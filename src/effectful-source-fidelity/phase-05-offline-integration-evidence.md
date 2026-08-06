---
title: "Phase 5 Offline Hosted-Evaluation Integration Evidence"
kind: note
created: 2026-08-06
maturity: developing
tags:
  - beam
  - hosted-model-evaluation
  - implementation-evidence
  - llm-evaluation
  - offline-testing
aliases: []
---

# Phase 5 Offline Hosted-Evaluation Integration Evidence

## Conclusion

Phase 5's offline implementation gate passes. Both fixed provider adapters run
through the scripted OTP HTTPS fixture seam, the complete 288-cell schedule
executes under deterministic successes and faults, all 408 attempts enter an
842-record hash-chained journal, and two clean ERTS processes emit identical
redacted evidence bytes. Replay independently regenerates every normalized
observation, score, aggregate, bootstrap interval, accounting total, and
offline validity result without credentials or network access.

This completes Task 5.4.1 only. No hosted model request was made, the fixture
prices and outputs are not empirical observations, and the offline result
cannot support a comparison between A-Lang and typed JSON. Task 5.4.2,
Section 5.4, and Phase 5 remain incomplete until an operator separately
authorizes the fixed hosted campaign and its retained evidence passes offline
replay.

## Complete offline campaign

The schedule remains fixed at 288 primary cells: 24 semantic cases, two
conditions, two model families, and three repetitions. A deterministic fault
program adds retries, repairs, and replacements without changing or skipping
a primary cell.

| Accounted item | Count |
| --- | ---: |
| Primary attempts | 288 |
| Pre-submission retries | 24 |
| Syntax-or-schema repairs | 72 |
| Uncertain submissions | 24 |
| Linked replacements | 24 |
| All attempts | 408 |
| Journal records | 842 |
| Scorable primary observations | 288 |
| Hosted calls | 0 |

The fixture accounting records 33,698 input tokens, 14,032 output tokens, and
61,762 micro-USD under deliberately synthetic rates. These values prove that
token and cost joins, ceilings, and replay work; they are not provider prices
or a statement of campaign cost.

Primary classifications include 168 schema-valid records, 48 malformed JSON
records, 24 schema-invalid records, 24 definitive refusals, and 24 truncated
records. Forty-eight malformed responses have exact secondary repairs; 24
schema failures retain a separate `repair_failure`. A successful repair never
changes the primary zero-fidelity score.

## Adapter and fault boundary

Both adapters render their production request bodies, authentication header
shapes, exact model identities, and fixed endpoints before handing the request
to a local scripted transport. The suite covers:

- TLS or certificate rejection and redirect rejection;
- timeout before submission and uncertain timeout after possible submission;
- wrong model identity for both providers;
- malformed, oversized, and partial-usage responses;
- rate limiting, projected-price failure, call exhaustion, and cost
  exhaustion;
- fixture crashes and secret-bearing error terms.

The OTP transport now catches a crashing scripted or sidecar boundary and
returns the closed `sidecar_crash`/`uncertain` result without retaining the
exception or credential. The same result algebra controls retry eligibility,
so an uncertain submission cannot be retried as if it were proved absent.

## Replay, mutation, and redaction gates

Every prefix of the 842-record journal is copied through deterministic ETF,
validated from its hash-chain root, and replayed to the next legal runner
state. This exercises interruption after every start, intent, result,
replacement-link, and close transition rather than sampling a few recovery
points.

Seeded mutations attempt to promote a repaired result into the primary score,
erase omissions, swap a condition, undercount cost, change the bootstrap seed,
and delete a journal record. Independent recomputation or hash-chain replay
detects each defect even after the mutant recomputes its outer digest.

The retained bundle contains the frozen source and control bytes, answer keys,
common prompt and result schema, schedule, normalized observations, scores,
aggregate tables, 10,000-resample intervals, journal, bounded accounting,
validity record, provenance, and implementation BEAM digests. Its writer
rejects credentials, authorization or raw-envelope fields, hidden reasoning,
unrelated provider identifiers, and caller-supplied secret substrings. Safe
ETF decoding and content-digest checks precede offline recomputation.

## Reproducibility identities

| Evidence | SHA-256 |
| --- | --- |
| Frozen schedule | `bb4b1544a038acd1c845d6575f326b890064f414678dd3a0ce1e175e0bdc07f7` |
| Deterministic offline campaign | `c61183f45bfcb059f8248b0136257423508dba82adcae34c6b7711c132e96df8` |
| Redacted evidence body | `8c0e9a8af8f1f23bc3ca17e5ed618d5b6073a58f42feff83f733a998c866061c` |
| Each generated ETF artifact | `cfbfe6f4f5060d989822fc03e40cabe1b31db7f910127bd6c0df10e6357c4ec9` |

The two clean-process files compare byte-for-byte equal. They remain under the
ignored `build/effectful-source-fidelity/phase-05/evidence/` directory rather
than entering version control.

The synthetic design yields 50% exact primary fidelity in every
model-family/condition cell and a zero observed paired difference. Its
non-degenerate intervals merely exercise the registered sampling algorithm;
they are intentionally incapable of establishing efficacy.

## BEAM residency and default-offline gate

Adapter, transport, scheduler, journal, observation, scorer, bootstrap,
evidence, mutation, worker, and integration modules load from `.beam` files.
The offline worker imports neither `erlang:open_port/2` nor `os:cmd/1`, invokes
no provider adapter, reads no credential, and makes no HTTP request. OTP
release 29 produced the recorded evidence.

The hosted path remains behind exact-profile probing, explicit live opt-in,
both adapter-owned credentials, a price-provenanced projection, a matching
confirmation digest, the 576-call ceiling, and the USD 200 ceiling. The
default build and all tests exercise only local fixtures and replay.

## Remaining hosted gate

The following evidence does not yet exist:

- actual availability probes for both exact registered model identifiers;
- explicit operator approval of the displayed request and price projection;
- a fully accounted hosted journal and its primary/repair/replacement records;
- a repository-safe hosted evidence bundle that reproduces offline; or
- a valid-or-invalid hosted campaign determination suitable for Phase 6.

Absent that evidence, this document must not be used to mark Section 5.4 or
Phase 5 complete, or to make an efficacy, production-readiness, or provider-
behavior claim.

## Reproduction

From the repository root, run:

```bash
make test-fidelity-section-5-4
```

The target reruns every inherited gate, compiles the Phase 5 modules, executes
the adapter fault matrix and 288-cell offline campaign, generates evidence in
two clean ERTS processes, compares their artifacts, tests every journal
prefix, detects all seeded mutants, and replays the retained evidence without
network access.

## Connections

- [Phase 5 implementation plan](../../60-planning/02-effectful-source-fidelity/phase-05-hosted-multi-model-fidelity-evaluation.md)
- [Effectful source fidelity roadmap](../../60-planning/02-effectful-source-fidelity/README.md)
- [Phase 4 source-to-BEAM evidence](phase-04-integration-evidence.md)
- [Implementation index](README.md)
