---
title: "Handling Algebraic Effects"
kind: source
created: 2026-07-31
authors:
  - "Gordon D. Plotkin"
  - "Matija Pretnar"
published: 2013
citation_key: plotkin2013HandlingEffects
container: "Logical Methods in Computer Science 9(4:23)"
doi: "10.2168/LMCS-9(4:23)2013"
url: "https://lmcs.episciences.org/705"
accessed: 2026-07-31
tags:
  - algebraic-effects
  - effect-handlers
  - programming-language-semantics
aliases: []
---

# Handling Algebraic Effects

## Reference

Gordon D. Plotkin and Matija Pretnar. “Handling Algebraic Effects.” *Logical
Methods in Computer Science* 9, no. 4:23 (2013): 1–36.
[Open paper](https://lmcs.episciences.org/705)

## Contribution

The paper represents computational effects through operations and equational
laws, then gives a general account of handlers. Effects include exceptions,
state, nondeterminism, interactive I/O, and time. A computation either returns
a value or performs an operation whose outcome selects a continuation.

Handlers interpret effect operations into a chosen model. This unifies
constructs such as exception handling, timeout, rollback, relabeling, and stream
redirection under one semantic account.

## Finding

Algebraic effects provide a modular separation between requesting an operation
and deciding how that operation is handled. Equational presentations also
support reasoning about operations independently of one concrete runtime.

## Relevance

An agent DSL can expose operations such as `search`, `write`, `ask`, `spend`,
or `delegate` without granting their implementation directly. Runtime handlers
can enforce capabilities, sandbox writes, log provenance, simulate actions,
require approval, or substitute test doubles while the workflow remains the
same.

This is a stronger architecture than treating permissions as natural-language
advice embedded in a prompt.

## Limits

Not every effect has a simple algebraic presentation, and irreversible
real-world actions still need transactional boundaries, idempotency controls,
and domain-specific safety checks. Effect handlers organize enforcement; they
do not make unsafe operations safe automatically.

## Derived notes

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Can categorical semantics materially improve an agent language?](../40-inquiries/can-categorical-semantics-improve-agent-language.md)
