---
title: "Phase 3 Erlang Abstract Format Contract"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - beam
  - compiler-backend
  - erlang-abstract-format
aliases: []
---

# Phase 3 Erlang Abstract Format Contract

## Boundary

The A-Lang compiler constructs Erlang Abstract Format terms in a BEAM process
and passes them directly to OTP 29 `compile:forms/2`. It never generates Erlang
source, Core Erlang, BEAM assembly, or a `.beam` container by hand.

The generated module name, exported entrypoint, helper-function atoms,
variables, attributes, runtime module, and runtime function names come from
finite compiler-owned tables. A-Lang identifiers remain binaries and cannot
create VM atoms.

## Allowed forms

The backend validator admits only module and metadata attributes, functions,
clauses, variables, bounded literals and lists, tuples, maps with fixed keys,
local and approved remote calls, `case`, bounded `receive` with timeout,
matches, and approved operators. It rejects fun expressions, dynamic apply,
comprehensions, record expansion, arbitrary remote modules, generated source,
Core forms, and raw BEAM instructions.

The only generated runtime import is
`alang_phase3_abi:request_effect/5`. Approved pure BIFs are enumerated by
`alang_phase3_contract:allowed_runtime_calls/0`; the list does not contain
`apply`, port operations, NIF loading, unsafe term decoding, atom construction,
or filesystem and network calls.

Compiler-owned local callables return raw A-Lang values so typed `apply` nodes
compose normally. Only the exported `execute/3` dispatcher evaluates the
selected task's completion predicate and wraps its final value or verifier
failure in the runtime result domain.

## Bounds

- at most 16 callables and 256 IR nodes per module;
- at most 16 parameters, arguments, or product fields;
- at most 16 compiler-owned sequence temporaries;
- source identities no longer than 256 bytes;
- binary values no larger than 65,536 bytes;
- signed 64-bit integer literals; and
- compiler-generated variable and function identities selected from finite
  tables.

## Diagnostics

Backend errors use
`{alang_compile_error_v1, Code, NodeId, {source, Byte, Line, Column}}`.
Unsupported nodes, dangling references, invalid types, illegal identities,
unresolved calls, unavailable compiler atoms, disallowed forms, OTP validation
errors, and warnings all fail the build. The [artifact and loading
contract](artifact-contract.md) adds exact OTP, metadata, import, and code
lifecycle evidence without weakening this contract.

## Connections

- [Backend representation contract](backend-representation-contract.md)
- [OTP 29 language implementor guidance](../../30-sources/erlang-otp-2026-language-implementors.md)
- [Phase 1 Abstract Format subset](../phase-01/abstract-format-subset.md)
