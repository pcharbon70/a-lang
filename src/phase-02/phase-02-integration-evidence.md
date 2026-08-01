---
title: "Phase 2 Native Frontend to BEAM Integration Evidence"
kind: note
created: 2026-07-31
maturity: stable
tags:
  - beam
  - compiler-testing
  - proof-of-concept
  - runtime-systems
aliases:
  - "Phase 2 completion evidence"
---

# Phase 2 Native Frontend to BEAM Integration Evidence

## Accepted pipeline

The completed Phase 2 path is:

```text
counter.alang
  -> native Rust lexer/parser
  -> resolution, data typing, effects, requirements
  -> validated alang-task-ir-v1
  -> closed counter-profile bridge
  -> Phase 1 typed semantic fixture
  -> OTP 29 Abstract Format validation and compile:forms/2
  -> inspected, manifested .beam artifact
  -> code:load_binary/3
  -> spawn phase1_counter_v1:start/1 on an isolated ERTS node
```

The native compiler emits the origin-preserving canonical JSON partner,
validated IR, semantic views, reference outcome, bridge manifest, Phase 1
fixture, and a small agreement record under `build/phase-02/frontend/`. The
bridge fixture is byte-for-byte equal to the Phase 1 fixture already covered by
the Abstract Format and artifact suites.

The bridge is deliberately fail closed. Phase 2 promotes `constant`, `input`,
`add`, `equal`, and `verify` into the current runtime counter profile, and all
nine instances in the demo graph receive an explicit lowering entry. Any
additional callable, node, effect, requirement, signature, or verifier shape is
rejected before fixture output. The other typed IR primitives are complete
semantic/test-view commitments whose generalized BEAM lowering remains Phase 3
work.

## Frontend and semantic agreement

The paired-fixture suite parses [`counter.alang`](fixtures/counter.alang),
serializes its origin-bearing AST into canonical JSON, decodes that JSON through
the independent bounded frontend, and asserts equality after every subsequent
judgment. Both paths produce byte-identical canonical serialized IR.

Focused accepted tests cover all 14 typed IR primitives, records and products,
structural results, functions, tasks, lexical binding, exhaustive matches,
effects, normalized requirements, and verifiers. Negative tests reject malformed
syntax, incomplete canonical result matches, unknown names, type mismatches,
annotation drift, missing requirements, recursion, opaque-boundary violations,
invalid IR, and bridge-profile drift with stable codes before backend work.

The deterministic fuzz-smoke suite performs 256 reproducible mutations against
each frontend. Every input returns the same accepted AST or ordered diagnostic
set on two runs, and neither frontend panics.

## Defined semantic equality

The test evaluator and production runtime have intentionally different trace
vocabularies, so the comparison uses a documented semantic projection rather
than byte equality:

| Projection | Test-only view | Loaded BEAM observation |
| --- | --- | --- |
| Input | integer `41` | `{input, 41}` envelope payload |
| Result | integer `42` | `{ok, 42}` result message |
| Completion | verifier is `true` | classification `ok` and exit `normal` |
| Effects | empty reference observations and manifest | no operation request |
| Order | typed graph requires input, add, verify | received, transition, result, down |

The static trace skeleton covers every IR node but is not presented as an ERTS
event log. The runtime trace is evidence about scheduling, messaging, loading,
and termination. The table above is the equality relation between their shared
semantic claims.

## Reproduced artifact and observation

On the pinned local toolchain—OTP `29.0.4`, ERTS `17.0.4`, and Rust `1.92.0`—the
clean Phase 2 artifact reported:

```text
module=phase1_counter_v1
beam_sha256=39d4df7f6fb5d5afb071aecf62899dcd73380701131f7ca596349615734123b9
manifest_sha256=5605c96111ca04ad522dbf8c90eb1b251843cf044f024247b57a0f27fef25654
```

The isolated runtime produced:

```text
loaded phase1_counter_v1
spawned phase1_counter_v1:start/1
trace phase-1-success received
trace phase-1-success waiting -> completed
result phase-1-success ok 42
down normal
phase_2_agreement_ok reference_result=42 beam_result=42 no_interpreter=true
```

## No-interpreter evidence

The only successful production result above came after manifest verification,
BEAM inspection, `code:load_binary/3`, and spawning the generated module. The
observed current function was `phase1_counter_v1:start/1`; generated imports and
the live stack contained none of `erl_eval`, Elixir, or Gleam; scheduler events
showed the generated function running; and the process terminated normally.

The Rust reference evaluator is marked nondeployable in code and outcome data,
has only bounded fixture inputs, and is absent from the ERTS command. It writes
comparison data before artifact compilation but cannot load a module, spawn an
A-Lang process, or satisfy this gate.

## Reproduction

From a clean checkout with the pinned toolchains available:

```console
make test
```

`make test-phase-2` may be used for the Phase 2-only gate. Generated compiler
outputs, artifact manifests, BEAM files, reference data, normalized runtime
traces, and EUnit evidence remain under the ignored `build/` directory.

## Connections

- [Phase 2 implementation plan](../../60-planning/01-minimal-proof-of-concept/phase-02-native-frontend-and-typed-task-ir.md)
- [Typed task IR and semantic views](typed-task-ir.md)
- [Phase 1 BEAM execution evidence](../phase-01/beam-execution-evidence.md)
