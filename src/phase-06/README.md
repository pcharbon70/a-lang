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

## Maintaining this index

Index every direct Phase 6 source, protocol, and evidence file. Provider
features must enter through the closed model boundary, remain bounded and
redacted, and never add a foreign executable to the trusted compiler or A-Lang
runtime path.
