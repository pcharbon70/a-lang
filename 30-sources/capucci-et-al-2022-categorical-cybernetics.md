---
title: "Towards Foundations of Categorical Cybernetics"
kind: source
created: 2026-07-31
authors:
  - "Matteo Capucci"
  - "Bruno Gavranović"
  - "Jules Hedges"
  - "Eigil Fjeldgren Rischel"
published: 2022
citation_key: capucci2022CategoricalCybernetics
container: "Electronic Proceedings in Theoretical Computer Science 372, 235–248"
doi: "10.4204/EPTCS.372.17"
url: "https://arxiv.org/abs/2105.06332"
accessed: 2026-07-31
tags:
  - categorical-cybernetics
  - feedback
  - open-systems
aliases: []
---

# Towards Foundations of Categorical Cybernetics

## Reference

Matteo Capucci, Bruno Gavranović, Jules Hedges, and Eigil Fjeldgren Rischel.
“Towards Foundations of Categorical Cybernetics.” *Electronic Proceedings in
Theoretical Computer Science* 372 (2022): 235–248.
[Open paper](https://arxiv.org/abs/2105.06332)

## Contribution

The paper proposes a categorical framework for open processes that interact
bidirectionally with both an environment and a controller. Its examples include
learners controlled by optimizers and game-like systems controlled by composed
strategic agents.

The framework is built to preserve the compositional structure of systems that
have forward behavior and backward information such as updates, objectives, or
feedback.

## Finding

Bidirectional environment–system–controller interaction can be represented
compositionally rather than collapsing the entire feedback loop into one
opaque process.

## Relevance

Agent execution has the same broad shape: an action produces an environmental
observation, while tests, critiques, reward, policy decisions, and human
feedback flow back toward the controller. A categorical agent IR could make
these channels first-class and prevent “feedback” from becoming an untyped
string appended to a prompt.

## Limits

The work is foundational and does not specify LLM prompting, tool security, or
an end-user programming language. Whether its abstractions yield simpler agent
software or better outcomes is an implementation and evaluation question.

## Derived notes

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Can categorical semantics materially improve an agent language?](../40-inquiries/can-categorical-semantics-improve-agent-language.md)
