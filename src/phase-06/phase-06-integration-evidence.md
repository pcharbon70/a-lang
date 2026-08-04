---
title: "Phase 6 Bounded Agent Integration Evidence"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - agent-runtime
  - beam
  - integration-testing
  - llm-agents
aliases: []
---

# Phase 6 Bounded Agent Integration Evidence

## Acceptance command

Run the complete Phase 6 gate from the repository root:

```bash
make test-section-6-5
```

The target first runs the provider protocol, task and context, repair and
verifier, and child attenuation suites. It then compiles and runs the Phase 6
integration fixture with the Phase 1–5 compiler, artifact, broker, adapter,
journal, and durable-state modules on the active OTP 29 toolchain. No live
provider or foreign compiler or interpreter is involved.

## Positive causal path

The deterministic scenario compiles three accepted A-Lang artifacts to BEAM:

1. The parent artifact calls the model boundary, receives malformed syntax,
   and executes exactly one schema-preserving repair call in the same
   supervised task process.
2. The parent starts a supervised child whose compiled artifact makes one
   model call through a fresh, model-only, nondelegable local grant.
3. A separately bound compiled workspace artifact publishes the child's
   Markdown through the same broker, the bounded workspace adapter, and the
   durable intent/result journal.
4. The artifact verifier binds path, content digest, byte and UTF-8 bounds,
   Markdown structure, nonempty `Findings`, and the journaled result into a
   completion witness. Only that witness moves the parent task to `complete`.

The parent model request, repair request, child request, generated artifacts,
broker decisions, durable journal, workspace receipt, and final witness share
their operation, task, session, request, artifact, or result digests. The
BEAM-resident orchestrator places and validates each task checkpoint before
the corresponding live model or workspace request and consumes its typed
result before another transition is admitted. The
published file is `reports/phase-6.md` inside the temporary acceptance
workspace and equals the verifier's expected bytes.

## Exact bounded counts

The deterministic fixture asserts these exact values:

| Measure | Count | Meaning |
| --- | ---: | --- |
| Parent task transitions | 9 | Context, two requests, two results, repair, draft, write, and witness |
| Model calls | 3 | Original parent, parent repair, and child |
| Repair attempts | 1 | The sole allowed diagnostic repair |
| Model input tokens | 134 | Deterministic byte-based mock estimate across all calls |
| Model output tokens | 42 | Deterministic byte-based mock estimate across accepted outputs |
| Broker-authorized effects | 4 | Three model effects and one workspace effect |
| Workspace mutations | 1 | One durable, digesting publication |

The task state itself owns a two-call parent model budget, one repair, one
workspace effect, and sixteen-step ceiling. The child owns a one-call local
budget that consumes the parent's shared model pool.

## Negative matrix

`alang_phase6_integration_tests` and the prerequisite Section 6 suites cover:

- malformed syntax followed by exhausted repair;
- retrieved prompt-injection text retained only as `data_only`;
- deadline exhaustion and explicit child cancellation;
- a widened child requirement rejected before spawn;
- wrong-session, wrong-presenter, and wrong-generation child presentations;
- attempted child-grant restriction and combination;
- an opaque grant rejected from model-visible context;
- a fenced but wrong-session child reply discarded;
- symlink, traversal, digest, journal, and required-section verifier failures.

Each case terminates, denies, or remains incomplete. None adds authority,
retries an uncertain consequential effect, publishes a second artifact, or
marks the parent task complete.

## Nonexposure gate

The integration test scans parent, repair, and child requests; context
snapshots; the public child handle; broker audit; adapter events; durable
journal; parent, child, and workspace traces; and the final witness. These
surfaces contain no VM reference and neither private fixture marker. Both
parent and child snapshots record the private fragment only by identifier and
`private_visibility` exclusion reason. Provider status confirms three fixture
calls with network disabled and no secrets.

This evidence completes the [Phase 6 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-06-bounded-llm-task-and-subagent-execution.md).
See the [provider boundary](model-boundary-contract.md),
[task orchestration](task-orchestration-and-context.md),
[repair and verification gate](repair-and-completion-verification.md), and
[child attenuation contract](mechanically-attenuated-child-task.md) for the
individual claims exercised here.
