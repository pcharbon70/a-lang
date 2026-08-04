---
title: "Phase 7 Integration Evidence"
kind: note
created: 2026-08-04
maturity: developing
tags:
  - beam
  - integration-testing
  - performance-testing
  - runtime-validation
aliases: []
---

# Phase 7 Integration Evidence

## Acceptance outcome

Phase 7 passes its aggregate campaign and the complete repository gate. The
campaign executed 1,468 generated cases, 30 fixed attacks, 63 fault cases, and
17 seeded defects: 1,578 validation cases in total. It also recorded 10
control-plane measurements and 2 comparison baselines. All 17 mutants were
detected by their named observations, and the serialized evidence contained no
BEAM process identifiers, references, or ports.

The acceptance commands were:

```bash
make test-section-7-5
make test
```

Both commands passed on 2026-08-04. Expected supervisor and crash reports in
the output come from explicit gateway, broker, and corrupt-store failure tests;
their enclosing EUnit cases passed.

## Toolchain and environment

| Item | Captured value |
| --- | --- |
| OTP | 29.0.4 |
| ERTS | 17.0.4 |
| Architecture | `x86_64-pc-linux-gnu` |
| Rebar3 | 3.27.0 |
| PropEr | 1.5.0 |
| Online schedulers | 20 |
| Logical processors | 20 |
| Word size | 8 bytes |
| Time-warp mode | `multi_time_warp` |

The compiler modules, generated programs, property harness, mutation harness,
fault probes, and benchmark driver all ran as BEAM modules on ERTS. PropEr is a
test-only dependency and is excluded from the deployable compiler path.

## Coverage record

| Evidence class | Count | Result |
| --- | ---: | --- |
| Typed source, law, shrink, and BEAM differential cases | 348 | Pass |
| Authority, lifecycle, effect-history, and journal cases | 480 | Pass |
| Generated binary and typed-term attacks | 640 | Pass |
| Fixed size, atom, grant, path, adapter, context, and leak attacks | 30 | Pass |
| Component-by-transition fault cases | 63 | Pass |
| Seeded semantic/backend defects | 8 | Detected |
| Seeded authorization/recovery defects | 9 | Detected |

The fault record crosses seven runtime components with nine durable-effect
transitions. It combines monitored process/generation probes and validated
journal evidence with the real Phase 3 gateway, Phase 4 broker and workspace
adapter, Phase 5 process/node/storage recovery, and Phase 6 cancellation and
reply-fencing suites.

## Captured performance characterization

The table is one local campaign capture in microseconds. Throughput is derived
from sequential sampled time and must not be read as service capacity.

| Operation | Samples | Mean | p50 | p95 | p99 | Max | Ops/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Compile | 12 | 10,542 | 10,450 | 10,851 | 10,851 | 10,851 | 94 |
| Inspect/load/purge | 30 | 1,566 | 1,463 | 2,167 | 2,254 | 2,254 | 638 |
| Task start/complete | 30 | 1,839 | 1,813 | 2,669 | 2,685 | 2,685 | 543 |
| Message round trip | 300 | 1 | 1 | 3 | 5 | 21 | 733,496 |
| Grant resolution | 300 | 0 | 0 | 1 | 4 | 23 | 4,347,826 |
| Broker decision | 100 | 9 | 8 | 15 | 22 | 25 | 109,529 |
| Journal transition | 300 | 6 | 6 | 12 | 17 | 19 | 150,375 |
| Workspace adapter | 30 | 21,022 | 23,039 | 25,546 | 25,723 | 25,723 | 47 |
| Journal recovery | 60 | 365 | 315 | 652 | 922 | 922 | 2,735 |
| Completion verifier | 100 | 102 | 100 | 123 | 132 | 139 | 9,783 |

The typed in-memory control-transition baseline was below the timer resolution
for all 300 samples. Typed effect validation had p95 1 microsecond, p99 3
microseconds, maximum 8 microseconds, and derived throughput of 7,894,736
operations per second. The workspace adapter measurement is shared external
I/O; it is not replaced with a faster mock for the comparison.

## Pressure and bounds

- 1, 8, and 32 concurrent compiled sessions all completed in 198, 351, and
  605 microseconds respectively in the captured run.
- Grant-store snapshots for 1, 64, and 256 grants encoded to 848, 44,562, and
  177,967 bytes.
- Workspace payloads of 64, 4,096, 32,768, and 65,536 bytes were accepted;
  65,537 bytes was rejected.
- The post-pressure VM snapshot recorded a zero run queue and 65,739,544 bytes
  of total VM memory. The harness inherited 11 mailbox messages from earlier
  campaign sections and added zero messages during its measurement.
- Executable component suites covered gateway in-flight admission, broker
  pending admission, store mailbox backpressure, workspace port timeout, and
  recovery deadlines.

## Replay and open risk

Generated IR cases carry replayable case seeds and PropEr preserves a shrunk
counterexample on failure. PropEr 1.5.0 does not expose the campaign's passing
engine seed as a supported quickcheck option, so a passing random stream is not
bit-for-bit replayable; this limitation is recorded by the aggregate evidence.

The results are generated-test evidence, not mathematical proof. The local
mutants establish sensitivity only to the 17 selected faults and do not define
a global mutation score. Performance is a single-host characterization with
timer-resolution artifacts, not a service-level objective or a cross-host
comparison. Live-provider behavior, multi-node scheduling, formal categorical
proof, broad workload performance, and production hardening remain for the
Phase 8 decision and any follow-on roadmap.

## Connections

See the [Phase 7 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-07-law-security-fault-and-performance-validation.md),
[typed law evidence](typed-generators-and-law-observations.md),
[authorization properties](authorization-and-state-properties.md),
[adversarial boundary inventory](adversarial-boundary-testing.md),
[fault and performance characterization](fault-and-performance-characterization.md),
and [seeded-defect sensitivity](seeded-defect-sensitivity.md).
