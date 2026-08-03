---
title: "Phase 2 BEAM-Resident Compiler to BEAM Runtime Evidence"
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

# Phase 2 BEAM-Resident Compiler to BEAM Runtime Evidence

## Accepted pipeline

```text
counter.alang
  -> BEAM-resident lexer and parser
  -> deterministic, bounded canonical ETF round-trip
  -> BEAM-resident name and data checks
  -> validated alang_typed_task_ir_v1
  -> BEAM-resident reference/view comparison (test only)
  -> fail-closed counter-profile bridge
  -> Phase 1 typed semantic fixture
  -> OTP 29 Abstract Format validation and compile:forms/2
  -> inspected and manifested .beam artifact
  -> code:load_binary/3
  -> spawn phase1_counter_v1:start/1 on an isolated ERTS node
```

All source-to-fixture compiler stages are Erlang-bootstrap modules compiled to
`.beam` and invoked by `erl`. There is no Rust/Cargo toolchain or foreign
compiler executable. Erlang source defines compiler passes, but accepted
A-Lang is not translated to Erlang source and no Erlang evaluator executes its
AST or IR.

## Whole-toolchain BEAM residency

The compiler evidence record names the loaded file for these modules:

- `alang_phase2_lexer`
- `alang_phase2_parser`
- `alang_phase2_canonical`
- `alang_phase2_semantics`
- `alang_phase2_ir`
- `alang_phase2_reference`
- `alang_phase2_views`
- `alang_phase2_bridge`
- `alang_phase2_compiler`
- Phase 1 `alang_phase1_compiler`, `alang_phase1_fixture`, and
  `alang_phase1_package` backend modules
- OTP `compile` and `beam_lib` services

Every path ends in `.beam`; `engine` is `beam`, `vm` is `BEAM`, the OTP release
is `29`, `all_compiler_modules_are_beam` is `true`, and
`foreign_compiler_executables` is empty. EUnit also asserts that no Phase 2
Rust source, Cargo manifest, or repository Rust toolchain pin exists.

The reference module is included because it participates in differential
testing before bridge output. Its result is marked `deployable => false` and
`engine => beam_test_oracle`; it cannot satisfy the runtime gate.

## Frontend and semantic evidence

[`counter.alang`](fixtures/counter.alang) parses to an origin-bearing AST,
encodes with deterministic ETF, safely decodes with exact byte consumption,
and returns the identical AST. The compiler rejects trailing ETF bytes,
unsupported versions, unsafe or malformed terms, nonempty effect or
requirement lists, duplicate declarations, unresolved names, ill-typed
arithmetic or equality, result mismatch, and non-Boolean completion.

The deterministic malformed-input smoke test exercises every one-byte input
plus focused truncated and invalid programs. All return an ordinary compiler
result rather than crashing the BEAM compiler process.

## Typed IR and law evidence

The counter lowers to stable input, literal, addition, result, equality, and
verify nodes. Repeated lowering produces equal maps and the first node identity
is `node:task:Counter.successor/1:0000`. Structural validation rejects invalid
identities, dangling edges, and invalid task roots.

EUnit exhaustively checks left identity, right identity, and associativity for
three small pure transformations over integers `-32..32`. These checks execute
on ERTS and are deliberately described as bounded validation, not proof.

## Defined semantic equality

| Projection | Nondeployable BEAM oracle | Loaded generated BEAM module |
| --- | --- | --- |
| Input | binary-keyed value `41` | `{input, 41}` envelope payload |
| Result | integer `42` | `{ok, 42}` result message |
| Completion | verifier returns `true` | classification `ok`, exit `normal` |
| Effects | empty observation and manifest | no operation request |
| Order | typed body then verifier | received, transition, result, down |

The static trace skeleton is a compiler projection, not an ERTS event log. The
runtime trace is evidence about loading, scheduling, messaging, and process
termination.

## Reproduced artifact and observation

On OTP `29.0.4` and ERTS `17.0.4`, the compiler reported:

```text
engine=beam
canonical_encoding=deterministic_etf
canonical_sha256=0ac9fab3031c93311ae0e42f9f494c17797d2b05662443c281b2b6f7af781d28
ir_sha256=075a861db01759a6b2b99f456ae54677456537ce93036b7a66dfdbd95a16cc64
```

The Phase 1 artifact identity remained:

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

The successful production result occurred only after manifest verification,
BEAM inspection, `code:load_binary/3`, and spawning the generated module. The
observed function was `phase1_counter_v1:start/1`; the live stack and imports
contained no evaluator; scheduler tracing observed generated code; and the
process terminated normally.

The build ERTS node and runtime ERTS node are separate invocations. The first
creates products and exits. The second loads the validated program artifact.
The test oracle cannot load an A-Lang artifact, spawn the generated task, or
satisfy this gate.

## Reproduction

```console
make test
```

`make test-phase-2` runs the Phase 2 gate alone. Compiler products, `.beam`
files, manifests, reference data, and runtime traces remain under ignored
`build/` paths.

## Connections

- [Phase 2 implementation plan](../../60-planning/01-minimal-proof-of-concept/phase-02-native-frontend-and-typed-task-ir.md)
- [Typed task IR and semantic views](typed-task-ir.md)
- [Phase 1 BEAM execution evidence](../phase-01/beam-execution-evidence.md)
- [BEAM compiler-host research](../../20-notes/beam-runtime-for-native-agent-language.md)
