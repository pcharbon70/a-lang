---
title: "Erlang/OTP compiler guidance for language implementors"
kind: source
created: 2026-07-31
authors:
  - "Erlang/OTP"
published: 2026
citation_key: erlangOtp2026LanguageImplementors
container: "Erlang/OTP 29 documentation"
edition: "OTP 29"
isbn: null
doi: null
url: "https://www.erlang.org/doc/apps/compiler/compile.html"
accessed: 2026-07-31
tags:
  - beam
  - compiler-backends
  - erlang-abstract-format
  - language-implementation
aliases:
  - "OTP 29 language implementor guidance"
---

# Erlang/OTP compiler guidance for language implementors

## Reference

Erlang/OTP. “Compiler (`compile`)” and “The Abstract Format.” *Erlang/OTP 29
documentation*, 2026.

- [Compiler documentation](https://www.erlang.org/doc/apps/compiler/compile.html)
- [Erlang Abstract Format](https://www.erlang.org/doc/apps/erts/absform.html)

## Contribution

OTP 29 documents four ways for another language to use the Erlang compiler:
generate Erlang source, Erlang Abstract Format, Core Erlang, or BEAM assembly.
It then makes an unusually explicit recommendation: language implementors
should prefer source or Abstract Format.

`compile:forms/2` accepts Abstract Format terms directly. Its options include
`binary`, `deterministic`, `basic_validation`, `strong_validation`, custom
compiler information, debug-information backends, and additional BEAM chunks.
The validation modes check compiler input without emitting executable code.

## Finding

Abstract Format is the most suitable supported boundary for the new A-Lang
compiler. The BEAM-resident compiler can construct forms in memory and call
OTP services on ERTS. This avoids generating an Erlang text program while
retaining the OTP compiler's supported validation, optimization, BEAM emission,
and compatibility work.

The same documentation cautions that direct Core Erlang can create forms the
normal compiler pipeline never produces. Core `primop` details may change at a
major release. BEAM assembly is discouraged more strongly: instruction and
calling-convention changes can make generated code unsafe and can crash the VM.

## Relevance

This source changes the backend recommendation. A small Core-like agent IR is
still useful, but the production adapter should lower that IR to versioned
Abstract Format and let the OTP compiler emit `.beam` files. That is compilation
to BEAM, not interpretation by Erlang, Elixir, Gleam, or another surface
language.

Source annotations can preserve mappings back to the agent language. Custom
chunks and debug backends can carry an IR digest, capability manifest, source
map, compiler identity, and provenance metadata.

## Limits

Abstract Format remains coupled to an OTP release and exposes Erlang's runtime
value and module conventions. It is a supported compiler interface, not a
promise that every term shape will behave identically forever. A language
implementation still needs a pinned build toolchain, a compatibility matrix,
and tests on each deployment OTP.

## Derived notes

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
- [BEAM runtime for agent languages](../10-maps/beam-runtime-for-agent-languages.md)
- [Can BEAM support a native agent language safely?](../40-inquiries/can-beam-support-a-native-agent-language.md)
