---
title: "BEAM instructions, loading, JIT execution, and compatibility"
kind: source
created: 2026-07-31
authors:
  - "Erlang/OTP"
published: 2026
citation_key: erlangOtp2026BeamExecution
container: "Erlang/OTP 29 source and documentation"
edition: "OTP 29"
isbn: null
doi: null
url: "https://github.com/erlang/otp/blob/OTP-29.0/lib/compiler/src/genop.tab"
accessed: 2026-07-31
tags:
  - beam
  - virtual-machines
  - jit
  - code-loading
aliases:
  - "BEAM execution model"
---

# BEAM instructions, loading, JIT execution, and compatibility

## Reference

Erlang/OTP. BEAM opcode table and ERTS/compiler documentation, OTP 29.

- [OTP 29 opcode table](https://github.com/erlang/otp/blob/OTP-29.0/lib/compiler/src/genop.tab)
- [`beam_makeops` internal documentation](https://www.erlang.org/doc/apps/erts/beam_makeops.html)
- [A first look at the JIT](https://www.erlang.org/blog/a-first-look-at-the-jit/)
- [The BEAM compiler history](https://www.erlang.org/blog/beam-compiler-history/)
- [Code loading](https://www.erlang.org/doc/system/code_loading.html)
- [`beam_lib` module](https://www.erlang.org/doc/apps/stdlib/beam_lib.html)

## Contribution

These materials document the moving boundary between compiler output, the BEAM
loader, and the BeamAsm JIT. On supported architectures, BeamAsm translates
loaded BEAM code to native machine code while preserving BEAM semantics.
`.beam` modules also carry named chunks for code, attributes, compile data,
debug information, and optional application-specific metadata.

OTP supports a current and an old version of a module. A process changes to the
current version through a qualified call; loading another version can require
purging the oldest code and can terminate processes that still execute it.

## Finding

The VM instruction interface is not particularly small or stable. A mechanical
count of OTP 29's `genop.tab` finds 191 numbered entries: 132 active and 59
marked obsolete. The table also participates in instruction transformations,
so this count should be read as a property of that release's source table, not
as a timeless architectural instruction count.

The supported compiler path can still produce code that runs directly under
ERTS and BeamAsm. No Erlang-language interpreter loop is involved after module
loading.

## Relevance

BEAM is a viable execution target even when the language is not Erlang-like.
The agent language can embed source maps, IR and source hashes, effect and
capability manifests, and compiler provenance in custom chunks. Hot code
loading may help long-running agents, provided language semantics explicitly
govern state migration and version pinning.

## Limits

`beam_makeops`, opcode tables, file layout details, and loader conventions are
implementation internals. Direct emission shifts verification and safety
responsibility onto the new compiler. Hot loading supplies code-version
mechanics, not automatic state-schema migration or semantic compatibility.

## Derived notes

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
- [BEAM runtime for agent languages](../10-maps/beam-runtime-for-agent-languages.md)
