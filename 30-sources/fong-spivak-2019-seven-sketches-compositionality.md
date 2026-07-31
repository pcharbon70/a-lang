---
title: "An Invitation to Applied Category Theory: Seven Sketches in Compositionality"
kind: source
created: 2026-07-31
authors:
  - "Brendan Fong"
  - "David I. Spivak"
published: 2019
citation_key: fong2019SevenSketches
container: "Cambridge University Press"
isbn: "978-1-108-71182-1"
doi: "10.1017/9781108668804"
url: "https://arxiv.org/abs/1803.05316"
accessed: 2026-07-31
tags:
  - category-theory
  - compositionality
  - applied-category-theory
aliases:
  - "Seven Sketches in Compositionality"
---

# An Invitation to Applied Category Theory: Seven Sketches in Compositionality

## Reference

Brendan Fong and David I. Spivak. *An Invitation to Applied Category Theory:
Seven Sketches in Compositionality*. Cambridge University Press, 2019.
[Open manuscript](https://arxiv.org/abs/1803.05316)

## Contribution

The book develops category theory as a language for compositional systems. Its
examples include orders, databases, resource theories, co-design, electrical
circuits, and dynamical systems. Across these domains, objects describe
interfaces or system boundaries, morphisms describe processes, and categorical
composition builds a whole from compatible parts.

The account also develops monoidal categories and wiring diagrams for parallel
or side-by-side composition, functors for structure-preserving interpretations,
and universal constructions that specify an object by how it relates to other
objects rather than by a concrete implementation.

## Finding

This is a mathematical and expository work, not an empirical software study.
Its relevant result is a reusable formal pattern: when a domain admits
well-chosen interfaces and composition operations, category laws support local
construction and reasoning that remain valid inside larger compositions.

## Relevance

An agent language can use the same pattern to make task components typed and
composable. Sequential composition, parallel composition, branching, and
multiple interpretations can be given one coherent semantic vocabulary rather
than being unrelated workflow features.

The strongest design lesson is to use category theory as the language's
semantic spine. Authors and LLMs need not manipulate advanced categorical
terminology in the surface syntax.

## Limits

The book does not show that a category-based agent language improves task
success, intent recognition, or usability. Those benefits require a concrete
language, compiler, runtime, and controlled evaluation.

## Derived notes

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Categorical foundations for agent languages](../10-maps/categorical-foundations-for-agent-languages.md)
