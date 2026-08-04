---
title: "Phase 7 Authorization and Runtime State Properties"
kind: note
created: 2026-08-04
maturity: developing
tags:
  - capability-security
  - property-based-testing
  - state-machine-testing
  - runtime-validation
aliases: []
---

# Phase 7 Authorization and Runtime State Properties

## Finite authority model

The test oracle expands each local grant over a finite, declared universe of
workspace paths and model identifiers. Restriction is observed as set
intersection. Child and grandchild observations must be subsets of their
parents, while the real Phase 4 store independently enforces structural
prefix, budget, deadline, owner, session, generation, revocation, and restart
rules.

The model is deliberately finite. Agreement demonstrates the implementation's
behavior over the generated universe; it is not a proof for every possible
resource identifier.

## Generated histories

Grant histories mix resolve, consumption, wrong-session presentation, expiry,
revocation, and runtime-generation replacement. At every step, the oracle's
status and shared budget must agree with the real opaque-reference store.

Effect histories model intent, authorization, submission, result, crash,
recovery, cancellation, expiry, and restart. Invariants reject budget
underflow, effects without durable intent or authorization, duplicate
submission, and automatic retry after an uncertain submission. Settlement
must reach observed, denied, cancelled, or explicit-uncertain state in one
additional step.

Journal histories append generated digest-only observations through the real
Phase 5 journal. The complete chain must validate, while a changed record
digest must be rejected at the first inconsistent sequence.

## Reproduce

```bash
make test-section-7-2
```

This property layer builds on the
[Phase 4 local grant implementation](../phase-04/alang_phase4_grants.erl),
[Phase 5 journal](../phase-05/alang_phase5_journal.erl), and the
[Phase 7 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-07-law-security-fault-and-performance-validation.md).
