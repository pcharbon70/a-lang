---
title: "Generalising Monads to Arrows"
kind: source
created: 2026-07-31
authors:
  - "John Hughes"
published: 2000
citation_key: hughes2000Arrows
container: "Science of Computer Programming 37(1–3), 67–111"
doi: "10.1016/S0167-6423(99)00023-4"
url: "https://www.sciencedirect.com/science/article/pii/S0167642399000234"
accessed: 2026-07-31
tags:
  - arrows
  - functional-programming
  - compositionality
aliases: []
---

# Generalising Monads to Arrows

## Reference

John Hughes. “Generalising Monads to Arrows.” *Science of Computer
Programming* 37, nos. 1–3 (2000): 67–111.
[Publisher page](https://www.sciencedirect.com/science/article/pii/S0167642399000234)

## Research question

Can the generic, compositional interface associated with monadic programming be
extended to computations that do not fit the monad interface?

## Contribution

Hughes introduces arrows as a more general abstraction for computations with
typed inputs and outputs. Arrows retain identity and composition, add an
operation that lifts pure functions, and support structured treatment of
additional inputs. The paper demonstrates the abstraction with parsers,
graphical interfaces, and active web pages.

## Finding

A common algebraic interface lets generic combinators and reasoning patterns be
reused across multiple implementation domains. The wider arrow interface covers
useful computations for which ordinary monadic structure is too restrictive.

## Relevance

An agent task naturally resembles a typed arrow from an input contract to an
output contract. The abstraction permits workflows to compose sequentially
without claiming that each task is a pure function, and it leaves room for
dataflow structures in which the computation is known before all inputs are.

The language need not expose Haskell-style arrow syntax. The relevant design
principle is a law-governed, typed composition interface for heterogeneous
agent components.

## Limits

Arrows are a programming abstraction, not an empirical agent architecture.
They do not by themselves represent goals, permissions, uncertainty, or
completion evidence, and their abstraction cost can exceed their benefit for
small workflows.

## Derived notes

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Categorical foundations for agent languages](../10-maps/categorical-foundations-for-agent-languages.md)
