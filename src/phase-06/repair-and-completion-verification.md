---
title: "Phase 6 Structured Repair and Completion Verification"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - agent-runtime
  - beam
  - completion-witnesses
  - structured-repair
aliases: []
---

# Phase 6 Structured Repair and Completion Verification

## Diagnostic repair boundary

`alang_repair_state_v1` retains the original request, request digest, and
context digest. Only a definitive syntax or schema failure before a
consequential effect may enter repair. Cancellation, failed authorization,
policy denial, transport timeout, provider failure, budget exhaustion,
uncertain outcome, and any failure after a consequential effect terminate
without blind retry.

A repair request preserves the original profile, output schema, deadline, and
goal provenance while replacing model-visible context with only the smallest
reported failing fragment and its stable diagnostic. Its fresh call identity
is derived from the original request digest and attempt number. Each history
entry binds original and repair call identities, request and context digests,
diagnostic and fragment digests, attempt number, and the accepted or rejected
response fragment. The task machine consumes a runtime-owned repair counter
before a new checkpointed model call can occur.

## Independent completion gate

`alang_completion_witness_v1` is computed from the workspace, the declared
completion specification, and a typed journal result—not from a model claim.
The verifier requires a safe expected relative path, a regular non-symlink
file, the expected SHA-256 digest, the byte bound, valid UTF-8, a Markdown H1,
a nonempty named H2 section, and a successful journal record bound to the same
relative path and artifact digest.

Every predicate records pass or fail plus a digest-bearing specification,
artifact, or journal reference. Any failure remains listed as unresolved
uncertainty and makes the witness `incomplete`; only the conjunction of all
predicates produces `complete`. The witness itself has a deterministic digest
that later durable task completion can cite.

See the [model boundary](model-boundary-contract.md),
[task orchestration contract](task-orchestration-and-context.md),
[Phase 6 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-06-bounded-llm-task-and-subagent-execution.md),
and [Phase 6 implementation index](README.md).
