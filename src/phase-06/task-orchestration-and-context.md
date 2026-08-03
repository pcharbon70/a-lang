---
title: "Phase 6 Deterministic Task Orchestration and Context Slicing"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - agent-runtime
  - beam
  - context-engineering
  - state-machines
aliases: []
---

# Phase 6 Deterministic Task Orchestration and Context Slicing

## Runtime-owned control

`alang_task_state_v1` keeps the immutable original goal separate from the
current plan and makes `prepare_context`, `request_model`, `decode`,
`verify_draft`, `request_write`, `verify_artifact`, and terminal states
explicit. A model result can supply a draft or a classified failure; it cannot
name the next state, mark completion, increase a bound, or select an effect.

The BEAM runtime owns model-call, repair, step, effect, byte, deadline, and
elapsed-time limits. Exhaustion returns a typed incomplete result. Cancellation
and failure are explicit transitions, unexpected events leave state unchanged,
and the original goal survives plan updates. Model and workspace requests are
consequential transitions and require a checkpoint acknowledgement over the
exact current state before their counters or pending identities advance.

## Context selection

The slicer accepts typed goal, input, evidence, diagnostic, retrieved-data, and
allowed-action candidates. It preserves source order, visibility, provenance,
and trust. Only `public` and `task_local` candidates enter the request; private
material is recorded only as an excluded identifier and reason. Retrieved text
is always data, never instruction authority.

Available actions become generated summaries containing the closed operation,
requirement, and declared constraints. They contain no callable, capability
reference, broker state, adapter credential, process address, or grant handle.
The slicer rejects prohibited keys and node-local terms recursively, enforces
fragment and total byte limits, and emits a content-free snapshot of selected
identities, provenance digests, exclusions, counts, and the final slice digest.

See the [provider-neutral model boundary](model-boundary-contract.md),
[Phase 6 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-06-bounded-llm-task-and-subagent-execution.md),
and [Phase 6 implementation index](README.md).
