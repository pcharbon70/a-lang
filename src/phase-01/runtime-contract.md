---
title: "Phase 1 BEAM Runtime Contract"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - beam
  - proof-of-concept
  - runtime-abi
  - runtime-systems
aliases:
  - "A-Lang Phase 1 execution contract"
---

# Phase 1 BEAM Runtime Contract

## Normative language and scope

The words **must**, **must not**, **required**, **may**, and **may not** are
normative in this document. This contract governs only the first A-Lang
vertical slice. Later phases may add operations or types by versioning the
language and runtime ABI; they may not weaken the execution-engine invariant.

## Execution-engine invariant

An accepted Phase 1 A-Lang program must:

1. exist as a validated `.beam` artifact emitted by the pinned OTP compiler;
2. be loaded into ERTS through the normal BEAM loader;
3. execute its state transition inside a spawned BEAM process;
4. receive input and emit traces and results through the closed ABI below;
5. consume BEAM reductions and terminate with an observable ERTS exit reason;
6. reach no host filesystem, network, model, tool, or arbitrary module call;
   and
7. produce its result without an AST evaluator, IR evaluator, source evaluator,
   shell computation, or another language runtime.

Compilation to BEAM is not sufficient evidence by itself. The integration
gate must identify the loaded module and spawned PID, observe scheduler-visible
execution, collect the ABI messages, and receive the process monitor result.

## Bootstrap boundary

The following components are allowed before the artifact is loaded:

- a fixture decoder that accepts only the versioned Phase 1 semantic fixture;
- a validator for its closed types and named runtime operations;
- a lowering pass that constructs only the documented Erlang Abstract Format
  subset;
- an OTP compiler service using validation and deterministic binary emission;
- artifact, import, metadata, and digest inspection;
- a fixture generator or test oracle that cannot be selected by the runtime
  command; and
- a harness that loads, spawns, messages, monitors, and observes the artifact.

Bootstrap components must not:

- calculate the fixture's successor state or result as an execution fallback;
- dispatch an A-Lang operation from source or IR after artifact acceptance;
- invoke `erl_eval`, compile generated Erlang source, generate Core Erlang, or
  emit raw BEAM assembly;
- remain callable from generated code as a general evaluator;
- replace a failed BEAM execution with a fixture-derived success value; or
- count a mock, simulation, trace skeleton, or lowered form as runtime
  completion evidence.

## First observable program

The first program is `phase1_counter_v1`. Its semantic state is the closed sum
`waiting | completed`. It accepts one integer input while waiting, performs the
single transition `waiting -> completed`, and returns the input plus one. It
has no external effect, model call, tool call, retry, recursion, or additional
message loop.

The generated module exports only `start/1`. The harness passes its own PID to
`start/1`; generated code then waits for exactly one input envelope, emits the
defined trace and result messages to that PID, and terminates.

## Runtime ABI version 1

All tags below are fixed compiler-known atoms. Correlation identifiers and
user values are binaries or integers; untrusted input must never create atoms.
The maximum accepted encoded envelope size is 1,024 bytes.

### Input envelope

```erlang
{alang_v1, run, Correlation, ReplyTo, {input, Value}}
```

- `Correlation` is a non-empty binary of at most 64 bytes.
- `ReplyTo` is a local PID supplied by the harness.
- `Value` is an integer in the inclusive range `0..1000000`.

### Trace events

```erlang
{alang_v1, trace, Correlation, received}
{alang_v1, trace, Correlation, {transition, waiting, completed}}
```

### Successful result

```erlang
{alang_v1, result, Correlation, {ok, Successor}}
```

`Successor` must equal `Value + 1` and must be calculated by the generated BEAM
module during its process execution.

### Rejected result

```erlang
{alang_v1, result, Correlation, {error, Failure}}
```

The closed Phase 1 failures are:

```text
malformed_envelope
unsupported_abi
invalid_correlation
invalid_reply_target
invalid_payload
payload_too_large
unavailable_operation
unexpected_process_exit
```

When a trustworthy reply PID and correlation identifier can be recovered, the
generated process returns a typed rejection and terminates normally. Otherwise
the harness classifies the rejection from the monitored process outcome and
must not synthesize a successful result.

## Canonical successful observation

The canonical input uses correlation `<<"phase-1-success">>` and value `41`.
The normalized observation, excluding nondeterministic PID and reduction
counts, is exactly:

```text
loaded phase1_counter_v1
spawned phase1_counter_v1:start/1
trace phase-1-success received
trace phase-1-success waiting -> completed
result phase-1-success ok 42
down normal
```

The evidence bundle additionally records the actual PID, node, OTP version,
ERTS version, scheduler count, reductions before and after the process, module
digest, and manifest digest.

## Canonical failure observations

The integration suite must exercise and classify:

| Case | Required classification | Required side effect |
| --- | --- | --- |
| tuple or tag does not match the ABI | `malformed_envelope` | none |
| envelope uses `alang_v2` | `unsupported_abi` | none |
| correlation is empty or over 64 bytes | `invalid_correlation` | none |
| reply target is not a local PID | `invalid_reply_target` | none |
| input is not an integer in range | `invalid_payload` | none |
| encoded envelope exceeds 1,024 bytes | `payload_too_large` | none |
| payload requests any runtime operation | `unavailable_operation` | none |
| process exits before its typed result | `unexpected_process_exit` | none |

Every rejection must be bounded, leave no generated process running, and
produce no successful trace or result for the rejected correlation.

## Runtime operations

The semantic fixture may name only these operations, in this order:

1. `initialize`;
2. `receive_envelope`;
3. `emit_trace`;
4. `reply_result`; and
5. `terminate`.

These names describe compiler obligations. They are not dynamic module or
function names and cannot be selected by the input envelope.

## Acceptance evidence

Section 1.1 is satisfied when this contract is indexed, linked from the phase
plan, and reviewed together with the BEAM runtime research. Executable claims
remain subject to Sections 1.2 through 1.4 and must not be marked complete from
this document alone.

## Connections

- [Phase 1 implementation plan](../../60-planning/01-minimal-proof-of-concept/phase-01-beam-executable-vertical-slice.md)
- [BEAM runtime synthesis](../../20-notes/beam-runtime-for-native-agent-language.md)
- [OTP language-implementor guidance](../../30-sources/erlang-otp-2026-language-implementors.md)
