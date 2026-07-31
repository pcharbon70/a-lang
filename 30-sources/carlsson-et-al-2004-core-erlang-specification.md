---
title: "Core Erlang 1.0.3 language specification"
kind: source
created: 2026-07-31
authors:
  - "Richard Carlsson"
  - "Björn Gustavsson"
  - "Erik Johansson"
  - "Thomas Lindgren"
  - "Sven-Olof Nyström"
  - "Mikael Pettersson"
  - "Robert Virding"
published: 2004
citation_key: carlssonEtAl2004CoreErlang
container: "Uppsala University, Department of Information Technology"
edition: "Version 1.0.3"
isbn: null
doi: null
url: "https://www.it.uu.se/research/group/hipe/cerl/doc/core_erlang-1.0.3.pdf"
accessed: 2026-07-31
tags:
  - core-erlang
  - intermediate-representations
  - formal-semantics
  - beam
aliases:
  - "Core Erlang specification"
---

# Core Erlang 1.0.3 language specification

## Reference

Richard Carlsson, Björn Gustavsson, Erik Johansson, Thomas Lindgren, Sven-Olof
Nyström, Mikael Pettersson, and Robert Virding. *Core Erlang 1.0.3 Language
Specification*. Uppsala University, Department of Information Technology,
November 2004. [Specification](https://www.it.uu.se/research/group/hipe/cerl/doc/core_erlang-1.0.3.pdf)

See also the official [Core Erlang workshop page](https://erlang.org/workshop/2001/)
and OTP's [`cerl` module documentation](https://www.erlang.org/doc/apps/compiler/cerl.html).

## Contribution

Core Erlang is a compact functional language designed as a common intermediate
representation for Erlang implementations and tools. It makes evaluation,
bindings, pattern matching, function application, exceptions, binary
construction, and concurrent primitives explicit in a substantially smaller
language than full Erlang.

## Finding

The language is small enough to be a useful semantic reference for a new agent
language backend. Its explicit syntax can help define lowering passes and
cross-check compiler output without adopting Erlang syntax as the user-facing
language.

Core Erlang is not the same thing as the BEAM instruction set. It is a compiler
IR above BEAM. Its compact grammar therefore does not imply that current BEAM
opcodes or loader conventions form a small, stable public target.

## Relevance

A-Lang can borrow Core Erlang's philosophy: normalize a rich source language
into a small explicit calculus before backend-specific lowering. A Core-like
IR is also a plausible place to state categorical composition and effect laws.

## Limits

The specification describes the language, but the OTP compiler's `cerl` API is
documented as internal and not compatibility-guaranteed. OTP 29 additionally
warns that `primop` details may change at every major release and that foreign
Core shapes may reach untested compiler paths. The spec is therefore a semantic
resource, not sufficient evidence for choosing Core Erlang as the production
compiler ABI.

## Derived notes

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
- [BEAM runtime for agent languages](../10-maps/beam-runtime-for-agent-languages.md)
