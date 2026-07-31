---
title: "Categorical foundations for agent languages"
kind: map
created: 2026-07-31
tags:
  - agent-programming
  - category-theory
  - compositionality
  - programming-languages
aliases:
  - "Category theory for agent programming"
---

# Categorical foundations for agent languages

## Scope

This map connects `Set`-based data semantics, categorical composition,
computational effects, stateful systems, interaction protocols, probability,
feedback, multi-agent structure, and practical categorical software to the
design of an agent-specific programming language.

The proposal belongs inside the broader
[LLM agent task-languages map](llm-agent-task-languages.md). Its central open
question is whether category-specific structure adds measurable value beyond a
good conventional typed DSL.

## Start here

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
  — the full design and evidence synthesis.
- [Can categorical semantics materially improve an agent language?](../40-inquiries/can-categorical-semantics-improve-agent-language.md)
  — hypotheses, comparison conditions, and falsification criteria.

## Composition and effects

- [Seven Sketches in Compositionality](../30-sources/fong-spivak-2019-seven-sketches-compositionality.md)
  provides the broad applied-category account of composable systems.
- [Notions of Computation and Monads](../30-sources/moggi-1991-notions-computation-monads.md)
  explains why agent actions cannot be modeled only as total functions in
  `Set`.
- [Handling Algebraic Effects](../30-sources/plotkin-pretnar-2013-handling-algebraic-effects.md)
  separates effect requests from runtime handlers.
- [Generalising Monads to Arrows](../30-sources/hughes-2000-generalising-monads-arrows.md)
  supplies a broader typed composition interface.

## State, interaction, and feedback

- [Universal Coalgebra](../30-sources/rutten-2000-universal-coalgebra.md)
  develops observation, state transition, bisimulation, and coinduction.
- [Polynomial Functors](../30-sources/niu-spivak-2025-polynomial-functors-interaction.md)
  models interaction protocols and dynamical systems from a concrete
  set-and-function foundation.
- [Categorical Cybernetics](../30-sources/capucci-et-al-2022-categorical-cybernetics.md)
  organizes bidirectional environment and controller feedback.
- [Categories of Optics](../30-sources/riley-2018-categories-of-optics.md)
  offers lawful constructions for focused views and updates.

## Capability restriction

For the proof of concept, a runtime grant denotes a broker-held subset of the
well-typed effect invocations available to one session. Narrowing must preserve
subset inclusion, independent local grants may combine by union only when the
broker permits it, and opaque references carry no authority outside the
issuing BEAM runtime. These are proposed local enforcement laws, not claims
about a portable certificate protocol.

## Uncertainty, data, and interpretation

- [Categorical Hidden Markov Models](../30-sources/fritz-et-al-2025-hidden-markov-bayes-filter-categorical-probability.md)
  unifies filtering across multiple probabilistic settings.
- [Functorial Data Migration](../30-sources/spivak-2012-functorial-data-migration.md)
  connects schemas, set-valued instances, and structure-preserving migration.
- [Catlab and SemanticModels](../30-sources/halter-et-al-2020-compositional-scientific-computing.md)
  demonstrates executable categorical syntax, diagrams, composition, and
  solver integration.

## Multi-agent structure

- [Compositional Game Theory](../30-sources/ghani-et-al-2018-compositional-game-theory.md)
  distinguishes sequential and simultaneous composition while retaining
  strategic context and global-equilibrium concerns.
- [Agent Programming with Declarative Goals](../30-sources/de-boer-et-al-2002-agent-programming-with-declarative-goals.md)
  keeps goals separate from procedures in a formally grounded agent language.

## Bridge to current LLM-agent languages

- [AgentSPEX](../30-sources/wang-et-al-2026-agentspex.md) demonstrates benefits
  from interpreted workflows and explicit context management.
- [AgentSpec](../30-sources/wang-et-al-2026-agentspec.md) demonstrates runtime
  interception and enforcement of policy rules.
- [DSPy](../30-sources/khattab-et-al-2024-dspy.md) separates declarative
  language-model interfaces from compiled prompt realization.
- [LMQL](../30-sources/beurer-kellner-et-al-2023-lmql.md) supplies compiled
  query constraints over language-model generation.

These works support the surrounding architecture but do not isolate category
theory as the cause of better agent performance.

## Design thesis

Use category theory below a familiar surface language:

1. `Set`-like schemas for ordinary data;
2. typed task arrows for composable components;
3. products and coproducts for data and branch structure;
4. explicit effect operations and capability-sensitive handlers;
5. monoidal composition for checked parallelism;
6. coalgebraic or polynomial types for stateful interaction;
7. functorial interpreters for live, simulated, traced, visual, and policy
   views;
8. verifier-backed completion evidence.

Add advanced structures only when a benchmark makes their value observable.

## Candidate execution substrate

- [BEAM runtime for agent languages](beam-runtime-for-agent-languages.md)
  explores how lightweight processes, supervision, ports, and code loading can
  realize the effectful and coalgebraic layers.
- [PropEr](../30-sources/papadakis-sagonas-2011-proper.md) can execute
  generative law and state-machine tests on the target VM.
- [Concurrent Core Erlang formalisation](../30-sources/bereczky-et-al-2024-formalisation-concurrent-core-erlang.md)
  motivates observational equivalence and bisimulation for concurrent laws.

This is an implementation hypothesis, not a new categorical result. The
language should own its IR and lower through a supported compiler boundary.

## Open questions

- Which useful categorical laws survive nondeterministic LLM behavior?
- What is the right observable equivalence for two agent workflows?
- Can effect and capability inference remain understandable to authors?
- When are two tasks sufficiently independent for monoidal parallel execution?
- Do polynomial protocol types improve tool use enough to justify their
  implementation cost?
- Can backend translations preserve user-visible semantics across model and
  tool versions?
- Does a categorical IR beat a conventional typed IR after controlling for
  runtime enforcement?
- Which categorical equivalences remain observable and testable under BEAM
  scheduling, failure, messaging, and resource limits?
- Can local capability restriction be specified precisely enough for generated
  law tests and, later, mechanized proof without binding the semantics to an
  external authorization protocol?
