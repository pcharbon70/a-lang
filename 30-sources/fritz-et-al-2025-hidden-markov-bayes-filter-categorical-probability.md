---
title: "Hidden Markov Models and the Bayes Filter in Categorical Probability"
kind: source
created: 2026-07-31
authors:
  - "Tobias Fritz"
  - "Andreas Klingler"
  - "Drew McNeely"
  - "Areeb Shah-Mohammed"
  - "Yuwen Wang"
published: 2025
citation_key: fritz2025CategoricalHMM
container: "IEEE Transactions on Information Theory 71(9), 7052–7075"
doi: "10.1109/TIT.2025.3584695"
url: "https://arxiv.org/abs/2401.14669"
accessed: 2026-07-31
tags:
  - markov-categories
  - probability
  - belief-state
aliases: []
---

# Hidden Markov Models and the Bayes Filter in Categorical Probability

## Reference

Tobias Fritz, Andreas Klingler, Drew McNeely, Areeb Shah-Mohammed, and Yuwen
Wang. “Hidden Markov Models and the Bayes Filter in Categorical Probability.”
*IEEE Transactions on Information Theory* 71, no. 9 (2025): 7052–7075.
[Open manuscript](https://arxiv.org/abs/2401.14669)

## Contribution

The paper develops hidden Markov models, conditional independence, Bayesian
filtering, and smoothing within Markov categories. The abstract algorithms
specialize to familiar algorithms when interpreted in discrete, Gaussian, and
measure-theoretic probability, and also cover possibilistic nondeterminism.

String diagrams expose the direction and dependency of probabilistic
information flow while the categorical statements remain independent of one
concrete probability representation.

## Finding

One compositional theory can preserve the structure of filtering algorithms
across multiple probabilistic settings. This is a precise example of backend
generality obtained through structure-preserving interpretation.

## Relevance

An agent language should not encode facts, guesses, nondeterministic choices,
and probability distributions as the same untyped value. Markov-category ideas
offer a possible semantic layer for belief updates, sensor uncertainty,
confidence-bearing evidence, and probabilistic tools while retaining explicit
composition.

## Limits

LLM confidence is not automatically a calibrated probability, and many agent
tasks lack a defensible generative model. A Markov semantics would be useful
only where uncertainty has an operational interpretation; otherwise it could
add mathematical ceremony without better decisions.

## Derived notes

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Can categorical semantics materially improve an agent language?](../40-inquiries/can-categorical-semantics-improve-agent-language.md)
