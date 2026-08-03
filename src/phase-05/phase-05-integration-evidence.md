---
title: "Phase 5 Crash-Recovery Integration Evidence"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - beam
  - durable-execution
  - fault-injection
  - integration-testing
aliases: []
---

# Phase 5 Crash-Recovery Integration Evidence

## Evidence claim

The Phase 5 suite executes a compiled A-Lang workspace effect through the
BEAM runtime, durable workflow coordinator, capability broker, and isolated
workspace sidecar. Across the tested commit boundaries, killing the workflow
or its complete ERTS node cannot produce more than one logical workspace
operation, restore spent authority, accept a stale runtime generation, or
publish completion without the terminal checkpoint and evidence record.

This is executable proof-of-concept evidence for the declared local
filesystem and single-node model. It is not a claim of transactional delivery
across arbitrary external services or a proof against physical media failure.

## Reproduce

From the repository root, run:

```bash
make test-section-5-5
```

The target compiles the trusted toolchain and runtime as `.beam` modules,
runs the preceding Phase 5 state, journal, storage, resume, authority, and
effect-reconciliation suites, then executes
[`alang_phase5_integration_tests`](alang_phase5_integration_tests.erl).
Generated modules, stores, workspaces, and node configuration remain under the
ignored `build/` directory.

## Executed workflow

The integration fixture lowers typed A-Lang IR through the Phase 3 Abstract
Format backend and inspects the resulting `.beam` artifact before execution.
The generated module requests one `workspace.write` operation. The Phase 5
workflow then records and checkpoints the effect intent, authorization and
reduced budget, adapter submission, result, logical-state advance, and
terminal state before appending completion evidence.

The successful path checks all of the following together:

- the generated `.beam` result contains the expected content digest;
- exactly one stable operation receipt and one target artifact exist;
- the journal hash chain and final checkpoint validate after reopening;
- the pending intent is cleared and the workspace budget remains spent;
- the completion record is last and a subsequent resume returns `completed`;
- a stale generation envelope is rejected before it can advance the session.

## Failure matrix

The workflow exposes hooks only at named semantic boundaries. The test kills
the workflow process at each boundary, reopens the store, validates the
journal, recovers without dispatching an effect, and compares the observable
state with the expected cut:

| Failure hook | Durable cut at kill | Expected workspace receipts | Valid terminal state |
| --- | --- | ---: | --- |
| `before_intent` | Initial checkpoint | 0 | `running` |
| `after_intent_commit` | Intent record and checkpoint | 0 | `running` |
| `after_authorization` | Reduced authority and authorization checkpoint | 0 | `running` |
| `after_submission` | Adapter identity and submission checkpoint | 0 | `running` |
| `after_mutation` | Sidecar mutation and durable receipt, result not journaled | 1 | `running` |
| `after_result_commit` | Durable result record, state advance not checkpointed | 1 | `running` |
| `after_checkpoint` | Result acknowledged and pending intent cleared | 1 | `running` |
| `before_terminal` | Completed effect, terminal transition not begun | 1 | `running` |
| `after_terminal` | Terminal checkpoint and completion record | 1 | `completed` |

Every row requires a valid journal and forbids completion except the final
row, where the checkpoint and completion evidence are already durable.

## Fresh-node and boundary failures

The node fixture starts a separate ERTS OS process with only the compiled BEAM
paths and a bounded, safe-decoded configuration. It stops at
`after_mutation`, after the workspace sidecar has synced its receipt and target
but before the workflow has journaled the result. The parent sends `SIGKILL`
to that ERTS process, observes its exit, starts a new supervised session tree,
and verifies that reconciliation finds the receipt, appends the missing result
record, and does not issue a second write.

Starting from a genuinely fresh VM also verifies that checkpoint decoding does
not depend on atoms previously interned by the test runner. Durable A-Lang
values admit only the compiler-owned data-tag vocabulary; the store preloads
the closed state and journal protocols before safe external-term decoding.

The aggregate Phase 5 target additionally exercises a sidecar crash after
mutation, malformed and divergent receipts, missing adapter results, durable
pause on irreconcilable outcomes, one-shot store unavailability and timeout,
read recovery, duplicate acknowledgements, deadlines, limits, and mailbox
backpressure. Failure sequences can be reduced to a deletion-minimal event
history with [`alang_phase5_failure_matrix`](alang_phase5_failure_matrix.erl);
the seeded duplicate-write violation reduces to that single causal event.

## Limits and falsification

This evidence would fail if any matrix row produced two operation receipts,
an invalid journal or checkpoint, a widened budget, an accepted stale
generation, or an unsupported terminal state. The final invariant check also
fails on an artifact digest mismatch or unresolved intent.

The PoC assumes one local node at a time, an atomic same-filesystem rename,
successful file and directory synchronization, and the fixed workspace
adapter protocol. It does not cover multi-node consensus, network partitions,
hardware write-cache loss, or non-idempotent third-party effects. Those cases
require stronger storage and operation-specific protocols rather than broader
claims from this suite.

See the [Phase 5 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-05-durable-beam-sessions-and-recovery.md)
and [Phase 5 implementation index](README.md).
