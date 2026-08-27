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
- [Can a compact projection reduce A-Lang token use without reducing fidelity?](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)

## Maps

- [BEAM runtime for agent languages](beam-runtime-for-agent-languages.md)
- [Categorical foundations for agent languages](categorical-foundations-for-agent-languages.md)
- [LLM agent task languages](llm-agent-task-languages.md)
- [Semantic code graphs for LLM agents](semantic-code-graphs-for-llm-agents.md)
- [Symbol-aware code context for LLM agents](symbol-aware-code-context-for-llm-agents.md)
- [Token-efficient A-Lang syntax](token-efficient-alang-syntax.md)

## Recently developed

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Task languages for LLM agents: a deep dive](../20-notes/llm-agent-task-languages-deep-dive.md)
- [Token-efficient syntax for A-Lang](../20-notes/token-efficient-syntax-for-a-lang.md)
- [Model-facing A-Lang promotion must be token-positive](../20-notes/model-facing-alang-promotion-must-be-token-positive.md)
- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)

## Implementation planning

- [A-Lang minimal proof-of-concept plan](../60-planning/01-minimal-proof-of-concept/README.md)
  — a BEAM-first, eight-phase path that proves direct ERTS execution before
  adding the BEAM-resident compiler frontend, supervised runtime, local capability broker,
  durable effects, bounded model and child-task execution, adversarial
  validation, and a final architecture decision.
- [Effectful source fidelity plan](../60-planning/02-effectful-source-fidelity/README.md)
  — the numbered successor that compares user-authored effectful A-Lang with
  semantically matched typed JSON while holding the BEAM enforcement path
  constant and applying a pre-registered decision rule.
- [Compact projection fidelity plan](../60-planning/03-compact-projection-fidelity/README.md)
  — a separate preregistered path from checked BEAM projection through a
  2,304-cell, two-model comparison of token cost, semantic non-inferiority,
  repair, robustness, and safety; readable v2 remains canonical in every
  outcome.
- [Token-positive mnemonic promotion plan](../60-planning/04-token-positive-mnemonic-promotion/README.md)
  — prospectively re-registers the exact R2 surface after the negative R3
  token result; it requires those same mnemonic bytes to be cheaper than
  readable A-Lang on every frozen request before model fidelity and safety can
  authorize promotion.

## Unsettled threads

- Whether BEAM's concurrency advantages remain material after durable effect
  brokering and OS-level sandboxing are included.
- Whether a small local capability broker can enforce least authority without
  portable delegation or an unnecessary second authorization runtime.
- Whether authored typed source relations improve grounded code understanding
  beyond a generated symbol map under the same context budget.
- Whether a reversible compact projection can reduce A-Lang's model-token cost
  without losing semantic fidelity, diagnostics, or the safety value of
  descriptive names and explicit authority.
- Whether a derived queryable graph, provenance-bearing semantic claims, or
  inline placement adds value after graph facts and context budgets are
  controlled independently—and whether its live workspace snapshots can remain
  exact while an agent edits temporarily invalid code.
