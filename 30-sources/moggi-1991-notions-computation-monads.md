---
title: "Notions of Computation and Monads"
kind: source
created: 2026-07-31
authors:
  - "Eugenio Moggi"
published: 1991
citation_key: moggi1991Notions
container: "Information and Computation 93(1), 55–92"
doi: "10.1016/0890-5401(91)90052-4"
url: "https://person.dibris.unige.it/moggi-eugenio/ftp/ic91.pdf"
accessed: 2026-07-31
tags:
  - programming-language-semantics
  - monads
  - computational-effects
aliases: []
---

# Notions of Computation and Monads

## Reference

Eugenio Moggi. “Notions of Computation and Monads.” *Information and
Computation* 93, no. 1 (1991): 55–92.
[Author-hosted paper](https://person.dibris.unige.it/moggi-eugenio/ftp/ic91.pdf)

## Research question

How can programming-language semantics distinguish pure values from
computations that may diverge, branch, change state, raise exceptions, perform
I/O, or otherwise exhibit effects?

## Contribution

Moggi models a value type as an object `A` and a computation returning such a
value as `T A`, where `T` is a suitable monad. Programs with effects compose in
the corresponding Kleisli category. The paper gives examples over sets for
partiality, finite nondeterminism, state, exceptions, continuations, and
interactive input or output.

This separates ordinary total functions from effectful computations while
retaining identity and associative composition laws for programs.

## Finding

The formal result is that a broad family of computational effects can be given
a uniform categorical semantics and associated calculi for reasoning about
program equivalence. Treating every program as a total function between sets
would erase behavior essential to real computation.

## Relevance

`Set` is a useful base for an agent language's data types, but it is not an
adequate category of agent actions. Tool calls may fail, change persistent
state, consume resources, branch nondeterministically, and interact with an
environment. A monadic or effect-oriented layer can make those distinctions
part of the type and composition rules.

## Limits

Monadic semantics does not decide which effects an agent should be permitted to
perform, whether a tool's implementation is honest, or whether a generated
task denotes the user's intent. Combining many effects can also create a
difficult language and implementation problem.

## Derived notes

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Categorical foundations for agent languages](../10-maps/categorical-foundations-for-agent-languages.md)
