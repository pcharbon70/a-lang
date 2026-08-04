---
title: "Phase 8 Integration and Release Evidence"
kind: note
created: 2026-08-04
maturity: developing
tags:
  - beam
  - integration-testing
  - proof-of-concept
  - release-engineering
aliases: []
---

# Phase 8 Integration and Release Evidence

## Outcome

Phase 8 is accepted with a `revise` architecture decision. The offline demo,
controlled comparison, falsification review, decision record, complete
validation campaign, and archive gates pass on the one supported environment.
The Phase 8 implementation is complete, but the original eight-phase roadmap
is deliberately recorded as `revised_not_complete`: its claim that every
model, tool, storage, and workspace boundary is OS-bounded is not implemented.
The model fixture and durable store remain trusted BEAM processes, and there is
no general tool boundary.

This distinction prevents a successful release-candidate gate from becoming a
false production-readiness claim. Production status remains `not_approved`.

## Reproduce

```bash
make test-section-8-4
make test
```

The first command runs all eight phases needed by the final candidate, the
offline demonstration, Phase 7 law/security/fault/performance campaign, matched
comparison, decision validation, archive check, and final release aggregation.
The second command is the repository-wide gate. Expected supervisor and crash
reports are emitted by deliberate gateway, broker, corrupt-store, and recovery
tests; their enclosing test cases must still pass.

## Supported environment

| Item | Accepted value |
| --- | --- |
| Erlang/OTP | 29.0.4 |
| OTP release | 29 |
| ERTS | 17.0.4 |
| Architecture | `x86_64-pc-linux-gnu` |
| Operating system | Linux/Unix |
| Word size | 8 bytes |
| Online schedulers | 20 |
| Rebar3 | 3.27.0 |
| PropEr | 1.5.0 |

No other host or OTP environment is declared supported by this proof of
concept. A deviation must fail the pinned toolchain check rather than silently
regenerate golden artifacts.

## Release evidence

- The frozen demonstration evidence digest is
  `d1c693dba369ed6b39080b74fb18ad8f26d814cb88c563f8d5bd56a06f7bf21f`.
- The source, child, and workspace BEAM artifacts use deterministic, versioned
  ETF metadata attributes and retain pinned byte digests across clean ERTS
  processes.
- Compiled BEAM, semantic oracle, conventional typed runtime, and conventional
  typed IR observations agree for the frozen conditions.
- The local broker records two denials; the direct-handler ablation performs
  the two corresponding unauthorized writes.
- The validation campaign records 1,468 generated cases, 30 fixed attacks, 63
  fault cases, 17 detected seeded defects, 10 performance metrics, and 2
  comparison baselines: 1,578 validation cases in total.
- The architecture record narrows task-language and categorical claims,
  promotes BEAM, local broker, and explicit durability to one next prototype,
  and revises the combined architecture.
- The BEAM archive checker validates JSON syntax for the metadata schema,
  required frontmatter shapes, all local links, a README in every retained
  directory, and complete direct-child indexes. The repository handoff also
  runs full JSON-Schema validation with ISO dates preserved as strings.

## Evidence index

| Completion claim | Primary evidence | Executable gate |
| --- | --- | --- |
| Source compiles to inspected BEAM | [Reproducible demo](reproducible-demonstration-package.md) | `make test-section-8-1` |
| Trusted compiler and programs run on ERTS | [Phase 3 artifact contract](../phase-03/artifact-contract.md) | Phase 3 residency and Phase 8 release tests |
| Static IR and compiled observations agree | [Controlled comparison](controlled-baseline-and-ablation-comparison.md) | `alang_phase8_comparison_tests` |
| Local authority prevents scope and budget violations | [Phase 4 evidence](../phase-04/phase-04-integration-evidence.md) and [ablation](controlled-baseline-and-ablation-comparison.md) | Phase 4 suites and comparison tests |
| Recovery preserves one logical effect or explicit uncertainty | [Phase 5 evidence](../phase-05/phase-05-integration-evidence.md) | Phase 5 recovery plus 63-case Phase 7 matrix |
| Model and child work stay typed and bounded | [Phase 6 evidence](../phase-06/phase-06-integration-evidence.md) | Phase 6 negative and integration suites |
| Laws, attacks, faults, measurements, and mutants pass | [Phase 7 evidence](../phase-07/phase-07-integration-evidence.md) | `make test-phase-7` |
| Accepted and rejected research claims are explicit | [Falsification review](falsification-review.md) | `make decide` |
| Implementation, risks, and deferrals are reconciled | [Status and risk record](implementation-status-and-risk-record.md) and [deferred ledger](deferred-work-ledger.md) | Archive and release tests |
| Final outcome and next boundary are machine-readable | [Architecture decision](proof-of-concept-architecture-decision.md) | `alang_phase8_decision_tests` |

## Roadmap reconciliation

Ten of the eleven original roadmap completion items have reproducible evidence.
The remaining OS-boundary item stays unchecked in the
[planning-stream README](../../60-planning/01-minimal-proof-of-concept/README.md)
with its blocker. Closing Phase 8 with a revised roadmap is the accepted
decision; it is not a waiver of the unmet gate.

The next authorized prototype is limited to user-authored effectful source and
matched task-fidelity evidence. The [deferred-work ledger](deferred-work-ledger.md)
freezes unrelated expansion until that question is answered.
