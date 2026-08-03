---
title: "Leex and Yecc parser tools"
kind: source
created: 2026-07-31
authors:
  - "Erlang/OTP"
published: 2026
citation_key: erlangOtp2026LeexYecc
container: "Erlang/OTP 29 documentation"
edition: "OTP 29"
isbn: null
doi: null
url: "https://www.erlang.org/doc/apps/parsetools/leex.html"
accessed: 2026-07-31
tags:
  - parser-generators
  - lexer-generators
  - beam
  - compiler-frontends
aliases:
  - "Erlang parser tools"
---

# Leex and Yecc parser tools

## Reference

Erlang/OTP. *Leex* and *Yecc*, Parse Tools documentation, OTP 29.

- [Leex](https://www.erlang.org/doc/apps/parsetools/leex.html)
- [Yecc](https://www.erlang.org/doc/apps/parsetools/yecc.html)

## Contribution

Leex is a regular-expression lexical-analyzer generator. Yecc is an LALR-1
parser generator. Both are mature OTP tools, and both generate Erlang source
modules from declarative scanner or grammar specifications.

## Finding

These tools can bootstrap a reference parser that runs on BEAM, but they are
not language-neutral lexer or parser facilities embedded in the VM. Their
generated artifact is Erlang source and is then compiled normally.

## Relevance

The project now requires the compiler toolchain itself to run on BEAM. A
Leex/Yecc frontend is compatible because its generated module executes on ERTS
as a compiler pass, not as an interpreter for agent programs. A handwritten
Erlang-bootstrap parser is equally compatible. A foreign host-language parser
is not: it would move a trusted compiler pass outside the whole-toolchain BEAM
boundary. Leex/Yecc can still serve as a differential oracle during
bootstrapping.

The declarative grammar files are still valuable test assets. The same token
and parse corpora can be run against both frontends to detect divergence.

## Limits

Leex and Yecc do not provide incremental parsing, generalized ambiguity
handling, error recovery suited to every interactive language, or a security
boundary. Their use must be justified by grammar and diagnostics needs; the
whole-toolchain decision already establishes ERTS as both compiler host and
program execution target.

## Derived notes

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
- [Can BEAM support a native agent language safely?](../40-inquiries/can-beam-support-a-native-agent-language.md)
