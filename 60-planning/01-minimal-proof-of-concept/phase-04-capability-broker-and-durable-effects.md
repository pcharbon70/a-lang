---
title: "Phase 4: Capability Broker and Durable Effects"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - capability-security
  - durable-execution
  - implementation-planning
  - runtime-systems
aliases: []
---

# Phase 4: Capability Broker and Durable Effects

**Description:** This phase replaces fixture-backed effect replies with an
A-Lang reference monitor, typed effect registry, opaque local capabilities,
stateful budgets, durable intent/result journaling, safe workspace and mock
model adapters, replay control, cancellation, and crash recovery.

**Status:** Planned.

**Dependencies:** Phase 3 complete with validated BEAM artifacts, a closed
runtime ABI, supervised task execution, and reference-to-BEAM differential
agreement accepted.

## Section 4.1: Typed Effect and Resource Registry

**Description:** Define one trusted registry that gives every runtime operation
its typed arguments, canonical resource identity, policy facts, adapter,
idempotency, result, and audit semantics.

- [ ] **Section 4.1 Complete**

### Task 4.1.1: Define the Minimal Effect Catalog

**Description:** Register `Model.complete`, `Workspace.write`, and `Trace.emit`
as the only external or observable PoC effects.

- [ ] **Task 4.1.1 Complete**

#### Subtask 4.1.1.1: Define Typed Intent and Result Schemas

**Description:** Define bounded canonical arguments, results, stable operation
IDs, error variants, redaction rules, and serialization for each effect.

- [ ] **Subtask 4.1.1.1 Complete**

#### Subtask 4.1.1.2: Define Operation Semantics

**Description:** Record preconditions, postconditions, idempotency key rules,
reversibility, compensation limits, retry class, timeout meaning, and
completion evidence for each operation.

- [ ] **Subtask 4.1.1.2 Complete**

### Task 4.1.2: Implement Canonical Resource Resolution

**Description:** Turn typed operation arguments into the exact semantic
resource identity used by requirement matching, policy, authorization,
adapter execution, and audit.

- [ ] **Task 4.1.2 Complete**

#### Subtask 4.1.2.1: Canonicalize Workspace Paths

**Description:** Represent paths as validated relative segments, reject empty,
absolute, traversal, reserved, and oversized forms, and resolve them relative
to an already opened workspace root.

- [ ] **Subtask 4.1.2.1 Complete**

#### Subtask 4.1.2.2: Bind Model and Trace Resources

**Description:** Bind model profile, provider class, maximum calls and tokens,
trace sensitivity, and session ownership to typed identifiers rather than
untrusted strings.

- [ ] **Subtask 4.1.2.2 Complete**

## Section 4.2: Opaque Capability Broker and Stateful Policy

**Description:** Match task requirements against deployment authority and
issue only opaque, session-bound local handles to compiled tasks.

- [ ] **Section 4.2 Complete**

### Task 4.2.1: Implement Requirement-to-Grant Matching

**Description:** Decide whether available deployment authority covers the
normalized task requirement and derive the smallest local grant for one
session.

- [ ] **Task 4.2.1 Complete**

#### Subtask 4.2.1.1: Implement Coverage and Attenuation

**Description:** Check operation, resource, argument bounds, deadline, call,
byte, and token limits and reject any child grant that is not a subset of both
deployment authority and the task requirement.

- [ ] **Subtask 4.2.1.1 Complete**

#### Subtask 4.2.1.2: Issue Opaque Capability References

**Description:** Store authority in broker-owned session state and expose a
random, unforgeable, task-bound `CapabilityRef` whose presentation alone does
not bypass principal, operation, deadline, or argument checks.

- [ ] **Subtask 4.2.1.2 Complete**

### Task 4.2.2: Implement Execution-Time Policy Decisions

**Description:** Validate every typed effect intent against its session grant,
current budgets, deadlines, cancellation state, and authoritative resource
facts immediately before durable submission.

- [ ] **Task 4.2.2 Complete**

#### Subtask 4.2.2.1: Enforce Budgets and Deadlines Transactionally

**Description:** Reserve and settle call, byte, token, and elapsed-time budgets
without check-then-act races and return stable allow, deny, or exhausted
decisions.

- [ ] **Subtask 4.2.2.1 Complete**

#### Subtask 4.2.2.2: Emit Explainable Decisions

**Description:** Record the requirement, grant, current facts, matched rule,
decision, and redacted reason without exposing keys, opaque handle entropy, or
sensitive model and artifact contents.

- [ ] **Subtask 4.2.2.2 Complete**

## Section 4.3: Durable Intent, Result, and Replay State

**Description:** Make effect progress recoverable across process death without
claiming that BEAM supervision or message delivery alone provides durable or
exactly-once execution.

- [ ] **Section 4.3 Complete**

### Task 4.3.1: Implement the Effect Journal State Machine

**Description:** Persist each effect through planned, authorized,
intent-recorded, submitted, observed, uncertain, reconciled, denied, and
cancelled states with monotonic transitions.

- [ ] **Task 4.3.1 Complete**

#### Subtask 4.3.1.1: Define Transaction and Recovery Boundaries

**Description:** Specify which transition precedes adapter submission, how
results bind to intents, what survives crashes, and when a retry is safe,
unsafe, or requires reconciliation.

- [ ] **Subtask 4.3.1.1 Complete**

#### Subtask 4.3.1.2: Implement Durable Storage and Migration Header

**Description:** Store versioned journal records with checksums, ordering,
atomic writes, bounded retention, startup recovery, and an explicit schema
version even though live migration remains deferred.

- [ ] **Subtask 4.3.1.2 Complete**

### Task 4.3.2: Implement Replay and Idempotency Control

**Description:** Ensure duplicate runtime messages, task restarts, and repeated
effect IDs do not repeat an already acknowledged PoC effect.

- [ ] **Task 4.3.2 Complete**

#### Subtask 4.3.2.1: Derive Stable Intent Identities

**Description:** Bind task, operation, canonical arguments, capability
reference, source node, and explicit nonce into an intent identity without
including mutable transport details.

- [ ] **Subtask 4.3.2.1 Complete**

#### Subtask 4.3.2.2: Reuse or Reconcile Existing Results

**Description:** Return the stored result for completed idempotent intents,
deny conflicting nonce reuse, and enter reconciliation rather than blind retry
when submission occurred without an observed result.

- [ ] **Subtask 4.3.2.2 Complete**

## Section 4.4: Isolated Effect Adapters

**Description:** Execute model and workspace operations outside generated task
code through bounded adapters that share the registry's canonical semantics.

- [ ] **Section 4.4 Complete**

### Task 4.4.1: Implement the Safe Workspace Adapter

**Description:** Write bounded content beneath one configured workspace root
using canonical path segments and return a verified artifact reference.

- [ ] **Task 4.4.1 Complete**

#### Subtask 4.4.1.1: Enforce Filesystem Containment

**Description:** Use descriptor-relative operations where available, reject
symlink and traversal escapes, avoid ambient current-directory authority, and
verify the final target remains under the configured root.

- [ ] **Subtask 4.4.1.1 Complete**

#### Subtask 4.4.1.2: Record and Verify Artifact Results

**Description:** Bound bytes, write through an atomic temporary-to-final
transition, calculate digest and size, and return an `ArtifactRef` whose
metadata can be checked independently.

- [ ] **Subtask 4.4.1.2 Complete**

### Task 4.4.2: Implement the Deterministic Model and Trace Adapters

**Description:** Provide offline model responses and structured traces through
the same port or sidecar boundary later used by live integrations.

- [ ] **Task 4.4.2 Complete**

#### Subtask 4.4.2.1: Implement Fixture-Driven Model Completion

**Description:** Match a typed request to a versioned fixture, enforce request
and response limits, return deterministic structured output, and support
declared timeout, malformed, and transient-failure cases.

- [ ] **Subtask 4.4.2.1 Complete**

#### Subtask 4.4.2.2: Implement Redacted Trace Collection

**Description:** Collect source, task, effect, decision, journal, adapter, and
verifier events with correlation and causal ordering while redacting content
and authority material according to the registry.

- [ ] **Subtask 4.4.2.2 Complete**

## Section 4.5: Phase 4 Integration Tests

**Description:** Execute the compiled demo through the local broker and real
durable adapters, then inject denials, duplicate messages, timeouts, and
process failures at every effect transition.

- [ ] **Section 4.5 Complete**

### Task 4.5.1: Validate Authorized Durable Effects

**Description:** Demonstrate one model response and one workspace write with
typed arguments, least local authority, transactional budgets, durable intent,
verified result, and a complete trace.

- [ ] **Task 4.5.1 Complete**

#### Subtask 4.5.1.1: Run Positive End-to-End Local Authority

**Description:** Compile, load, run, authorize, submit, observe, verify, and
complete the deterministic example and compare its normalized observations
with the reference evaluator.

- [ ] **Subtask 4.5.1.1 Complete**

#### Subtask 4.5.1.2: Run Policy and Containment Denials

**Description:** Deny wrong operation, wrong task, forged handle, exhausted
budget, expired deadline, oversized model request, oversized write, absolute
path, traversal, symlink escape, and cancelled work.

- [ ] **Subtask 4.5.1.2 Complete**

### Task 4.5.2: Validate Recovery and Deduplication

**Description:** Kill task, gateway, adapter, and journal-facing workers around
each transition and verify the recovered state follows the specified retry or
reconciliation rule.

- [ ] **Task 4.5.2 Complete**

#### Subtask 4.5.2.1: Execute Transition Fault Matrix

**Description:** Inject death before and after authorization, intent recording,
submission, external mutation, result observation, result recording, and task
reply.

- [ ] **Subtask 4.5.2.1 Complete**

#### Subtask 4.5.2.2: Run Phase Completion Gates

**Description:** Run broker, registry, journal, adapter, containment, replay,
fault-injection, differential, and complete repository suites and publish
duplicate-effect and recovery counts.

- [ ] **Subtask 4.5.2.2 Complete**

### Phase 4 Completion Evidence

**Description:** Record the evidence that authorizes Phase 5 to replace local
broker authority with portable UCAN-backed proofs without changing effect
semantics.

- [ ] Typed registry and canonical resource identity agree across all layers
- [ ] Tasks receive only opaque, session-bound capability references
- [ ] Budgets, deadlines, cancellation, and denials are enforced at execution
- [ ] Journal recovery survives the complete transition fault matrix
- [ ] Replayed or duplicated intents do not repeat an acknowledged write
- [ ] Workspace containment and deterministic model tests pass
