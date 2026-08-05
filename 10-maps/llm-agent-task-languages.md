---
title: "LLM agent task languages"
kind: map
created: 2026-07-30
tags:
  - llm-agents
  - task-specification
  - programming-languages
aliases:
  - "Task languages for LLM agents"
---

# LLM agent task languages

## Scope

This map covers the relationship between transformers, instruction following,
formal task representations, programming-language abstractions, and reliable
LLM-agent execution.

## Start here

- [Deep-dive synthesis](../20-notes/llm-agent-task-languages-deep-dive.md)
- [Open inquiry](../40-inquiries/can-a-task-language-improve-llm-agents.md)

## Foundations and evaluation cautions

- [Prompt meaning](../30-sources/webson-pavlick-2022-prompt-meaning.md) —
  benchmark performance is not enough to establish semantic understanding.
- The deep dive also connects transformer architecture, instruction tuning,
  demonstrations, constraint-following evaluations, and long-context failures.

## Declarative intent and formal reasoning

- [GOAL](../30-sources/de-boer-et-al-2002-agent-programming-with-declarative-goals.md)
  — separate goals-to-be from procedures.
- [SatLM](../30-sources/ye-et-al-2023-satlm.md) — declarative constraints plus
  theorem proving.
- [Logic-LM](../30-sources/pan-et-al-2023-logic-lm.md) — symbolic translation,
  solver execution, and diagnostic repair.
- [LLM+P](../30-sources/liu-et-al-2023-llm-plus-p.md) — natural language to PDDL
  and classical planning.

## Programming language approaches

- [LMQL](../30-sources/beurer-kellner-et-al-2023-lmql.md) — query constraints
  and generation-aware compilation.
- [DSPy](../30-sources/khattab-et-al-2024-dspy.md) — declarative modules and
  metric-driven compilation.
- [CodeAct](../30-sources/wang-et-al-2024-codeact.md) — executable Python as an
  agent action space.
- [AgentSPEX](../30-sources/wang-et-al-2026-agentspex.md) — interpreted YAML
  workflows with explicit state and context.

## Categorical semantic foundations

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
  — a layered semantic proposal covering pure data, effects, state,
  interaction, uncertainty, and structure-preserving interpreters.
- [Categorical foundations for agent languages](categorical-foundations-for-agent-languages.md)
  — the research trail through the relevant programming-language and applied
  category theory.
- [Open empirical inquiry](../40-inquiries/can-categorical-semantics-improve-agent-language.md)
  — asks whether categorical structure adds measurable value beyond a strong
  conventional typed DSL.

## BEAM execution substrate

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
  — proposes a wholly BEAM-resident compiler toolchain and categorical IR
  compiled through OTP's supported Abstract Format, without an existing BEAM
  language as the interpreter for A-Lang programs.
- [BEAM runtime map](beam-runtime-for-agent-languages.md) — connects Core
  Erlang, compiler boundaries, ERTS processes, supervision, ports, security,
  and property-based testing.
- [BEAM feasibility inquiry](../40-inquiries/can-beam-support-a-native-agent-language.md)
  — defines the compatibility, correctness, performance, durability, and
  isolation gates the runtime must pass.

## Task-specific and enforced languages

- [TALAR](../30-sources/pang-et-al-2023-task-related-language.md) — a learned,
  predicate-like task representation for instruction-following policies.
- [AgentSpec](../30-sources/wang-et-al-2026-agentspec.md) — a runtime-enforced
  DSL for safety constraints.

## Local capability enforcement

The current proof-of-concept boundary separates declarative capability
requirements from runtime grants without choosing a portable protocol. A
trusted BEAM broker holds typed resource scope, budgets, deadlines, and
revocation state; generated A-Lang processes receive only opaque local
references and must route effects through the closed runtime ABI.

## Symbol-aware repository context

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
  — separates compiler-derived symbol facts, authored semantic relations, and
  selectively materialized model context, with a falsifiable promotion gate.
- [Symbol-aware code context for LLM agents](symbol-aware-code-context-for-llm-agents.md)
  — follows the evidence through cross-file completion, repository QA, code
  graphs, agent interfaces, LSP, SCIP, generated maps, and prompt injection.
- [Open source-reference inquiry](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
  — asks whether source embedding adds value beyond an equal-budget generated
  symbol map.

This is deliberately separate from the active notation experiment. The current
effectful source fidelity campaign compares A-Lang with typed JSON; it does not
vary repository-navigation context or authorize a new reference form.

## Emerging design thesis

The most promising language is layered:

1. human-readable declarative intent;
2. a typed task intermediate representation;
3. compiled prompts and context slices for bounded LLM judgments;
4. executable action representations;
5. deterministic control flow, capabilities, and runtime monitors;
6. verifier-backed evidence of completion.

BEAM is now the leading candidate for both the trusted compiler host and the
concurrent execution layer, provided the language retains its own IR and
treats durable effects and hostile-code isolation as separate responsibilities.

The unresolved question is how much of this should be one language, and how
much should be a family of interoperating representations with a common task
model.

## Active implementation test

The [effectful source fidelity plan](../60-planning/02-effectful-source-fidelity/README.md)
turns the central notation question into a bounded experiment: A-Lang and a
closed typed-JSON control express matched task semantics, compile through the
same BEAM enforcement path, and are compared across two declared hosted model
families with deterministic scoring and safety vetoes. Until its evidence
exists, it is an experimental design rather than support for either notation.

## Open questions

- Which semantic core generalizes across research, coding, web, and embodied
  tasks?
- Should plans be authored, synthesized, or mixed?
- How should subjective success criteria be represented?
- Can semantic translation be tested without recreating the whole task?
- What representation best supports clarification and negotiated intent?
- When does a compact DSL help enough to offset its learning and authoring cost?
- Can a BEAM backend preserve this task model across supported OTP releases
  without making OTP compiler internals part of the language semantics?
- Can opaque local grants and a closed BEAM effect ABI provide sufficient
  least-authority enforcement for the first proof of concept?
- Do compiler-resolved authored source relations improve LLM understanding
  beyond a generated symbol map under an equal context budget?
