---
title: "Phase 1: BEAM-Executable Vertical Slice"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - beam
  - compiler-design
  - implementation-planning
  - proof-of-concept
aliases: []
---

# Phase 1: BEAM-Executable Vertical Slice

**Description:** This phase proves the non-negotiable runtime architecture
before building a general frontend. A fixed, minimal A-Lang semantic fixture is
lowered to Erlang Abstract Format, compiled by a pinned OTP compiler, loaded by
ERTS, spawned as a BEAM process, driven through a closed message ABI, and
observed through normal BEAM termination and trace events.

**Status:** Planned.

**Dependencies:** The BEAM runtime synthesis and feasibility inquiry are the
accepted baseline. No compiler, evaluator, broker, or other host runtime may be
treated as the A-Lang execution engine.

## Section 1.1: Non-Negotiable BEAM Execution Contract

**Description:** Freeze the boundary that distinguishes a language running on
BEAM from a language merely using BEAM as a late export format.

- [x] **Section 1.1 Complete** — evidence: [normative runtime contract](../../src/phase-01/runtime-contract.md)

### Task 1.1.1: Publish the Runtime Invariants

**Description:** Record the architectural statements that every later phase
must preserve and that reviewers can test directly.

- [x] **Task 1.1.1 Complete** — evidence: [execution-engine and bootstrap invariants](../../src/phase-01/runtime-contract.md#execution-engine-invariant)

#### Subtask 1.1.1.1: Define the Execution Engine

**Description:** State that production A-Lang programs execute only as loaded
BEAM modules and ERTS processes, use BEAM scheduling and process isolation, and
do not execute through a host-language AST or IR interpreter.

- [x] **Subtask 1.1.1.1 Complete** — evidence: [execution-engine invariant](../../src/phase-01/runtime-contract.md#execution-engine-invariant)

#### Subtask 1.1.1.2: Define Permitted Bootstrap Components

**Description:** Allow a build-time encoder, OTP compiler service, test oracle,
or fixture generator only when it cannot execute an A-Lang task and is not
present on the runtime path after a `.beam` artifact is accepted.

- [x] **Subtask 1.1.1.2 Complete** — evidence: [bootstrap boundary](../../src/phase-01/runtime-contract.md#bootstrap-boundary)

### Task 1.1.2: Freeze the First Observable Program

**Description:** Specify one tiny program whose execution proves module
loading, process creation, message receipt, typed result emission, and normal
or classified abnormal termination on ERTS.

- [x] **Task 1.1.2 Complete** — evidence: [first observable program](../../src/phase-01/runtime-contract.md#first-observable-program)

#### Subtask 1.1.2.1: Define the Successful Trace

**Description:** Fix the input envelope, process identity observation, state
transition, output envelope, trace event order, and terminal result expected
from the first BEAM-executed program.

- [x] **Subtask 1.1.2.1 Complete** — evidence: [canonical successful observation](../../src/phase-01/runtime-contract.md#canonical-successful-observation)

#### Subtask 1.1.2.2: Define the Failure Trace

**Description:** Fix deterministic rejection cases for a malformed envelope,
unknown ABI version, invalid payload shape, unavailable runtime operation, and
unexpected process exit.

- [x] **Subtask 1.1.2.2 Complete** — evidence: [canonical failure observations](../../src/phase-01/runtime-contract.md#canonical-failure-observations)

## Section 1.2: Pinned OTP Compilation Boundary

**Description:** Establish the supported path from the language-owned fixture
to validated BEAM without making Core Erlang or raw BEAM assembly a production
contract.

- [x] **Section 1.2 Complete** — evidence: [pinned compilation boundary](../../src/phase-01/abstract-format-subset.md)

### Task 1.2.1: Pin the OTP Build and Runtime Pair

**Description:** Select one OTP release for both compilation and execution and
make its versions, flags, and artifact metadata reproducible from a clean
checkout.

- [x] **Task 1.2.1 Complete** — evidence: [machine-readable toolchain contract](../../src/phase-01/toolchain.config)

#### Subtask 1.2.1.1: Record Toolchain Constraints

**Description:** Add machine-readable OTP and ERTS constraints, deterministic
compiler options, supported architecture assumptions, and a documented clean
build command.

- [x] **Subtask 1.2.1.1 Complete** — evidence: [toolchain constraints](../../src/phase-01/toolchain.config) and [clean build commands](../../Makefile)

#### Subtask 1.2.1.2: Reject Version Drift

**Description:** Fail the build when compiler or runtime versions fall outside
the pinned contract and print the detected and expected versions without
silently continuing.

- [x] **Subtask 1.2.1.2 Complete** — evidence: [compiler boundary checks](../../src/phase-01/alang_phase1_compiler.erl) and [drift rejection test](../../src/phase-01/alang_phase1_compiler_tests.erl)

### Task 1.2.2: Define the Abstract Format Subset

**Description:** Specify the smallest Erlang Abstract Format forms needed for
the first process and make unsupported forms an explicit build error.

- [x] **Task 1.2.2 Complete** — evidence: [Abstract Format subset](../../src/phase-01/abstract-format-subset.md)

#### Subtask 1.2.2.1: Enumerate Allowed Forms and Calls

**Description:** Permit only fixed modules and functions, bounded atoms,
tuples, binaries, integers, `case`, receive behavior through the runtime
adapter, and the exact imports required by the vertical slice.

- [x] **Subtask 1.2.2.1 Complete** — evidence: [allowed forms and runtime calls](../../src/phase-01/abstract-format-subset.md#allowed-abstract-format)

#### Subtask 1.2.2.2: Enforce Strong Validation and Inspection

**Description:** Run OTP strong validation, deterministic compilation, BEAM
chunk inspection, and import allowlisting before any artifact can be loaded.

- [x] **Subtask 1.2.2.2 Complete** — evidence: [strong validation and inspection](../../src/phase-01/alang_phase1_compiler.erl) and [boundary tests](../../src/phase-01/alang_phase1_compiler_tests.erl)

## Section 1.3: First A-Lang BEAM Artifact

**Description:** Produce a deterministic artifact from a language-owned
semantic fixture and attach enough metadata to prove how it was built.

- [x] **Section 1.3 Complete** — evidence: [typed semantic fixture](../../src/phase-01/semantic-fixture.md) and [artifact packager](../../src/phase-01/alang_phase1_package.erl)

### Task 1.3.1: Define the Minimal Semantic Fixture

**Description:** Represent the first program in a small typed data structure
owned by A-Lang rather than as Erlang source or an untyped code-generation
template.

- [x] **Task 1.3.1 Complete** — evidence: [language-owned fixture](../../src/phase-01/semantic-fixture.config)

#### Subtask 1.3.1.1: Model Input, State, and Result

**Description:** Define closed input, state, result, and failure variants for a
single deterministic state transition with no external effect or model call.

- [x] **Subtask 1.3.1.1 Complete** — evidence: [closed fixture types](../../src/phase-01/semantic-fixture.md#closed-types)

#### Subtask 1.3.1.2: Model the Closed Runtime Operations

**Description:** Represent only initialization, one versioned message receive,
one trace emission, one result reply, and termination as named runtime
operations.

- [x] **Subtask 1.3.1.2 Complete** — evidence: [closed runtime operations](../../src/phase-01/semantic-fixture.md#closed-runtime-operations)

### Task 1.3.2: Lower and Package the Artifact

**Description:** Convert the fixture directly into the allowed Abstract Format
subset, compile it, inspect it, and package it as a reproducible `.beam`
artifact.

- [x] **Task 1.3.2 Complete** — evidence: [lowering pass](../../src/phase-01/alang_phase1_fixture.erl) and [artifact packager](../../src/phase-01/alang_phase1_package.erl)

#### Subtask 1.3.2.1: Generate Deterministic Abstract Forms

**Description:** Make identical fixture and toolchain inputs produce identical
normalized forms, stable source locations, bounded atoms, and reproducible
diagnostics.

- [x] **Subtask 1.3.2.1 Complete** — evidence: [deterministic lowering](../../src/phase-01/semantic-fixture.md#deterministic-lowering) and [reproducibility tests](../../src/phase-01/alang_phase1_artifact_tests.erl)

#### Subtask 1.3.2.2: Attach and Verify the Manifest

**Description:** Record source-fixture digest, semantic version, runtime ABI,
OTP target, compiler flags, imports, and artifact digest, then verify the
manifest before loading.

- [x] **Subtask 1.3.2.2 Complete** — evidence: [manifest builder and verifier](../../src/phase-01/alang_phase1_package.erl) and [manifest tests](../../src/phase-01/alang_phase1_artifact_tests.erl)

## Section 1.4: BEAM Execution Integration Test

**Description:** Prove end to end that the accepted artifact runs on ERTS as a
BEAM process and that every non-BEAM substitute fails the phase gate.

- [ ] **Section 1.4 Complete**

### Task 1.4.1: Execute the Successful Vertical Slice on ERTS

**Description:** Start an isolated test node, load the artifact, spawn its
entry process, send the canonical envelope, and collect its reply, trace, and
termination evidence.

- [ ] **Task 1.4.1 Complete**

#### Subtask 1.4.1.1: Capture BEAM Process Evidence

**Description:** Record the loaded module, spawned PID, scheduler-visible
execution, received and emitted envelopes, reductions, exit reason, and node
and OTP versions.

- [ ] **Subtask 1.4.1.1 Complete**

#### Subtask 1.4.1.2: Reproduce the Run from a Clean Checkout

**Description:** Rebuild and execute the same fixture with one documented
command and compare the artifact digest and normalized trace with the expected
evidence.

- [ ] **Subtask 1.4.1.2 Complete**

### Task 1.4.2: Exercise Fail-Closed Runtime Boundaries

**Description:** Demonstrate that malformed artifacts, messages, imports, and
runtime versions are rejected before or during isolated BEAM execution with
classified errors.

- [ ] **Task 1.4.2 Complete**

#### Subtask 1.4.2.1: Run Artifact and ABI Rejection Cases

**Description:** Test bad manifest digests, forbidden imports, unsupported
Abstract Format, mismatched OTP targets, unknown message versions, and
oversized payloads.

- [ ] **Subtask 1.4.2.1 Complete**

#### Subtask 1.4.2.2: Prove the No-Interpreter Gate

**Description:** Inspect the runtime command, process tree, dependencies, and
trace to show that the program result came from the loaded BEAM module rather
than a host evaluator, Erlang source evaluator, or another language runtime.

- [ ] **Subtask 1.4.2.2 Complete**

## Phase 1 Completion Evidence

**Description:** Phase 1 is complete only when the repository contains
reproducible evidence for all items below.

- [ ] OTP compiler and ERTS versions are pinned and enforced
- [ ] The language-owned fixture lowers through the documented Abstract Format subset
- [ ] The artifact passes validation, import inspection, and manifest verification
- [ ] The artifact loads and runs as a spawned BEAM process on an isolated node
- [ ] The canonical message, result, trace, and termination evidence match the contract
- [ ] Negative artifact, ABI, payload, and version cases fail closed
- [ ] No host-language or existing BEAM-language interpreter executes the A-Lang program
