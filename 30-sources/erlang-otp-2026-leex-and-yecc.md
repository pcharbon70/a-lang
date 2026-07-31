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

If the project interprets “no Erlang as the main interpreter” narrowly, a
Leex/Yecc reference frontend remains compatible: it is a build-time compiler
component, not a runtime interpreter for agent programs. If the stronger goal
is a fully native, self-contained frontend with no existing BEAM language at
its implementation boundary, use a handwritten or host-language parser and
retain Leex/Yecc only as a differential oracle during bootstrapping.

The declarative grammar files are still valuable test assets. The same token
and parse corpora can be run against both frontends to detect divergence.

## Limits

Leex and Yecc do not provide incremental parsing, generalized ambiguity
handling, error recovery suited to every interactive language, or a security
boundary. Choosing them solely because the target VM is BEAM conflates the
compiler's host language with the program's execution target.

## Derived notes

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
- [Can BEAM support a native agent language safely?](../40-inquiries/can-beam-support-a-native-agent-language.md)
