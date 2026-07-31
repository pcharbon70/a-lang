---
title: "Phase 1: Executable Contract and Toolchain Foundation"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - compiler-design
  - implementation-planning
  - proof-of-concept
  - toolchain
aliases: []
---

# Phase 1: Executable Contract and Toolchain Foundation

**Description:** This phase converts the research conclusions into one frozen
vertical-slice contract, creates the native compiler and runtime workspace,
pins the Rust and OTP toolchains, and establishes semantic fixtures,
diagnostics, and clean-build gates before language implementation begins.

**Status:** Planned.

**Dependencies:** The task-language, categorical, BEAM, and UCAN synthesis
notes are accepted as the planning baseline. No implementation phase is yet
complete.

## Section 1.1: Proof-of-Concept Semantic Contract

**Description:** Define exactly what the final demonstration accepts,
executes, observes, and rejects so later phases cannot silently broaden the
language or weaken the evidence standard.

- [ ] **Section 1.1 Complete**

### Task 1.1.1: Publish the Executable Feature Ledger

**Description:** Create a versioned ledger for every source, IR, backend,
runtime, effect, authorization, and verifier feature in the minimal PoC.

- [ ] **Task 1.1.1 Complete**

#### Subtask 1.1.1.1: Classify the Minimal Language Surface

**Description:** Mark primitive types, records, products, results, modules,
pure functions, tasks, sequential composition, exhaustive result matching,
closed effects, capability requirements, and completion predicates as planned
PoC features.

- [ ] **Subtask 1.1.1.1 Complete**

#### Subtask 1.1.1.2: Record Deferred and Forbidden Surfaces

**Description:** Record recursion, polymorphic effects, arbitrary actors,
parallelism, distribution, dynamic loading, direct Core or BEAM emission,
general tools, and advanced UCAN lifecycle formats as explicit non-goals that
must fail closed.

- [ ] **Subtask 1.1.1.2 Complete**

### Task 1.1.2: Specify the Canonical End-to-End Scenario

**Description:** Define one deterministic example that uses a bounded model
completion to produce text and a least-authority workspace effect to publish
an artifact with verifiable completion evidence.

- [ ] **Task 1.1.2 Complete**

#### Subtask 1.1.2.1: Fix Inputs, Outputs, and Expected Trace

**Description:** Specify the source input, mock-model response, output path,
artifact digest, typed result, effect events, authorization events, and final
completion witness expected from a successful run.

- [ ] **Subtask 1.1.2.1 Complete**

#### Subtask 1.1.2.2: Fix Negative Scenario Variants

**Description:** Define deterministic failures for syntax, type, undeclared
effect, insufficient requirement, escaped path, expired grant, wrong audience,
replay, malformed model output, failed verifier, and worker crash.

- [ ] **Subtask 1.1.2.2 Complete**

## Section 1.2: Repository and Toolchain Bootstrap

**Description:** Establish reproducible code, test, fixture, and generated
artifact boundaries without treating bootstrap support written in Erlang as an
A-Lang interpreter.

- [ ] **Section 1.2 Complete**

### Task 1.2.1: Create the Implementation Workspace

**Description:** Create a documented workspace that separates the Rust
compiler and evaluator, BEAM support modules, UCAN port, examples, conformance
fixtures, integration tests, and generated outputs.

- [ ] **Task 1.2.1 Complete**

#### Subtask 1.2.1.1: Define Component Ownership

**Description:** Assign parsing, semantic analysis, typed IR, reference
evaluation, Abstract Format encoding, runtime ABI, broker, authorization,
adapters, journal, and verification to explicit components with one-way
dependencies.

- [ ] **Subtask 1.2.1.1 Complete**

#### Subtask 1.2.1.2: Define Generated and Persistent State

**Description:** Separate disposable build artifacts from checked-in fixtures
and durable runtime state, and ensure secrets, session keys, proof caches, and
journals cannot enter source control.

- [ ] **Subtask 1.2.1.2 Complete**

### Task 1.2.2: Pin the Bootstrap Toolchains

**Description:** Pin one Rust toolchain, OTP 29.x release, dependency set,
artifact format version, and supported host platforms for reproducible PoC
builds.

- [ ] **Task 1.2.2 Complete**

#### Subtask 1.2.2.1: Record Compiler and Runtime Versions

**Description:** Add machine-readable Rust and OTP version constraints and a
human-readable compatibility statement that distinguishes the A-Lang version
from the backend OTP version.

- [ ] **Subtask 1.2.2.1 Complete**

#### Subtask 1.2.2.2: Establish Reproducible Commands

**Description:** Provide single commands for formatting, linting, unit tests,
integration tests, fixture checks, compiler build, runtime build, and complete
PoC validation from a clean checkout.

- [ ] **Subtask 1.2.2.2 Complete**

## Section 1.3: Artifact, Diagnostic, and Oracle Baseline

**Description:** Define stable observable forms for source programs, typed IR,
compiler artifacts, runtime events, and failures before implementation details
can become accidental contracts.

- [ ] **Section 1.3 Complete**

### Task 1.3.1: Version the Canonical Data Contracts

**Description:** Define schemas and version fields for canonical JSON source
fixtures, typed IR fixtures, capability manifests, backend metadata, runtime
messages, trace events, and completion evidence.

- [ ] **Task 1.3.1 Complete**

#### Subtask 1.3.1.1: Define Canonical Serialization Rules

**Description:** Specify field order independence, stable identifiers,
normalization, digest inputs, unknown-field behavior, size limits, and
round-trip expectations for each serialized boundary.

- [ ] **Subtask 1.3.1.1 Complete**

#### Subtask 1.3.1.2: Define Compatibility and Rejection Rules

**Description:** Specify how readers handle older, current, newer, malformed,
and unsupported versions and require fail-closed diagnostics for every
incompatible artifact.

- [ ] **Subtask 1.3.1.2 Complete**

### Task 1.3.2: Establish Stable Diagnostics and the Semantic Oracle

**Description:** Define one source-oriented diagnostic taxonomy and a small
independent evaluator model that later phases can use to compare normalized
meaning with compiled BEAM observations.

- [ ] **Task 1.3.2 Complete**

#### Subtask 1.3.2.1: Name Failure Families

**Description:** Define stable categories for lexical, syntax, resolution,
type, effect, requirement, lowering, OTP validation, runtime ABI,
authorization, policy, replay, adapter, verifier, and recovery failures.

- [ ] **Subtask 1.3.2.1 Complete**

#### Subtask 1.3.2.2: Define Normalized Observations

**Description:** Specify values, effect intents, decisions, state transitions,
results, completion evidence, and irrelevant runtime details so the reference
evaluator and BEAM backend can be compared without requiring identical
scheduler traces.

- [ ] **Subtask 1.3.2.2 Complete**

## Section 1.4: Phase 1 Integration Tests

**Description:** Verify that the frozen contract, workspace, toolchains,
schemas, fixtures, diagnostics, and build commands form a coherent baseline
before parser or runtime behavior is implemented.

- [ ] **Section 1.4 Complete**

### Task 1.4.1: Validate the Clean Bootstrap

**Description:** Exercise every repository command on a clean checkout and
confirm generated files, caches, keys, and runtime state remain isolated from
versioned source.

- [ ] **Task 1.4.1 Complete**

#### Subtask 1.4.1.1: Run Toolchain Smoke Tests

**Description:** Build and run a minimal Rust binary, compile and load a fixed
handwritten Abstract Format fixture through the OTP bridge, and exchange one
versioned message with a support process.

- [ ] **Subtask 1.4.1.1 Complete**

#### Subtask 1.4.1.2: Verify Reproducible Artifact Boundaries

**Description:** Repeat the bootstrap build, compare declared deterministic
outputs, and verify temporary and persistent state are created only under
their documented directories.

- [ ] **Subtask 1.4.1.2 Complete**

### Task 1.4.2: Validate the Contract and Fixture Baseline

**Description:** Check that every planned and deferred feature, positive and
negative scenario, schema, diagnostic family, and normalized observation has
a stable identifier and reviewable fixture.

- [ ] **Task 1.4.2 Complete**

#### Subtask 1.4.2.1: Audit Feature-to-Fixture Coverage

**Description:** Produce a report showing which fixture and later phase owns
each ledger item and reject duplicate, unowned, or implicitly promoted
features.

- [ ] **Subtask 1.4.2.1 Complete**

#### Subtask 1.4.2.2: Run Phase Completion Gates

**Description:** Run formatting, linting, schema, fixture, toolchain, and clean
workspace checks and publish exact versions and results as Phase 1 evidence.

- [ ] **Subtask 1.4.2.2 Complete**

### Phase 1 Completion Evidence

**Description:** Record the reproducible evidence that authorizes Phase 2 to
implement syntax and semantics without revisiting hidden bootstrap decisions.

- [ ] Feature ledger and non-goal ledger reviewed
- [ ] Canonical positive and negative scenario fixtures accepted
- [ ] Rust and OTP toolchains pinned and reproducible
- [ ] OTP bridge compiles and loads a fixed validated module
- [ ] Schemas, versions, normalized observations, and diagnostics published
- [ ] Clean-checkout build and repository gates pass
