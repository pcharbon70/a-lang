---
title: "Phase 3: Erlang Abstract Format and BEAM Runtime Kernel"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - beam
  - compiler-backend
  - implementation-planning
  - runtime-systems
aliases: []
---

# Phase 3: Erlang Abstract Format and BEAM Runtime Kernel

**Description:** This phase generalizes the Phase 1
A-Lang-IR-to-Erlang-Abstract-Format path, deterministic artifact checks, and
ERTS execution into a complete minimal backend, closed versioned runtime ABI,
and supervised task-process kernel without introducing an existing
BEAM-language interpreter.

**Status:** In progress — Sections 3.1 through 3.4 complete.

**Dependencies:** Phase 2 complete with source-derived typed IR, normalized
observations, test-only reference views, capability manifests, fail-closed
semantic fixtures, and successful compiled BEAM execution accepted.

## Section 3.1: Backend Representation Contract

**Description:** Define the exact runtime representations and supported
Abstract Format subset before emitting code.

- [x] **Section 3.1 Complete** — evidence: [backend representation contract](../../src/phase-03/backend-representation-contract.md), [Abstract Format contract](../../src/phase-03/abstract-format-contract.md), and [executable contract tests](../../src/phase-03/alang_phase3_contract_tests.erl)

### Task 3.1.1: Map Typed IR Values and Control to BEAM Terms

**Description:** Specify deterministic runtime representations for primitives,
opaque identifiers, records, products, results, functions, tasks, sequential
composition, effect requests, and verifier results.

- [x] **Task 3.1.1 Complete** — evidence: [closed value and failure encodings](../../src/phase-03/alang_phase3_contract.erl)

#### Subtask 3.1.1.1: Define Value and Error Encodings

**Description:** Assign closed tags and field orderings, distinguish source
errors from runtime protocol errors, and prohibit representation collisions
with user data.

- [x] **Subtask 3.1.1.1 Complete** — evidence: [value representation contract](../../src/phase-03/backend-representation-contract.md#values)

#### Subtask 3.1.1.2: Define Evaluation and Failure Order

**Description:** Specify expression evaluation order, result propagation,
exception containment, effect suspension, deadline observation, and verifier
execution in terms that both the evaluator and compiled backend can observe.

- [x] **Subtask 3.1.1.2 Complete** — evidence: [evaluation and failure order](../../src/phase-03/backend-representation-contract.md#evaluation-and-failure-order)

### Task 3.1.2: Freeze the Abstract Format Subset

**Description:** Enumerate the smallest OTP-supported Abstract Format forms and
runtime calls required by the PoC and reject every other backend shape.

- [x] **Task 3.1.2 Complete** — evidence: [closed Abstract Format surface](../../src/phase-03/abstract-format-contract.md)

#### Subtask 3.1.2.1: Classify Required Forms and Calls

**Description:** Cover modules, attributes, functions, clauses, variables,
literals, tuples, maps where justified, calls, cases, receives, timeouts, and
the fixed A-Lang runtime ABI without relying on Core Erlang or BEAM assembly.

- [x] **Subtask 3.1.2.1 Complete** — evidence: [allowed forms and calls](../../src/phase-03/alang_phase3_contract.erl)

#### Subtask 3.1.2.2: Define Fail-Closed Backend Diagnostics

**Description:** Map every unsupported IR node, invalid representation,
unresolved runtime call, illegal atom source, and OTP rejection back to the
original A-Lang node and source span.

- [x] **Subtask 3.1.2.2 Complete** — evidence: [source-oriented rejection tests](../../src/phase-03/alang_phase3_contract_tests.erl)

## Section 3.2: Abstract Format Lowering and OTP Compilation

**Description:** Generate supported Abstract Format directly from typed IR,
compile it through pinned OTP services, and emit only validated artifacts.

- [x] **Section 3.2 Complete** — evidence: [BEAM-resident lowering](../../src/phase-03/alang_phase3_lowering.erl), [bounded Abstract Format validator](../../src/phase-03/alang_phase3_forms.erl), [pinned OTP compiler bridge](../../src/phase-03/alang_phase3_backend.erl), and [backend tests](../../src/phase-03/alang_phase3_backend_tests.erl)

### Task 3.2.1: Implement the BEAM-Resident Abstract Format Encoder

**Description:** Lower each promoted typed IR node to normalized Abstract
Format terms inside the compiler's build ERTS node without generating Erlang
source or invoking a foreign compiler executable.

- [x] **Task 3.2.1 Complete** — evidence: [fixed-module Abstract Format encoder](../../src/phase-03/alang_phase3_lowering.erl)

#### Subtask 3.2.1.1: Lower Pure Data and Control Nodes

**Description:** Implement values, bindings, applications, functions,
products, result construction, exhaustive cases, sequential tasks, and final
returns with deterministic generated identities.

- [x] **Subtask 3.2.1.1 Complete** — evidence: [pure data and control lowering tests](../../src/phase-03/alang_phase3_backend_tests.erl)

#### Subtask 3.2.1.2: Lower Effect and Verifier Boundaries

**Description:** Translate effect requests and completion predicates into
calls through the fixed runtime ABI while preserving correlation, deadline,
source origin, expected argument and result types, and capability operation
identity.

- [x] **Subtask 3.2.1.2 Complete** — evidence: [runtime-ABI-only effect lowering](../../src/phase-03/alang_phase3_backend_tests.erl)

### Task 3.2.2: Implement the Pinned OTP Compilation Bridge

**Description:** Accept bounded Abstract Format input, run OTP compiler
validation, and return either a verified in-memory BEAM binary with diagnostics
or a structured failure.

- [x] **Task 3.2.2 Complete** — evidence: [in-memory OTP compilation bridge](../../src/phase-03/alang_phase3_backend.erl)

#### Subtask 3.2.2.1: Compile with Strong Validation and Determinism

**Description:** Invoke the supported OTP compile path with strong validation,
stable options, warning capture, no uncontrolled filesystem lookup, and
repeatable artifact comparison.

- [x] **Subtask 3.2.2.1 Complete** — evidence: [pinned strong-validation and repeatability test](../../src/phase-03/alang_phase3_backend_tests.erl)

#### Subtask 3.2.2.2: Return Source-Oriented Compiler Evidence

**Description:** Translate OTP errors and warnings to A-Lang source identities,
record backend and OTP versions, and reject any output that lacks successful
validation evidence.

- [x] **Subtask 3.2.2.2 Complete** — evidence: [source-identity diagnostic translation](../../src/phase-03/alang_phase3_backend.erl)

## Section 3.3: Versioned Runtime ABI and Task Process

**Description:** Establish the only runtime protocol compiled programs may use
for effects, replies, deadlines, cancellation, traces, and termination.

- [x] **Section 3.3 Complete** — evidence: [closed runtime ABI](../../src/phase-03/alang_phase3_abi.erl), [supervised session kernel](../../src/phase-03/alang_phase3_session_sup.erl), and [runtime protocol and lifecycle tests](../../src/phase-03/alang_phase3_runtime_tests.erl)

### Task 3.3.1: Implement the Closed Runtime Message Protocol

**Description:** Define and decode bounded envelopes for task start, effect
intent, effect result, denial, cancellation, deadline, trace, completion, and
runtime failure.

- [x] **Task 3.3.1 Complete** — evidence: [closed envelope implementation](../../src/phase-03/alang_phase3_abi.erl)

#### Subtask 3.3.1.1: Define Envelope and Correlation Semantics

**Description:** Include ABI version, closed kind tag, session and task IDs,
correlation ID, monotonic deadline, typed payload tag, reply target, and source
origin with explicit maximum sizes.

- [x] **Subtask 3.3.1.1 Complete** — evidence: [bounded envelope construction and validation](../../src/phase-03/alang_phase3_abi.erl)

#### Subtask 3.3.1.2: Reject Malformed and Stale Messages

**Description:** Validate every field before dispatch, reject unknown versions
and tags, drop or record late replies deterministically, and avoid dynamic atom
creation from message contents.

- [x] **Subtask 3.3.1.2 Complete** — evidence: [malformed, stale, oversized, and atom-safety tests](../../src/phase-03/alang_phase3_runtime_tests.erl)

### Task 3.3.2: Implement the Minimal Supervised Task Lifecycle

**Description:** Launch one compiled task under bounded supervision and govern
its admission, execution, waiting, cancellation, timeout, completion, and
failure states.

- [x] **Task 3.3.2 Complete** — evidence: [runtime launcher](../../src/phase-03/alang_phase3_launcher.erl), [session supervisor](../../src/phase-03/alang_phase3_session_sup.erl), and [task worker](../../src/phase-03/alang_phase3_task_worker.erl)

#### Subtask 3.3.2.1: Define Process Topology and Ownership

**Description:** Separate launcher, session supervisor, task worker, effect
gateway, and trace collector responsibilities and make every process and
monitor relationship explicit.

- [x] **Subtask 3.3.2.1 Complete** — evidence: [explicit supervised ownership topology](../../src/phase-03/alang_phase3_session_sup.erl)

#### Subtask 3.3.2.2: Bound Mailboxes, Deadlines, and Cancellation

**Description:** Enforce admission and in-flight limits, refuse work under
pressure, handle task and gateway death, propagate cancellation, and ensure
timeouts do not convert an uncertain effect into an automatic retry.

- [x] **Subtask 3.3.2.2 Complete** — evidence: [bounded gateway](../../src/phase-03/alang_phase3_effect_gateway.erl), [bounded trace collector](../../src/phase-03/alang_phase3_trace.erl), and [overload, cancellation, gateway-death, deadline, and no-retry tests](../../src/phase-03/alang_phase3_runtime_tests.erl)

## Section 3.4: Artifact Inspection and Loading Boundary

**Description:** Ensure that only approved compiler artifacts with a closed
import and metadata surface can load on the PoC node.

- [x] **Section 3.4 Complete** — evidence: [artifact and loading contract](../../src/phase-03/artifact-contract.md), [artifact inspector and loader](../../src/phase-03/alang_phase3_artifact.erl), and [pre-load and lifecycle tests](../../src/phase-03/alang_phase3_artifact_tests.erl)

### Task 3.4.1: Emit A-Lang Artifact Metadata

**Description:** Bind each BEAM artifact to source and IR digests, compiler and
OTP versions, ABI version, capability manifest, source map, and reproducibility
data.

- [x] **Task 3.4.1 Complete** — evidence: [artifact metadata contract](../../src/phase-03/artifact-contract.md#metadata-placement) and [metadata emission](../../src/phase-03/alang_phase3_lowering.erl)

#### Subtask 3.4.1.1: Define Metadata Placement and Digest Scope

**Description:** Choose validated attributes or custom chunks, define which
bytes each digest covers, and prevent mutable build details from undermining
deterministic comparison.

- [x] **Subtask 3.4.1.1 Complete** — evidence: [metadata placement and digest scope](../../src/phase-03/artifact-contract.md#metadata-placement)

#### Subtask 3.4.1.2: Implement Metadata Inspection

**Description:** Provide a tool that reports source identity, IR identity,
versions, imports, capability requirements, and load policy without executing
the module.

- [x] **Subtask 3.4.1.2 Complete** — evidence: [nonexecuting artifact inspection](../../src/phase-03/alang_phase3_artifact.erl)

### Task 3.4.2: Enforce the Approved Load Policy

**Description:** Inspect module identity, imports, attributes, chunks, size,
compiler provenance, and ABI compatibility before isolated loading.

- [x] **Task 3.4.2 Complete** — evidence: [approved load policy](../../src/phase-03/alang_phase3_artifact.erl)

#### Subtask 3.4.2.1: Restrict Imports and Dynamic Behavior

**Description:** Permit only the fixed runtime ABI and explicitly approved
pure BIFs, and reject arbitrary module application, ports, NIF loading,
unsafe term decoding, and unbounded dynamic module or atom creation.

- [x] **Subtask 3.4.2.1 Complete** — evidence: [closed BEAM import and container tests](../../src/phase-03/alang_phase3_artifact_tests.erl)

#### Subtask 3.4.2.2: Load, Execute, and Purge Safely

**Description:** Load only inspected artifacts into the PoC node, start through
the runtime launcher, terminate all owning tasks before purge, and report code
lifecycle failures without hot-upgrade semantics.

- [x] **Subtask 3.4.2.2 Complete** — evidence: [inspected load-execute-soft-purge test](../../src/phase-03/alang_phase3_artifact_tests.erl)

## Section 3.5: Phase 3 Integration Tests

**Description:** Compare reference and compiled execution across pure and
fixture-backed effect programs while proving the backend and loader fail
closed.

- [ ] **Section 3.5 Complete**

### Task 3.5.1: Validate Source-to-BEAM Semantic Preservation

**Description:** Compile canonical Phase 2 programs, load their artifacts, and
compare normalized values, effect intents, result propagation, verifier
observations, and failures with the reference evaluator.

- [ ] **Task 3.5.1 Complete**

#### Subtask 3.5.1.1: Run Positive Differential Fixtures

**Description:** Cover every promoted value, branch, call, composition, effect
request, and verifier form with deterministic injected effect responses.

- [ ] **Subtask 3.5.1.1 Complete**

#### Subtask 3.5.1.2: Run Negative Backend and ABI Fixtures

**Description:** Reject unsupported IR, malformed forms, OTP validation
failures, forbidden imports, incompatible metadata, malformed messages, stale
replies, and runtime timeouts with stable diagnostics.

- [ ] **Subtask 3.5.1.2 Complete**

### Task 3.5.2: Validate Whole-Toolchain BEAM Residency

**Description:** Demonstrate that every trusted compiler pass runs as BEAM
code, and that A-Lang source is neither translated to Erlang source nor
evaluated by an Erlang, Elixir, Gleam, or other BEAM-language interpreter at
build time or runtime.

- [ ] **Task 3.5.2 Complete**

#### Subtask 3.5.2.1: Inspect the Build and Runtime Path

**Description:** Publish a trace from BEAM-resident source compilation through
typed IR, Abstract Format, OTP validation, BEAM load, and ERTS task execution;
identify every compiler and runtime module and prove that no foreign compiler
executable participated.

- [ ] **Subtask 3.5.2.1 Complete**

#### Subtask 3.5.2.2: Run Phase Completion Gates

**Description:** Run compiler, differential, OTP validation, artifact
inspection, loader, ABI, scheduler-smoke, and complete repository suites on the
pinned OTP release.

- [ ] **Subtask 3.5.2.2 Complete**

## Phase 3 Completion Evidence

**Description:** Record the evidence that authorizes Phase 4 to replace
fixture-backed effects with a local capability broker and bounded adapter.

- [ ] Every promoted typed IR node lowers through the frozen Abstract Format
      subset
- [ ] OTP strong validation and deterministic artifact checks pass
- [ ] Artifact metadata and import inspection pass before every load
- [ ] Reference and BEAM normalized observations agree
- [ ] Runtime ABI rejects malformed, stale, and incompatible messages
- [ ] Trusted compiler path contains only loaded BEAM modules and pinned OTP
      services
- [ ] Generated execution path contains no A-Lang source or IR interpreter
