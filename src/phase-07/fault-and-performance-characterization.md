---
title: "Phase 7 Fault and Performance Characterization"
kind: note
created: 2026-08-04
maturity: developing
tags:
  - beam
  - fault-injection
  - performance-testing
  - runtime-validation
aliases: []
---

# Phase 7 Fault and Performance Characterization

## Fault campaign

The coverage manifest crosses seven runtime components with all nine durable
effect transitions, producing 63 explicit cases. Every injected BEAM-process
failure must terminate observably, and every post-recovery record must satisfy
the Phase 5 invariants for single logical effect, artifact identity, journal
integrity, checkpoint integrity, no unresolved intent, evidence-backed
completion, consumed budget, and stale-message rejection.

The manifest is paired with component-specific executable suites rather than
treated as evidence by enumeration alone. The Section 7.4 target reruns the
Phase 3 gateway failure cases, Phase 4 broker restart and workspace port fault
cases, Phase 5 process/node/storage/effect recovery matrix, and Phase 6 model
and child cancellation/fencing cases before accepting the 63-case coverage
record.

Submissions interrupted after dispatch are classified `explicit_uncertain`;
crashes after mutation require reconciliation; other covered boundaries must
recover or deny. No case authorizes blind retry of an ambiguous consequential
effect.

## Performance characterization

The BEAM harness records microsecond samples with minimum, mean, p50, p95,
p99, maximum, total sampled time, and derived sequential throughput for ten
operations: compile, inspect/load/purge, task start,
message round trip, grant resolution, broker decision, journal transition,
workspace adapter execution, journal recovery, and completion verification.
Two conventional typed-control baselines measure an in-memory state transition
and effect-contract validation. The workspace adapter measurement is shared by
both sides of the comparison, keeping external I/O out of the attributed
control-plane difference rather than inventing a dissimilar mock baseline.

Pressure scenarios run 1, 8, and 32 concurrent supervised sessions; retain 1,
64, and 256 local grants; and exercise effect payloads at 64, 4,096, 32,768,
65,536, and 65,537 bytes. A VM snapshot records memory categories, run queue,
and the harness mailbox before and after pressure so inherited messages are
not misreported as benchmark leakage. Existing component suites supply the slow-consumer,
mailbox admission, pending-request, port-timeout, and storage-deadline gates.

These measurements characterize one host and one run. They are not service
level objectives, cross-host comparisons, or statistically independent
claims. The environment record preserves OTP, ERTS, scheduler, processor, and
word-size facts so Phase 8 can decide whether broader measurement is needed.

## Reproduce

```bash
make test-section-7-4
```

See the [Phase 7 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-07-law-security-fault-and-performance-validation.md),
[Phase 5 recovery evidence](../phase-05/phase-05-integration-evidence.md), and
[Phase 6 bounded-agent evidence](../phase-06/phase-06-integration-evidence.md).
