---
title: "Effectful Source Fidelity Architecture Decision"
kind: note
created: 2026-08-06
maturity: developing
tags:
  - architecture-decision
  - beam
  - evaluation
  - llm-agents
  - task-language
aliases:
  - "Phase 6 fidelity decision"
---

# Effectful Source Fidelity Architecture Decision

## Decision

Stop user-facing language-surface expansion without an efficacy conclusion.
Retain the evidence-supported BEAM compiler and runtime enforcement work, but
freeze both `alang-source-v2` and `alang-task-json-v1` as experimental
authoring paths.

The canonical machine outcome is
`stop-invalid-campaign-no-efficacy-conclusion`. It follows the
pre-registered invalid-campaign branch; it is not a judgment that A-Lang,
typed JSON, or either hosted model family performed better.

## Evidence

No live model authorization was granted and no hosted request was made. The
[retained closure](../../assets/effectful-source-fidelity/evidence/hosted-campaign-closure-v1.json)
records zero attempts, calls, tokens, and cost. The BEAM freeze pass expands
that closure against the immutable schedule and accounts for all 288 primary
cells as missing with one common cause,
`live-authorization-not-granted`.

The validity gate fails exactly three predicates:

- live authorization is absent;
- no hosted score set exists to reproduce; and
- no cell has its three required scorable primary observations.

Consequently, the analysis contains no OpenAI, Anthropic, pooled, task-family,
component, safety-difference, effect-size, bootstrap-interval, or sensitivity
result. The deterministic decision digest is
`185756c9b9dcec2c63a5d03f14085fa39e957e6d242869eee778db81014bbb06`;
its campaign-freeze digest is
`c08454cf2887639d5012633472c36445cdc7467711686d865835d1a99f9a16a0`.

## Retained implementation

The following bounded implementation evidence remains useful independently of
the failed comparison:

- both source conditions validate, statically check, and lower through
  separate BEAM frontends into matched A-Lang-owned IR;
- all 48 frozen source documents compile to inspected BEAM and run through the
  same broker, durability, model, child, workspace, and completion boundaries;
- fixed OpenAI and Anthropic adapters, durable campaign accounting,
  deterministic scoring, and replay work against offline fault fixtures; and
- the original compiler, runtime, adversarial, fault, property, mutation, and
  completion gates remain green.

These facts establish implementation mechanics, not hosted-model fidelity.

## Consequences

- Do not present `alang-source-v2` or `alang-task-json-v1` as a supported
  user-facing task language.
- Do not cite the deterministic offline fixture campaign as model evidence.
- Do not claim production readiness, cross-model validity, human-usability
  benefit, or categorical advantage.
- Keep the runtime-local capability broker, durability protocol, inspected
  BEAM backend, and verifier-backed completion as bounded proof-of-concept
  results.
- Keep the broader [task-language inquiry](../../40-inquiries/can-a-task-language-improve-llm-agents.md)
  open: this experiment did not answer it.

## Later authorization boundary

A later hosted comparison would be a new experiment, not a continuation or
rerun of this stream. It requires explicit approval, a newly numbered planning
stream, fresh provider and pricing verification, and a new pre-registration.
This decision does not authorize recursion, polymorphism, parallelism,
distribution, portable delegation, additional effects, packages,
self-hosting, categorical surface notation, human-usability claims, or
production scope.

## Connections

- [Phase 6 implementation plan](../../60-planning/02-effectful-source-fidelity/phase-06-fidelity-decision-and-roadmap-handoff.md)
- [Effectful source fidelity roadmap](../../60-planning/02-effectful-source-fidelity/README.md)
- [Phase 5 offline evidence](phase-05-offline-integration-evidence.md)
- [Phase 6 decision and handoff evidence](phase-06-integration-evidence.md)
- [Original Phase 8 architecture decision](../phase-08/proof-of-concept-architecture-decision.md)
- [LLM agent task-language map](../../10-maps/llm-agent-task-languages.md)
