---
title: "Polynomial Functors: A Mathematical Theory of Interaction"
kind: source
created: 2026-07-31
authors:
  - "Nelson Niu"
  - "David I. Spivak"
published: 2025
citation_key: niu2025PolynomialFunctors
container: "Cambridge University Press"
isbn: "978-1-009-57671-0"
doi: "10.1017/9781009576734"
url: "https://arxiv.org/abs/2312.00990"
accessed: 2026-07-31
tags:
  - polynomial-functors
  - interaction-protocols
  - dynamical-systems
aliases:
  - "Polynomial Functors"
---

# Polynomial Functors: A Mathematical Theory of Interaction

## Reference

Nelson Niu and David I. Spivak. *Polynomial Functors: A Mathematical Theory of
Interaction*. Cambridge University Press, 2025.
[Open manuscript](https://arxiv.org/abs/2312.00990)

## Contribution

The book studies polynomial endofunctors on `Set` as models of interaction
protocols and dynamical systems. Informally, a polynomial has a collection of
positions and, for each position, a collection of directions. Morphisms send
positions forward and directions backward, yielding a structured account of
two-way communication.

Dependent lenses, parallel products, composition products, wiring diagrams,
and state systems are developed within this concrete set-and-function
foundation.

## Finding

The framework can describe an interface by the outputs or positions a system
may expose and the inputs or directions admissible after each output. These
interfaces compose, including for stateful and dynamically interacting
systems.

## Relevance

This is the closest mathematical match to “Set category principles” for an
agent language. A tool or subagent interface can be more precise than a flat
function signature: its legal next inputs may depend on the previous response.
That supports typed multi-turn protocols, state-dependent capabilities, and
workflow generation from interface structure.

## Limits

The work supplies a mathematical theory, not a tested agent DSL. Mapping tool
APIs and conversational protocols into useful polynomials requires design
judgment, and exposing the theory directly would probably be too demanding for
most authors.

## Derived notes

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Categorical foundations for agent languages](../10-maps/categorical-foundations-for-agent-languages.md)
