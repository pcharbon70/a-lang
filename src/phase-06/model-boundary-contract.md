---
title: "Phase 6 Provider-Neutral Model Boundary"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - beam
  - llm-agents
  - model-adapters
  - typed-protocols
aliases: []
---

# Phase 6 Provider-Neutral Model Boundary

## Semantic boundary

A-Lang sees one closed `alang_model_request_v1` value and one closed
`alang_model_result_v1` sum. A request names a trusted model profile, ordered
context fragments, one instruction, an output schema, absolute deadline,
retry class, redaction policy, and provenance. The profile fixes the provider
class, model identity, sampling policy, byte and token limits, and timeout;
there is no map for arbitrary provider parameters, URL selection, headers, or
credentials.

Canonical deterministic external-term encoding and SHA-256 identify the exact
request. Context order is semantic, fragment identifiers are unique, every
fragment carries a provenance digest and trust classification, and the total
instruction plus context size must fit the profile before an adapter call.

## Result algebra

Success contains bounded output, the schema-tagged parsed value, bounded usage,
and a four-field provider metadata record. Failure is one of
`invalid_syntax`, `schema_failure`, `content_policy_denial`, `timeout`,
`provider_error`, `budget_exhausted`, or `outcome_unknown`, with a bounded
diagnostic, usage, retained metadata, deterministic retry classification, and
definitive-or-uncertain outcome marker.

Syntax and schema failures are potentially repairable. An uncertain transport
outcome is never silently retried. Later Phase 6 sections make those choices
in the runtime state machine rather than in the provider adapter.

## Acceptance adapter

[`alang_phase6_mock_model`](alang_phase6_mock_model.erl) is the mandatory
offline acceptance adapter. It selects a fixture only by the canonical request
digest and emits stable usage, request identity, and provenance without
network access or secrets. Fixtures cover valid, malformed, schema-invalid,
policy-denied, timeout, transient, permanent, and uncertain results.

The optional live path is an explicit `live_provider_disabled` feature gate in
this proof of concept. No live provider, credentials, arbitrary endpoint, or
nondeterministic response is needed to complete Phase 6. A future live adapter
must implement this exact boundary behind an OS-isolated effect and cannot
weaken the mandatory deterministic tests.

See the [Phase 6 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-06-bounded-llm-task-and-subagent-execution.md)
and [Phase 6 implementation index](README.md).
