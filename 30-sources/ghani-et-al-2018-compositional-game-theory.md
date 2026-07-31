---
title: "Compositional Game Theory"
kind: source
created: 2026-07-31
authors:
  - "Neil Ghani"
  - "Jules Hedges"
  - "Viktor Winschel"
  - "Philipp Zahn"
published: 2018
citation_key: ghani2018CompositionalGames
container: "33rd Annual ACM/IEEE Symposium on Logic in Computer Science, 472–481"
doi: "10.1145/3209108.3209165"
url: "https://arxiv.org/abs/1603.04641"
accessed: 2026-07-31
tags:
  - compositional-game-theory
  - multi-agent-systems
  - monoidal-categories
aliases: []
---

# Compositional Game Theory

## Reference

Neil Ghani, Jules Hedges, Viktor Winschel, and Philipp Zahn. “Compositional
Game Theory.” In *33rd Annual ACM/IEEE Symposium on Logic in Computer Science*,
472–481, 2018.
[Open manuscript](https://arxiv.org/abs/1603.04641)

## Contribution

The paper introduces open games as morphisms in a symmetric monoidal category.
Categorical composition builds sequential games; the monoidal product builds
simultaneous games. Interfaces describe where an open game interacts with its
environment, and string diagrams visualize information flow.

The construction preserves strategies, equilibria, and off-equilibrium best
responses for the covered games while building larger games from smaller ones.

## Finding

Strategic interaction can be made modular, but only after the interface carries
enough contextual information. The paper also stresses that a composite
equilibrium is not generally obtained by combining locally optimal choices.

## Relevance

Multi-agent orchestration needs more than parallel tool calls. Agents may have
different goals, information, permissions, and incentives. Open-system
semantics suggests typed communication boundaries and explicit forward and
backward context for composing such systems.

The warning about local versus global optimality is especially important for
delegation: independently successful subagents do not guarantee a successful
whole task.

## Limits

The formal agents are game-theoretic decision makers, not LLM agents, and the
paper's covered solution concepts are deliberately limited. Translating human
organizational concerns into utilities or best-response relations can be
misleading.

## Derived notes

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Can categorical semantics materially improve an agent language?](../40-inquiries/can-categorical-semantics-improve-agent-language.md)
