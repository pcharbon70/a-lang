---
title: "Phase 8 Demonstration and Decision"
kind: map
created: 2026-08-04
tags:
  - beam
  - directory-index
  - proof-of-concept
  - release-engineering
aliases: []
---

# Phase 8 Demonstration and Decision (`src/phase-08`)

## Purpose

This directory packages the final offline A-Lang proof-of-concept scenario,
matched baseline comparisons, architecture decisions, and release-candidate
acceptance evidence. It consumes the BEAM-resident compiler and runtime proven
in earlier phases; it does not introduce an alternate interpreter.

## What belongs here

- Frozen demonstration inputs and expected observations.
- The one-command BEAM-native demonstration and bundle inspector.
- Controlled baselines and ablations that keep task semantics fixed.
- Decision, feature, risk, and deferred-work records.
- Final release-candidate checks and evidence indexes.

Generated bundles belong under ignored `build/phase-08/` paths.

## Index

### Subdirectories

- [Demonstration fixtures](fixtures/README.md) — frozen A-Lang source, model,
  grant, manifest, trace, output, and digest expectations.

### Files

- [`alang_phase8_demo.erl`](alang_phase8_demo.erl) — the offline source,
  compiled child, broker, durable workspace, verifier, and evidence-bundle
  runner.
- [`alang_phase8_inspect.erl`](alang_phase8_inspect.erl) — independent digest,
  redaction, artifact, and explanation checks for a generated bundle.
- [`alang_phase8_demo_tests.erl`](alang_phase8_demo_tests.erl) — deterministic
  rerun, expected-output, tamper, and inspection acceptance tests.
- [`alang_phase8_comparison.erl`](alang_phase8_comparison.erl) — semantically
  matched execution, authority, recovery, performance, and structural-cost
  comparison runner.
- [`alang_phase8_comparison_tests.erl`](alang_phase8_comparison_tests.erl) —
  executable agreement, denial, recovery-evidence, and reporting gates.
- [`alang_phase8_decision.erl`](alang_phase8_decision.erl) — the validated,
  machine-readable layer dispositions and next decision boundary.
- [`alang_phase8_decision_tests.erl`](alang_phase8_decision_tests.erl) —
  evidence-path, outcome, scope-freeze, and owned-output decision gates.
- [`alang_phase8_release.erl`](alang_phase8_release.erl) — supported-toolchain,
  compiler-residency, demo, comparison, validation, decision, and archive gate
  aggregation for the final release candidate.
- [`alang_phase8_release_tests.erl`](alang_phase8_release_tests.erl) — exact
  environment, campaign, roadmap-status, leak, documentation, and evidence
  acceptance tests.
- [Reproducible demonstration package](reproducible-demonstration-package.md)
  — usage, contents, trust boundaries, reproducibility, and failure behavior.
- [Controlled baseline and ablation comparison](controlled-baseline-and-ablation-comparison.md)
  — conditions, controls, observations, cost boundaries, and limits.
- [Falsification review](falsification-review.md) — positive, rejection, and
  narrowing criteria applied independently to each research hypothesis.
- [Proof-of-concept architecture decision](proof-of-concept-architecture-decision.md)
  — accepted and rejected claims, layer dispositions, and the single next
  prototype boundary.
- [Implementation status and risk record](implementation-status-and-risk-record.md)
  — supported contracts, commands, feature dispositions, security assumptions,
  and operational risks.
- [Deferred-work ledger](deferred-work-ledger.md) — explicitly unimplemented
  language, runtime, authority, model, durability, operational, and research
  work with reconsideration triggers.
- [Phase 8 integration and release evidence](phase-08-integration-evidence.md)
  — exact environment, reproduction commands, aggregate results, evidence
  index, and the deliberately unmet roadmap gate.

## Maintaining this index

Index every direct file and subdirectory. Keep frozen fixture digests aligned
with the pinned OTP toolchain and update them only with an explained semantic
or compiler change.
