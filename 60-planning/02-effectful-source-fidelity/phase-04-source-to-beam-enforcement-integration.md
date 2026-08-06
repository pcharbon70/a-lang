---
title: "Phase 4: Source-to-BEAM Enforcement Integration"
kind: note
created: 2026-08-05
maturity: developing
tags:
  - beam
  - capability-security
  - compiler-backend
  - implementation-planning
  - otp
aliases: []
---

# Phase 4: Source-to-BEAM Enforcement Integration

**Description:** Compile `alang_typed_task_ir_v2` through the existing
BEAM-resident Abstract Format backend and execute each corpus family through
the same generated-code, model, broker, durability, child, workspace, and
completion boundaries. Offline deterministic evidence must prove the complete
path before hosted-model variability is introduced.

**Status:** Complete; all four sections pass from source, and the reproducible
[Phase 4 integration evidence](../../src/effectful-source-fidelity/phase-04-integration-evidence.md)
records the complete offline source-to-BEAM enforcement gate.

**Dependencies:** Phase 3 complete with matched IR and manifests for all 24
pairs. The Phase 3 backend and artifact inspector plus Phase 4–8 runtime and
validation evidence remain the implementation baseline and may not be bypassed.

## Section 4.1: IR V2 Backend and Artifact Contract

**Description:** Extend the allowlisted Abstract Format lowering and artifact
metadata only where v2 semantics require it, retaining deterministic output and
fixed generated-module discipline.

- [x] **Section 4.1 Complete**

### Task 4.1.1: Lower V2 Control and Delegation Through Closed Runtime Calls

**Description:** Lower existing data/result/sequence/effect nodes unchanged and
map the new delegate node and completion metadata only to fixed versioned A-Lang
runtime ABI calls.

- [x] **Task 4.1.1 Complete**

#### Subtask 4.1.1.1: Extend Abstract Format Lowering Conservatively

**Description:** Generate static calls for result matching, registered effects,
child start/await/cancel, and completion verification; preserve only the
existing allowlisted bounded receive-with-timeout form where the runtime
contract requires it, and reject arbitrary remote calls, dynamic apply,
unbounded receive, direct spawn, ports, ETS, filesystem, network, and dynamic
module/function values in generated forms.

- [x] **Subtask 4.1.1.1 Complete**

#### Subtask 4.1.1.2: Preserve Source and JSON Diagnostics

**Description:** Map backend validation failures through the artifact's
frontend identity and source map so A-Lang reports byte/line/column and JSON
reports JSON pointer/offset without leaking Abstract Format internals.

- [x] **Subtask 4.1.1.2 Complete**

### Task 4.1.2: Version and Inspect V2 Artifact Metadata

**Description:** Attach deterministic metadata for IR v2, semantic digest,
frontend/source digest, manifest, task limits, child restrictions, completion
specification, compiler identity, and pinned OTP profile.

- [x] **Task 4.1.2 Complete**

#### Subtask 4.1.2.1: Encode Metadata Deterministically

**Description:** Use the versioned deterministic-ETF attribute envelope,
canonical field ordering, and bounded decoded shapes so repeated clean ERTS
processes produce byte-identical artifacts for the same representation.

- [x] **Subtask 4.1.2.1 Complete**

#### Subtask 4.1.2.2: Reject Tampered or Widened Artifacts

**Description:** Fail inspection when imports, exports, module identity,
manifest, limits, child bounds, completion predicates, source/semantic digests,
IR version, compiler profile, or metadata encoding differ from the compiler
evidence.

- [x] **Subtask 4.1.2.2 Complete**

## Section 4.2: Runtime Binding for Model, Repair, Child, and Completion

**Description:** Bind compiled manifests and task metadata to the existing
supervised runtime so source declarations become enforced limits rather than
documentation.

- [x] **Section 4.2 Complete**

### Task 4.2.1: Instantiate Runtime State and Local Authority from Artifacts

**Description:** Create task state, broker policy, grants, shared budgets,
deadlines, and durable session identities from inspected metadata and
operator-owned resource bindings only.

- [x] **Task 4.2.1 Complete**

#### Subtask 4.2.1.1: Bind Model and Workspace Resources

**Description:** Resolve declared model profiles and workspace identities
against the closed operator policy, issue opaque local grants with exact
operation/resource/budget/deadline scope, and reject absent, extra, or widened
bindings before generated code starts.

- [x] **Subtask 4.2.1.1 Complete**

#### Subtask 4.2.1.2: Bind Limits to Durable Task State

**Description:** Initialize step, model, repair, child, workspace, byte, and
deadline counters from the artifact, checkpoint them before consequential
effects, derive stable operation identities from trusted session, transition,
and effect-site state, and reject runtime attempts to supply, increase, reset,
or reuse those values inconsistently.

- [x] **Subtask 4.2.1.2 Complete**

### Task 4.2.2: Execute Repair, Delegation, and Completion Semantics

**Description:** Route definitive syntax/schema failures through at most one
diagnostic repair, run a statically named more-restricted child, and let only
the independent artifact verifier produce completion.

- [x] **Task 4.2.2 Complete**

#### Subtask 4.2.2.1: Connect Source Metadata to Existing Repair and Child APIs

**Description:** Preserve original request/profile/schema/deadline through
repair, derive a fresh operation identity, mechanically restrict the child's
grant and shared budget, fence replies, and propagate cancellation without
exposing grants or process identities to model-visible data.

- [x] **Subtask 4.2.2.1 Complete**

#### Subtask 4.2.2.2: Bind Canonical Output to Completion Evidence

**Description:** Parse a valid comprehension response, canonicalize it,
write it through the broker and durable workspace adapter, and require the
declared path, answer-key digest, byte/UTF-8/Markdown/section predicates, and
matching journal result before emitting a complete witness.

- [x] **Subtask 4.2.2.2 Complete**

## Section 4.3: Offline Paired Execution and Inherited Gates

**Description:** Run both representation paths against deterministic model and
replay fixtures while preserving all negative evidence from the first roadmap.

- [x] **Section 4.3 Complete**

### Task 4.3.1: Execute All Three Families Through the Same Runtime

**Description:** Compile A-Lang and JSON independently, load inspected BEAM,
run each condition with matched offline responses, and compare normalized
results, effect traces, broker decisions, journals, child evidence, artifacts,
and completion witnesses.

- [x] **Task 4.3.1 Complete**

#### Subtask 4.3.1.1: Prove Positive Observation Equality

**Description:** Require each valid pair to reach the same typed result,
registered effect sequence, authority decision, normalized executable-artifact
semantic digest, terminal class, and completion-witness digest after removing
representation-specific source provenance; raw artifacts retain their distinct
frontend/source metadata.

- [x] **Subtask 4.3.1.1 Complete**

#### Subtask 4.3.1.2: Prove Matched Failure and Incomplete Outcomes

**Description:** Exercise denied scope, exhausted budget, malformed response,
repair failure, child widening, cancellation, uncertain workspace outcome,
wrong digest, and missing-information cases and require the same fail-closed
classification in both conditions.

- [x] **Subtask 4.3.1.2 Complete**

### Task 4.3.2: Reuse the Full Security, Fault, and Law Campaign

**Description:** Run the established Phase 7/8 suites against the extended
compiler and runtime and add only v2-specific mutants and fault transitions.

- [x] **Task 4.3.2 Complete**

#### Subtask 4.3.2.1: Reassert Existing Enforcement and Recovery Evidence

**Description:** Require all prior law, differential, adversarial, broker,
workspace-isolation, durability, fault, pressure, leak, mutation, and completion
tests to pass without weakening expected denials or uncertainty.

- [x] **Subtask 4.3.2.1 Complete**

#### Subtask 4.3.2.2: Add V2-Specific Mutants and Faults

**Description:** Detect ignored source manifests, JSON bypass, increased runtime
limits, child authority widening, skipped repair accounting, source-map swaps,
completion from model text, and condition-specific runtime handlers.

- [x] **Subtask 4.3.2.2 Complete**

## Section 4.4: Phase 4 Integration Tests

**Description:** Prove from clean source that both frontends produce inspected
BEAM artifacts and only those artifacts satisfy the complete offline execution
gate.

- [x] **Section 4.4 Complete**

### Task 4.4.1: Run the Offline Source-to-Evidence Matrix

**Description:** Provide one command that rebuilds the BEAM-resident toolchain,
compiles all 48 representation files, checks pair semantics, executes the three
families with frozen mock responses, and writes deterministic evidence below an
owned build directory.

- [x] **Task 4.4.1 Complete**

#### Subtask 4.4.1.1: Reproduce Artifacts Across Clean ERTS Processes

**Description:** Rebuild a representative artifact from each family and
condition in separate pinned ERTS processes and require byte-identical BEAM,
metadata, normalized traces, artifacts, and completion evidence.

- [x] **Subtask 4.4.1.1 Complete**

#### Subtask 4.4.1.2: Reassert Compiler Residency and No Interpreter

**Description:** Require every trusted frontend/backend module to load from a
`.beam` file, no foreign executable in the compiler graph, no emitted Erlang
source or Core Erlang, and no reference/JSON evaluator accepted as execution.

- [x] **Subtask 4.4.1.2 Complete**

### Task 4.4.2: Publish Phase 4 Integration Evidence

**Description:** Reconcile artifact, manifest, runtime, security, recovery,
completion, and regression evidence for the complete offline paired matrix.

- [x] **Task 4.4.2 Complete**

#### Subtask 4.4.2.1: Index Positive and Negative Evidence

**Description:** Link every Phase 4 claim to a test, trace, artifact inspection,
broker audit, journal, child record, completion witness, or seeded-defect
result and leave any unsupported claim unchecked.

- [x] **Subtask 4.4.2.1 Complete**

#### Subtask 4.4.2.2: Record Remaining Runtime Risks

**Description:** Preserve the same-node trust, local-store, fixed-module,
single-OTP, provider-mock, and non-production limitations instead of treating
successful effectful source compilation as their resolution.

- [x] **Subtask 4.4.2.2 Complete**

## Phase 4 Completion Evidence

**Description:** Authorize hosted evaluation only after representation is the
sole experimental variable in a fully enforced offline path.

- [x] IR v2 lowers only through allowlisted Abstract Format and runtime ABI calls
- [x] Artifact inspection binds source, semantic, manifest, limit, child, and completion evidence
- [x] All 48 representation files compile to inspected BEAM without manual IR
- [x] All three task families execute as supervised generated BEAM processes
- [x] Paired positive, negative, incomplete, and uncertain observations agree
- [x] Runtime grants and counters are derived from inspected static metadata
- [x] Model text cannot mark completion or widen authority
- [x] All inherited Phase 1–8 gates pass unchanged
- [x] V2-specific mutants and faults are detected
- [x] Offline artifacts and evidence reproduce across clean ERTS processes
