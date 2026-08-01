---
title: "Phase 1 Typed Semantic Fixture"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - beam
  - compiler-ir
  - proof-of-concept
  - type-systems
aliases: []
---

# Phase 1 Typed Semantic Fixture

## Purpose

[`semantic-fixture.config`](semantic-fixture.config) is the language-owned
input to the Phase 1 compiler. It is a closed, versioned semantic data
structure. It is not Erlang source, an Erlang syntax tree, or a template that
accepts snippets of host-language code.

The build-only fixture module accepts exactly this structure. Unknown keys,
variants, operations, modules, entrypoints, limits, or type constructors are
rejected before lowering. Consequently, changing the fixture requires an
intentional compiler change rather than silently widening the language.

## Closed types

The fixture declares these types:

- input is an integer in the inclusive range `0..1000000`;
- state is the closed sum `waiting | completed`;
- a successful result contains the successor integer;
- an error result contains one of the eight failures fixed by the runtime
  contract; and
- correlation and envelope byte limits are part of the program's ABI.

No string is interpreted as a module, function, atom, expression, or runtime
operation. Every atom in the fixture is compiler-owned.

## Transition

The one transition binds an input value, changes state from `waiting` to
`completed`, and defines the result as integer addition by the literal `1`.
The lowering pass turns this declaration into the allowlisted Abstract Format
addition expression. The build tool never calculates an input's successor;
that calculation occurs only in the generated BEAM process.

## Closed runtime operations

The operation list is exact and ordered:

1. `initialize`;
2. `receive_envelope`;
3. `emit_trace`;
4. `reply_result`; and
5. `terminate`.

These names select fixed compiler obligations. They cannot be supplied by a
runtime message and do not become dynamic module or function calls.

## Deterministic lowering

[`alang_phase1_fixture.erl`](alang_phase1_fixture.erl) validates the complete
fixture and constructs stable Erlang Abstract Format terms with fixed integer
source annotations. Identical fixture bytes and the pinned toolchain therefore
produce identical normalized forms. The general compiler boundary performs a
second closed-subset validation before OTP strong validation and emission.

## Connections

- [Runtime contract](runtime-contract.md)
- [Abstract Format subset](abstract-format-subset.md)
- [Phase 1 implementation plan](../../60-planning/01-minimal-proof-of-concept/phase-01-beam-executable-vertical-slice.md)
