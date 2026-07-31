---
title: "Sources"
kind: map
created: 2026-07-31
tags:
  - archive-navigation
  - directory-index
aliases:
  - "Sources index"
---

# Sources (`30-sources`)

## Purpose

Sources preserve provenance. Each document records a work that was read,
watched, heard, or otherwise consulted, along with the claims and limitations
that matter to the archive.

## What belongs here

- Bibliographic records and stable links.
- Concise summaries of a source's contribution.
- Evidence, quotations, limitations, and connections to other documents.

Keep original synthesis in [`20-notes`](../20-notes/README.md). A source note
should make it clear what the cited work supports and what remains an
interpretation.

## Index

### Subdirectories

- None yet.

### Documents

#### Agent and language systems

- [Prompting Is Programming: LMQL](beurer-kellner-et-al-2023-lmql.md) —
  constrained generation through a declarative query language.
- [Agent Programming with Declarative Goals](de-boer-et-al-2002-agent-programming-with-declarative-goals.md)
  — goal-oriented agent semantics that separate desired states from
  procedures.
- [DSPy](khattab-et-al-2024-dspy.md) — declarative language-model modules and
  metric-driven pipeline compilation.
- [LLM+P](liu-et-al-2023-llm-plus-p.md) — translation from natural-language
  tasks into PDDL for classical planning.
- [Logic-LM](pan-et-al-2023-logic-lm.md) — symbolic translation, solver
  execution, and diagnostic repair.
- [Task-related Language Development and Translation](pang-et-al-2023-task-related-language.md)
  — learned predicate-like task representations for instruction following.
- [Executable Code Actions Elicit Better LLM Agents](wang-et-al-2024-codeact.md)
  — executable Python as a unified agent action space.
- [AgentSpec](wang-et-al-2026-agentspec.md) — runtime-enforced safety and
  reliability policies for LLM agents.
- [AgentSPEX](wang-et-al-2026-agentspex.md) — an interpreted YAML language for
  explicit agent workflows, state, and context.
- [Do Prompt-Based Models Really Understand the Meaning of Their Prompts?](webson-pavlick-2022-prompt-meaning.md)
  — evidence cautioning against equating benchmark success with prompt
  understanding.
- [SatLM](ye-et-al-2023-satlm.md) — declarative constraints paired with
  satisfiability solving.

#### Authorization and capability systems

- [SPKI Certificate Theory](ellison-et-al-1999-spki-certificate-theory.md) —
  authorization certificates, delegated authority, and tuple reduction by
  authorization and validity intersection.
- [UCAN Revocation](ucan-wg-2025-revocation.md) — immutable, path-specific,
  potentially eventually consistent invalidation of Delegation proofs.
- [UCAN Delegation and Invocation](ucan-wg-2026-delegation-and-invocation.md) —
  the required version-1 formats for transferring attenuated authority and
  requesting its concrete exercise.
- [UCAN implementations and container](ucan-wg-2026-implementations-and-container.md)
  — current compatibility, audit, transport, implementation, and BEAM
  integration evidence.
- [UCAN specification](ucan-wg-2026-ucan-specification.md) — the current
  high-level certificate-capability, proof-chain, and execution-time
  validation model.

#### BEAM runtime and language implementation

- [A Formalisation of Core Erlang, a Concurrent Actor Language](bereczky-et-al-2024-formalisation-concurrent-core-erlang.md)
  — machine-checked concurrent semantics and observational equivalence for a
  Core Erlang subset.
- [Core Erlang 1.0.3 language specification](carlsson-et-al-2004-core-erlang-specification.md)
  — the compact compiler IR used as a semantic reference rather than a stable
  external backend contract.
- [BEAM instructions, loading, JIT execution, and compatibility](erlang-otp-2026-beam-execution.md)
  — current opcode evidence, BeamAsm execution, module loading, and artifact
  metadata constraints.
- [Erlang/OTP interoperability and secure coding](erlang-otp-2026-interoperability-and-security.md)
  — ports, NIF risks, trusted distribution assumptions, and OS-level isolation
  requirements.
- [Erlang/OTP compiler guidance for language implementors](erlang-otp-2026-language-implementors.md)
  — the case for Abstract Format and official warnings about Core Erlang and
  BEAM assembly generation.
- [Leex and Yecc parser tools](erlang-otp-2026-leex-and-yecc.md) — mature lexer
  and parser generators that emit Erlang source and therefore serve best as
  bootstrap or differential tools.
- [Erlang runtime processes, signals, scheduling, and memory](erlang-otp-2026-process-runtime.md)
  — ERTS concurrency strengths and its ordering, mailbox, memory, and atom
  constraints.
- [Erlang/OTP supervision and release handling](erlang-otp-2026-supervision-and-releases.md)
  — fault topology and code-version mechanics, distinguished from durable retry
  and state migration.
- [PropEr types and property-based testing](papadakis-sagonas-2011-proper.md) —
  open-source generative, shrinking, and state-machine testing for categorical
  and runtime laws on BEAM.

#### Categorical foundations and composition

- [Towards Foundations of Categorical Cybernetics](capucci-et-al-2022-categorical-cybernetics.md)
  — bidirectional interaction among open processes, environments, and
  controllers.
- [Hidden Markov Models and the Bayes Filter in Categorical Probability](fritz-et-al-2025-hidden-markov-bayes-filter-categorical-probability.md)
  — compositional filtering across several probabilistic settings.
- [Seven Sketches in Compositionality](fong-spivak-2019-seven-sketches-compositionality.md)
  — an applied-category foundation for interface-based composition.
- [Compositional Game Theory](ghani-et-al-2018-compositional-game-theory.md)
  — sequential and simultaneous composition with strategic context.
- [Compositional Scientific Computing with Catlab and SemanticModels](halter-et-al-2020-compositional-scientific-computing.md)
  — executable categorical models represented as syntax, ASTs, and wiring
  diagrams.
- [Generalising Monads to Arrows](hughes-2000-generalising-monads-arrows.md) —
  a law-governed interface for a broader family of typed computations.
- [Notions of Computation and Monads](moggi-1991-notions-computation-monads.md)
  — categorical semantics for partiality, state, nondeterminism, exceptions,
  and other effects.
- [Polynomial Functors](niu-spivak-2025-polynomial-functors-interaction.md) — a
  Set-based theory of interaction protocols and dynamical systems.
- [Handling Algebraic Effects](plotkin-pretnar-2013-handling-algebraic-effects.md)
  — modular effect operations and runtime handlers.
- [Categories of Optics](riley-2018-categories-of-optics.md) — lawful
  constructions for bidirectional views and updates.
- [Universal Coalgebra](rutten-2000-universal-coalgebra.md) — state systems,
  observation, bisimulation, and coinductive reasoning.
- [Functorial Data Migration](spivak-2012-functorial-data-migration.md) —
  categorical schemas, set-valued instances, and structured migration.

## Maintaining this index

Add each source under the most useful conceptual label, not only its citation
key. If the collection becomes large, split the index into stable thematic
subdirectories while preserving a route from this page.
