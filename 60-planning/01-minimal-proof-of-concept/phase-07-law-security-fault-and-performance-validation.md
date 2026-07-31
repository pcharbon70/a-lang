---
title: "Phase 7: Law, Security, Fault, and Performance Validation"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - capability-security
  - implementation-planning
  - property-based-testing
  - runtime-validation
aliases: []
---

# Phase 7: Law, Security, Fault, and Performance Validation

**Description:** This phase tests the complete PoC through generated
composition and local capability-restriction laws, test-view-to-BEAM
differential checks, malformed and hostile inputs, complete effect-transition
fault injection, scheduler and resource pressure, and seeded-defect
sensitivity.

**Status:** Planned.

**Dependencies:** Phase 6 complete with a deterministic compiled parent-child
BEAM workflow, typed model boundary, opaque local authority, durable effects,
context minimization, and completion witnesses accepted.

## Section 7.1: Typed Generators and Law Definitions

**Description:** Generate only well-formed source, IR, capability, runtime, and
state-machine values and define equality or observation explicitly for every
law under test.

- [ ] **Section 7.1 Complete**

### Task 7.1.1: Implement Typed Source and IR Generators

**Description:** Generate bounded well-typed values, expressions, pure arrows,
result branches, sequential tasks, effect rows, requirements, and verifier
nodes with shrinkers that preserve validity.

- [ ] **Task 7.1.1 Complete**

#### Subtask 7.1.1.1: Generate Pure and Effectful Programs

**Description:** Separate total pure terms from fixture-backed effectful terms,
control size and depth, retain source origins, and produce both textual and
canonical JSON forms where possible.

- [ ] **Subtask 7.1.1.1 Complete**

#### Subtask 7.1.1.2: Shrink Semantic Counterexamples

**Description:** Shrink values, branches, task graphs, effects, requirements,
and verifier predicates without introducing type errors or changing the
failure class being investigated.

- [ ] **Subtask 7.1.1.2 Complete**

### Task 7.1.2: Define Categorical and Effect Observations

**Description:** Specify the equality used for pure values and the normalized
trace equivalence used for effectful or concurrent task execution.

- [ ] **Task 7.1.2 Complete**

#### Subtask 7.1.2.1: Define Pure Composition Laws

**Description:** Test identity and associativity, product projections and
pairing, result injection and case behavior, and deterministic normalization
under ordinary value equality.

- [ ] **Subtask 7.1.2.1 Complete**

#### Subtask 7.1.2.2: Define Task and Interpreter Laws

**Description:** Test sequential identity and associativity, effect and
requirement union, result propagation, interpreter coverage, manifest
composition, serialization, and reference-to-BEAM observational agreement.

- [ ] **Subtask 7.1.2.2 Complete**

## Section 7.2: Authorization and Runtime State Properties

**Description:** Generate local grants, restrictions, policies, runtime
messages, journal histories, failures, and recovery actions and check their
monotonic or state-machine invariants.

- [ ] **Section 7.2 Complete**

### Task 7.2.1: Implement Local Capability Restriction Properties

**Description:** Interpret broker-held grants as finite sets of accepted typed
invocations and test that every child, policy, budget, and time change
preserves or reduces authority.

- [ ] **Task 7.2.1 Complete**

#### Subtask 7.2.1.1: Test Restriction and Composition Laws

**Description:** Test subset reflexivity and transitivity, identity
restriction, policy conjunction, resource and validity intersection, child
restriction, and policy-controlled union of independent local grants.

- [ ] **Subtask 7.2.1.1 Complete**

#### Subtask 7.2.1.2: Test Reference Lifecycle and Broker Agreement

**Description:** Generate issuance, lookup, restriction, expiry, revocation,
restart, wrong-session, wrong-generation, forged-reference, and deletion cases
and compare the finite-set authority model with BEAM broker decisions.

- [ ] **Subtask 7.2.1.2 Complete**

### Task 7.2.2: Implement Broker and Journal State-Machine Properties

**Description:** Model sessions, grants, budgets, invocations, decisions,
intents, adapter outcomes, results, cancellation, expiry, disablement, crashes,
and recovery as generated command histories.

- [ ] **Task 7.2.2 Complete**

#### Subtask 7.2.2.1: Test Safety Invariants

**Description:** Verify no effect without requirement, grant, decision, and
journaled intent; no budget underflow; no authority widening; no accepted
expired or disabled grant; and no duplicate acknowledged non-idempotent effect.

- [ ] **Subtask 7.2.2.1 Complete**

#### Subtask 7.2.2.2: Test Recovery and Liveness Bounds

**Description:** Verify every recoverable history reaches observed, denied,
cancelled, or explicit uncertain state within bounded steps and never loops in
automatic retry after an ambiguous submission.

- [ ] **Subtask 7.2.2.2 Complete**

## Section 7.3: Adversarial Boundary Testing

**Description:** Attack every parser, serializer, loader, message, policy,
capability, resource, model, and logging boundary with malformed and hostile inputs
under explicit resource limits.

- [ ] **Section 7.3 Complete**

### Task 7.3.1: Fuzz Compiler, Artifact, and ABI Boundaries

**Description:** Fuzz source and JSON parsing, typed IR decoding, Abstract
Format encoding, compiler-bridge frames, BEAM artifact metadata, loader
inspection, and runtime message decoding.

- [ ] **Task 7.3.1 Complete**

#### Subtask 7.3.1.1: Assert Fail-Closed Parsing and Loading

**Description:** Require bounded rejection without panic, VM crash, dynamic
atom growth, partial successful artifacts, or execution of an uninspected
module.

- [ ] **Subtask 7.3.1.1 Complete**

#### Subtask 7.3.1.2: Exercise Size and Complexity Limits

**Description:** Test maximal and over-limit source, AST, IR, forms, modules,
messages, recursion depth, branch count, binaries, and metadata and record CPU,
memory, and diagnostic behavior.

- [ ] **Subtask 7.3.1.2 Complete**

### Task 7.3.2: Attack Authorization, Resource, and Model Boundaries

**Description:** Test privilege, parsing, resolution, replay, path, context,
and disclosure attacks against the complete effect path.

- [ ] **Task 7.3.2 Complete**

#### Subtask 7.3.2.1: Attack Grant and Resource Semantics

**Description:** Cover guessed and altered references, wrong session and
generation, stale grants, scope and budget widening, clock skew, wrong
ownership, traversal, normalization collisions, symlinks, races, and direct
adapter bypass attempts.

- [ ] **Subtask 7.3.2.1 Complete**

#### Subtask 7.3.2.2: Attack Context and Secret Boundaries

**Description:** Insert prompt-injection text in task data, attempt tool and
grant-management escalation through model output, inspect logs and crash
reports, and scan every model-visible or persisted surface for credentials,
opaque references, and broker state.

- [ ] **Subtask 7.3.2.2 Complete**

## Section 7.4: Fault and Performance Characterization

**Description:** Measure how the PoC behaves under BEAM process, port, storage,
and load failures and compare its control-plane costs with a conventional
typed control-flow baseline under the same external adapters.

- [ ] **Section 7.4 Complete**

### Task 7.4.1: Execute the Complete Fault Matrix

**Description:** Kill or disconnect each task, supervisor child, capability
broker, model adapter, workspace adapter, and journal boundary at every
meaningful transition.

- [ ] **Task 7.4.1 Complete**

#### Subtask 7.4.1.1: Verify Process and Port Recovery

**Description:** Confirm local failure containment, restart policy, stale reply
handling, session and capability cleanup, grant restoration, deadline
behavior, and explicit uncertain outcomes.

- [ ] **Subtask 7.4.1.1 Complete**

#### Subtask 7.4.1.2: Verify Durable Effect Recovery

**Description:** Compare journal and adapter state after each fault, prove
acknowledged writes are not duplicated, and ensure unobserved submissions are
reconciled rather than retried blindly.

- [ ] **Subtask 7.4.1.2 Complete**

### Task 7.4.2: Measure Runtime and Authorization Costs

**Description:** Characterize throughput, tail latency, memory, mailbox,
scheduler, broker decision, journal, and recovery costs under bounded
representative loads.

- [ ] **Task 7.4.2 Complete**

#### Subtask 7.4.2.1: Benchmark Control-Plane Operations

**Description:** Measure compile and load time, task start, message round trip,
grant resolution, effect decision, journal transition, adapter execution,
recovery, and completion verification at p50, p95, and p99.

- [ ] **Subtask 7.4.2.1 Complete**

#### Subtask 7.4.2.2: Exercise Resource Pressure and Backpressure

**Description:** Vary running and waiting sessions, slow consumers, mailbox
load, port failure, grant count, binary size, scheduler load, and storage delay
and verify admission and bounded-failure behavior.

- [ ] **Subtask 7.4.2.2 Complete**

## Section 7.5: Phase 7 Integration Tests

**Description:** Run laws, differential tests, attacks, fault injection, and
benchmarks as one reproducible validation campaign and prove that the harness
detects known bad implementations.

- [ ] **Section 7.5 Complete**

### Task 7.5.1: Validate Seeded-Defect Sensitivity

**Description:** Introduce one controlled defect for each principal claim and
require the intended property, differential, adversarial, or fault test to
fail with a minimized or otherwise actionable case.

- [ ] **Task 7.5.1 Complete**

#### Subtask 7.5.1.1: Seed Semantic and Backend Defects

**Description:** Break identity, composition, branch lowering, effect union,
manifest interpretation, serialization, evaluation order, and one runtime ABI
mapping and confirm targeted detection.

- [ ] **Subtask 7.5.1.1 Complete**

#### Subtask 7.5.1.2: Seed Authorization and Recovery Defects

**Description:** Break subset restriction, policy accumulation, expiry,
session and generation binding, revocation, budget atomicity, path containment,
journal ordering, and crash retry and confirm targeted detection.

- [ ] **Subtask 7.5.1.2 Complete**

### Task 7.5.2: Publish the Validation Evidence Set

**Description:** Record commands, seeds, fixture and generated-case counts,
counterexamples, fault matrix, environment, metrics, limits, failures, and
remaining coverage gaps in a reproducible report.

- [ ] **Task 7.5.2 Complete**

#### Subtask 7.5.2.1: Separate Passing Evidence from Open Risk

**Description:** Distinguish tested implementation behavior from mathematical
proof, characterize nondeterministic observations, and preserve every failed
or inconclusive criterion for the final decision.

- [ ] **Subtask 7.5.2.1 Complete**

#### Subtask 7.5.2.2: Run Phase Completion Gates

**Description:** Run all law, differential, fuzz, adversarial, fault,
performance, leak-scan, and complete repository gates and archive exact tool
and runtime versions with the results.

- [ ] **Subtask 7.5.2.2 Complete**

## Phase 7 Completion Evidence

**Description:** Record the complete evidence package that authorizes Phase 8
to judge the architecture against its research hypotheses.

- [ ] Well-typed generators and semantic shrinkers cover the promoted IR
- [ ] Composition, test-view, local restriction, and state-machine properties pass
- [ ] Seeded defects are detected by the intended tests
- [ ] Finite-set authority model and BEAM broker decisions agree
- [ ] Test-only semantic views and compiled BEAM agree within defined observations
- [ ] Adversarial inputs fail closed within declared resource bounds
- [ ] Complete transition fault matrix preserves durable safety invariants
- [ ] Performance and resource results include tails, pressure, and uncertainty
