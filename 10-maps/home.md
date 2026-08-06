---
title: "A-Lang"
kind: map
created: 2026-07-30
tags: []
aliases:
  - "Home"
---

# A-Lang

This is the entry point to the archive. It should remain selective: a map of
useful paths rather than an inventory of every file.

See the [archive guide](../README.md) for its structure and conventions.

## Active inquiries

- [Can BEAM support a native agent language safely and maintainably?](../40-inquiries/can-beam-support-a-native-agent-language.md)
- [Can categorical semantics materially improve an agent language?](../40-inquiries/can-categorical-semantics-improve-agent-language.md)
- [Can a task language improve LLM agents?](../40-inquiries/can-a-task-language-improve-llm-agents.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)

## Maps

- [BEAM runtime for agent languages](beam-runtime-for-agent-languages.md)
- [Categorical foundations for agent languages](categorical-foundations-for-agent-languages.md)
- [LLM agent task languages](llm-agent-task-languages.md)
- [Symbol-aware code context for LLM agents](symbol-aware-code-context-for-llm-agents.md)

## Recently developed

- [Effectful source fidelity architecture decision](../src/effectful-source-fidelity/effectful-source-fidelity-architecture-decision.md)
  — stops both experimental authoring surfaces after the hosted campaign
  closed invalid, while retaining bounded BEAM compiler/runtime evidence.
- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Task languages for LLM agents: a deep dive](../20-notes/llm-agent-task-languages-deep-dive.md)
- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)

## Implementation planning

- [A-Lang minimal proof-of-concept plan](../60-planning/01-minimal-proof-of-concept/README.md)
  — a BEAM-first, eight-phase path that proves direct ERTS execution before
  adding the BEAM-resident compiler frontend, supervised runtime, local capability broker,
  durable effects, bounded model and child-task execution, adversarial
  validation, and a final architecture decision.
- [Effectful source fidelity plan](../60-planning/02-effectful-source-fidelity/README.md)
  — the numbered successor implemented matched A-Lang and typed-JSON BEAM
  paths, then conservatively stopped both authoring surfaces when the hosted
  campaign closed invalid without calls or efficacy evidence.

## Unsettled threads

- Whether BEAM's concurrency advantages remain material after durable effect
  brokering and OS-level sandboxing are included.
- Whether a small local capability broker can enforce least authority without
  portable delegation or an unnecessary second authorization runtime.
- Whether authored typed source relations improve grounded code understanding
  beyond a generated symbol map under the same context budget.
