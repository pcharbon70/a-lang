---
title: "Phase 6 Bounded LLM Task and Subagent Execution"
kind: map
created: 2026-08-03
tags:
  - agent-runtime
  - directory-index
  - llm-agents
  - multi-agent-systems
aliases:
  - "Phase 6 implementation index"
---

# Phase 6 Bounded LLM Task and Subagent Execution (`src/phase-06`)

## Purpose

This directory implements the model, orchestration, repair, verification, and
child-task boundaries for the minimal A-Lang agent workflow. Deterministic
control and authority remain in supervised BEAM modules; model output crosses
only a closed typed protocol and cannot choose runtime functions, credentials,
capability references, or completion state.

## What belongs here

- The provider-neutral bounded model request and result algebra.
- The deterministic offline provider and optional live-provider feature gate.
- Runtime-owned task transitions, context slicing, repair, and verification.
- Supervised child-task execution and mechanically attenuated local authority.
- Parent-child integration tests and exact phase completion evidence.

Generated `.beam` files, fixture outputs, workspaces, and traces remain under
the ignored repository `build/` directory.

## Index

### Subdirectories

- None yet.

### Files

- [`alang_phase6_model_protocol.erl`](alang_phase6_model_protocol.erl) — the
  closed model profile, request, context, result, usage, metadata, canonical
  encoding, digest, and bounds validators.
- [`alang_phase6_mock_model.erl`](alang_phase6_mock_model.erl) — the bounded
  BEAM fixture adapter with digest-selected offline responses, stable
  provenance, no network or secrets, and a disabled live-provider gate.
- [`alang_phase6_model_protocol_tests.erl`](alang_phase6_model_protocol_tests.erl)
  — deterministic encoding, bounds, closed shapes, all result variants,
  fixture classes, and provider-isolation tests for Section 6.1.
- [Provider-neutral model boundary](model-boundary-contract.md) — the semantic
  request and result contract, retry classification, deterministic acceptance
  adapter, and explicitly deferred live integration.
- [`alang_phase6_context.erl`](alang_phase6_context.erl) — capability-aware
  selection of ordered provenance-bearing fragments, redacted action
  summaries, exclusion snapshots, and recursive nonexposure checks.
- [`alang_phase6_task.erl`](alang_phase6_task.erl) — the deterministic task
  transition system, immutable goal, checkpoint gates, runtime counters,
  bounds, and typed terminal results.
- [`alang_phase6_task_tests.erl`](alang_phase6_task_tests.erl) — context
  minimality, prompt-injection demotion, authority nonexposure, transition
  ordering, checkpoint, cancellation, and exhaustion evidence.
- [Deterministic task orchestration and context slicing](task-orchestration-and-context.md)
  — the runtime-owned control model, stop semantics, context rules, and
  instruction-authority boundary.
- [`alang_phase6_repair.erl`](alang_phase6_repair.erl) — bounded diagnostic-only
  repair classification, minimal repair requests, and digest-linked attempt
  provenance.
- [`alang_phase6_verifier.erl`](alang_phase6_verifier.erl) — independent
  artifact, Markdown, section, and journal predicates plus deterministic
  complete-or-incomplete witnesses.
- [`alang_phase6_repair_verifier_tests.erl`](alang_phase6_repair_verifier_tests.erl)
  — repair classification, provenance, budget, task-counter, artifact,
  journal, traversal, and symlink acceptance evidence.
- [Structured repair and completion verification](repair-and-completion-verification.md)
  — the narrow retry boundary and conjunctive durable completion gate.
- [`alang_phase6_child.erl`](alang_phase6_child.erl) — reduced child interface,
  parent-owned spawn, private correlation fence, typed result validation,
  cancellation, and late or wrong-session reply handling.
- [`alang_phase6_child_worker.erl`](alang_phase6_child_worker.erl) — the
  deadline-bound supervised child process and monitored executor boundary.
- [`alang_phase6_child_sup.erl`](alang_phase6_child_sup.erl) — the dynamic OTP
  supervisor for temporary child sessions.
- [`alang_phase6_child_tests.erl`](alang_phase6_child_tests.erl) — reduced
  context, subset, shared budget, binding, nondelegation, cancellation, reply
  fencing, and generated-surface acceptance evidence.
- [Mechanically attenuated child task](mechanically-attenuated-child-task.md) —
  the typed process boundary and its parent-to-child authority derivation.
- [`alang_phase6_integration_fixture.erl`](alang_phase6_integration_fixture.erl)
  — typed parent-repair and child model-effect IR compiled by the Phase 3 BEAM
  backend for final acceptance.
- [`alang_phase6_orchestrator.erl`](alang_phase6_orchestrator.erl) — the
  BEAM-resident live coordinator that places task checkpoints and typed
  transitions before and after each accepted model or workspace action.
- [`alang_phase6_integration_tests.erl`](alang_phase6_integration_tests.erl) —
  the compiled parent, repair, child, durable workspace, journal, verifier,
  nonexposure, negative-matrix, and exact-count completion gate.
- [Phase 6 bounded agent integration evidence](phase-06-integration-evidence.md)
  — the reproducible command, causal path, exact counts, denial matrix, and
  completion claim authorized by the final suite.

## Maintaining this index

Index every direct Phase 6 source, protocol, and evidence file. Provider
features must enter through the closed model boundary, remain bounded and
redacted, and never add a foreign executable to the trusted compiler or A-Lang
runtime path.
