---
title: "Phase 1 BEAM Execution Evidence"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - beam
  - integration-testing
  - proof-of-concept
  - runtime-systems
aliases: []
---

# Phase 1 BEAM Execution Evidence

## Outcome

Phase 1 passes its executable gate on the pinned OTP 29.0.4 and ERTS 17.0.4
toolchain. The fixed A-Lang semantic fixture produces a manifest-verified
`.beam`, and that artifact produces the canonical result from
`phase1_counter_v1:start/1` inside a spawned process on a fresh named ERTS
node.

The build and test tools are Erlang bootstrap components. They validate,
lower, load, and observe the artifact; they do not interpret the fixture or
calculate the successor result. The generated module imports only the closed
`erlang` allowlist and never calls a compiler, fixture, package, harness,
`erl_eval`, Elixir, Gleam, or another interpreter module.

## Clean reproduction

From a clean checkout with `asdf` available, run:

```sh
make test-phase-1
```

The project-local [`.tool-versions`](../../.tool-versions) selects Erlang/OTP
29.0.4. The command rejects a different OTP, ERTS, or architecture before
compilation; runs the compiler, fixture, package, and integration suites;
launches the integration suite on a fresh named node; then launches a second
fresh node to reproduce the canonical execution and write its evidence under
the ignored `build/phase-01/evidence/` directory.

The runtime demonstration uses `erl -noshell -sname ... -s
alang_phase1_runtime main`. It does not use `-eval`, an Erlang source file, or
an A-Lang evaluator on the runtime path.

## Artifact identity

For the committed fixture, toolchain, and compiler boundary, the reproducible
identities are:

| Item | SHA-256 |
| --- | --- |
| `phase1_counter_v1.beam` | `39d4df7f6fb5d5afb071aecf62899dcd73380701131f7ca596349615734123b9` |
| deterministic ETF manifest | `5605c96111ca04ad522dbf8c90eb1b251843cf044f024247b57a0f27fef25654` |

The manifest records the fixture and normalized-form digests, semantic
version, runtime ABI, exact OTP target, compiler options, imports, exports,
and BEAM digest. Verification reconstructs that expected manifest from the
trusted fixture, config, and inspected BEAM before safely decoding and
comparing the sidecar.

## Canonical normalized trace

The observed normalized trace is exactly:

```text
loaded phase1_counter_v1
spawned phase1_counter_v1:start/1
trace phase-1-success received
trace phase-1-success waiting -> completed
result phase-1-success ok 42
down normal
```

The unnormalized ETF evidence additionally contains the actual named node,
OS PID, harness PID, generated PID, scheduler count, scheduler in/out events,
node reduction counters before and after execution, process state before the
message, loaded filename, toolchain values, imports, artifact digests, and
the no-interpreter inspection result.

## Execution topology and no-interpreter gate

The executable path is:

```text
verified semantic fixture + manifest + BEAM inspection
    -> code:load_binary/3
        -> spawn phase1_counter_v1:start/1
            -> receive closed alang_v1 envelope
            -> generated BEAM addition
            -> trace and result messages
            -> monitored normal exit
```

The harness records `phase1_counter_v1:start/1` as the spawned process's
current function before dispatch. ERTS running-process trace events establish
scheduler-visible execution. The process is unlinked from the harness,
terminates after one envelope, and is confirmed dead after every test.

The gate fails unless all of the following hold:

- the package verifier succeeds before `code:load_binary/3`;
- the loaded filename is the verified `.beam` path;
- the generated process is executing `phase1_counter_v1:start/1`;
- scheduler tracing observes that function running;
- inspected imports remain inside the compiler's fixed allowlist;
- generated stack and import modules contain no known interpreter module;
- the expected ABI messages arrive in order; and
- the process monitor reports the expected terminal reason.

## Fail-closed matrix

The named-node integration suite covers:

| Boundary | Expected observation |
| --- | --- |
| unknown ABI | typed `unsupported_abi` result, normal exit |
| invalid payload | typed `invalid_payload` result, normal exit |
| oversized envelope | typed `payload_too_large` result, normal exit |
| unavailable operation | typed `unavailable_operation` result, normal exit |
| invalid correlation | monitored `invalid_correlation` rejection |
| invalid reply target | monitored `invalid_reply_target` rejection |
| malformed envelope | monitored `malformed_envelope` rejection |
| killed generated process | `unexpected_process_exit` classification |
| changed manifest bytes | rejected before load |
| forbidden BEAM import | rejected by BEAM inspection before load |
| unsupported Abstract Format | rejected before OTP emission |
| changed OTP target | rejected before load |

No rejection produces a successful result, and no generated process remains
alive after a case completes.

## Evidence implementation

- [`alang_phase1_runtime.erl`](alang_phase1_runtime.erl) performs verification,
  loading, spawning, messaging, scheduler tracing, monitoring, evidence
  capture, normalization, and the no-interpreter inspection.
- [`alang_phase1_integration_tests.erl`](alang_phase1_integration_tests.erl)
  asserts the canonical trace, failure matrix, artifact boundaries, isolated
  node, process termination, and no-interpreter gate.
- The repository [`Makefile`](../../Makefile) supplies the one-command clean
  reproduction and the source-free runtime invocation.

## Connections

- [Runtime contract](runtime-contract.md)
- [Typed semantic fixture](semantic-fixture.md)
- [Phase 1 implementation plan](../../60-planning/01-minimal-proof-of-concept/phase-01-beam-executable-vertical-slice.md)
