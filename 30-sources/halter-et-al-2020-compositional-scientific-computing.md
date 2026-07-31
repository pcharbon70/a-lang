---
title: "Compositional Scientific Computing with Catlab and SemanticModels"
kind: source
created: 2026-07-31
authors:
  - "Micah Halter"
  - "Evan Patterson"
  - "Andrew Baas"
  - "James Fairbanks"
published: 2020
citation_key: halter2020Catlab
container: "Applied Category Theory 2020 conference paper"
doi: "10.48550/arXiv.2005.04831"
url: "https://arxiv.org/abs/2005.04831"
accessed: 2026-07-31
tags:
  - applied-category-theory
  - categorical-software
  - domain-specific-languages
aliases:
  - "Catlab and SemanticModels"
---

# Compositional Scientific Computing with Catlab and SemanticModels

## Reference

Micah Halter, Evan Patterson, Andrew Baas, and James Fairbanks.
“Compositional Scientific Computing with Catlab and SemanticModels.” Applied
Category Theory 2020 conference paper, 2020.
[Open paper](https://arxiv.org/abs/2005.04831)

## Contribution

The paper presents Catlab.jl and SemanticModels.jl as software for categorical
and compositional scientific computing. Catlab represents categorical
expressions as formulas, abstract syntax trees, wiring diagrams, or familiar
program syntax. SemanticModels composes open models sequentially and in
parallel and connects the result to numerical solvers.

The same structured model can therefore support symbolic manipulation,
visualization, comparison, composition, and executable interpretation.

## Finding

This work is an implementation demonstration that categorical models need not
remain paper mathematics. A concrete software ecosystem can store categorical
syntax, compose models, translate representations, and generate executable
simulations.

## Relevance

An agent language could similarly retain one typed categorical IR while
offering text syntax, a visual workflow, a simulator, a traced executor, and
specialized compiler backends. The paper also supports implementing category
theory inside a practical host language rather than creating every facility
from scratch.

## Limits

The paper is short and focused on scientific models, not agent reliability or
language usability. It demonstrates feasibility and reuse, not a controlled
performance advantage attributable solely to category theory.

## Derived notes

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Categorical foundations for agent languages](../10-maps/categorical-foundations-for-agent-languages.md)
