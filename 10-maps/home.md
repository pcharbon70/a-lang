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
- [Can UCAN enforce A-Lang agent capabilities?](../40-inquiries/can-ucan-enforce-a-lang-agent-capabilities.md)

## Maps

- [BEAM runtime for agent languages](beam-runtime-for-agent-languages.md)
- [Categorical foundations for agent languages](categorical-foundations-for-agent-languages.md)
- [LLM agent task languages](llm-agent-task-languages.md)
- [UCAN and delegated agent authority](ucan-and-delegated-agent-authority.md)

## Recently developed

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Task languages for LLM agents: a deep dive](../20-notes/llm-agent-task-languages-deep-dive.md)
- [UCAN capabilities for A-Lang: a deep dive](../20-notes/ucan-capabilities-for-agent-language.md)

## Implementation planning

- [A-Lang minimal proof-of-concept plan](../60-planning/01-minimal-proof-of-concept/README.md)
  — an eight-phase path from a frozen language contract through native
  compilation, BEAM execution, durable effects, UCAN authorization, bounded
  LLM and child-task execution, adversarial validation, and a final
  architecture decision.

## Unsettled threads

- Whether BEAM's concurrency advantages remain material after durable effect
  brokering and OS-level sandboxing are included.
- Whether a pinned UCAN profile provides enough cross-boundary portability and
  provenance to justify its identity, proof-storage, revocation, and versioning
  cost over broker-only opaque handles.
