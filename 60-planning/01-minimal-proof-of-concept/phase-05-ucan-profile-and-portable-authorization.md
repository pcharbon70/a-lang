---
title: "Phase 5: UCAN Profile and Portable Authorization"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - authorization
  - capability-security
  - implementation-planning
  - ucan
aliases: []
---

# Phase 5: UCAN Profile and Portable Authorization

**Description:** This phase defines a version-pinned A-Lang UCAN profile,
resolves proof-order interoperability, isolates keys and signing behind a
bounded port, creates ephemeral session principals, maps typed requirements to
attenuated Delegations, signs concrete Invocations, and integrates proof,
replay, cache, and local-policy validation with the durable broker.

**Status:** Planned.

**Dependencies:** Phase 4 complete with a correct local capability broker,
canonical resource registry, durable effect journal, replay protection, and
fault-tested workspace and mock-model adapters accepted.

## Section 5.1: Pinned UCAN Profile and Conformance Fixtures

**Description:** Freeze the exact specification commits, encodings,
algorithms, limits, proof ordering, and unsupported features that define
`alang-ucan-profile/0`.

- [ ] **Section 5.1 Complete**

### Task 5.1.1: Publish the A-Lang UCAN Profile

**Description:** Define a narrow Delegation and Invocation compatibility
profile that can be implemented and rejected consistently across languages.

- [ ] **Task 5.1.1 Complete**

#### Subtask 5.1.1.1: Pin Normative Inputs and Algorithms

**Description:** Record exact high-level, Delegation, Invocation, container,
and implementation commits; permit only DAG-CBOR, CIDv1, SHA-256, Varsig,
Ed25519, and `did:key` initially.

- [ ] **Subtask 5.1.1.1 Complete**

#### Subtask 5.1.1.2: Bound and Forbid Profile Features

**Description:** Require finite expiry and conservative byte, proof, policy,
selector, argument, and resolution limits while forbidding Powerline, root `/`
grants, unknown algorithms, Promise, Receipt, and RC Revocation in the
normative PoC path.

- [ ] **Subtask 5.1.1.2 Complete**

### Task 5.1.2: Resolve Proof Order and Publish Fixtures

**Description:** Establish one canonical proof order despite the current
difference between Invocation prose and Go validator behavior.

- [ ] **Task 5.1.2 Complete**

#### Subtask 5.1.2.1: Obtain or Record the Normative Decision

**Description:** Seek official specification or fixture clarification; if none
is available, document the PoC choice, supporting evidence, interoperability
impact, and issue that prevents calling it generally compliant.

- [ ] **Subtask 5.1.2.1 Complete**

#### Subtask 5.1.2.2: Create Positive and Negative Cross-Validator Vectors

**Description:** Publish canonical bytes, CIDs, signatures, proof bundles,
expected decisions, and opposite-order rejection cases for Rust, Go, and the
A-Lang gateway.

- [ ] **Subtask 5.1.2.2 Complete**

## Section 5.2: Principal, Key, and Proof Services

**Description:** Keep all private keys and raw proof material outside compiled
tasks and model-visible context while making signing and resolution available
through a minimal auditable service.

- [ ] **Section 5.2 Complete**

### Task 5.2.1: Implement the Isolated UCAN Port Service

**Description:** Wrap the selected Rust UCAN library behind a framed,
versioned, resource-bounded port protocol that signs, parses, resolves, and
validates but never executes an effect.

- [ ] **Task 5.2.1 Complete**

#### Subtask 5.2.1.1: Define the Port Request and Response API

**Description:** Support create-session-key, sign-delegation,
sign-invocation, validate, compute-CID, inspect, and destroy-session operations
with typed success and stable failure categories.

- [ ] **Subtask 5.2.1.1 Complete**

#### Subtask 5.2.1.2: Enforce Parser and Service Bounds

**Description:** Bound frame, token, container, decompression, proof depth,
policy tree, DID, CPU, memory, and wall time; crash or restart the port without
crashing ERTS or losing broker state.

- [ ] **Subtask 5.2.1.2 Complete**

### Task 5.2.2: Implement Principal and Proof Lifecycles

**Description:** Create deployment and ephemeral session principals, retain
keys only in the port service, and manage content-addressed proofs and expiry
indexes in broker-owned storage.

- [ ] **Task 5.2.2 Complete**

#### Subtask 5.2.2.1: Create Ephemeral Session DIDs

**Description:** Generate one Ed25519 `did:key` principal per agent session,
bind it to the task and runtime session, destroy its signing handle at session
termination, and never equate a DID with a BEAM PID.

- [ ] **Subtask 5.2.2.1 Complete**

#### Subtask 5.2.2.2: Implement the Bounded Proof Store

**Description:** Store canonical token bytes by computed CID, resolve only
within an attached container or authenticated local store, index expiry and
dependencies, reject missing proofs, and garbage-collect expired state.

- [ ] **Subtask 5.2.2.2 Complete**

## Section 5.3: Requirement-to-Delegation and Intent-to-Invocation Mapping

**Description:** Add UCAN as one backend interpretation of A-Lang authority
without changing the typed requirement or local decision semantics from Phase
4.

- [ ] **Section 5.3 Complete**

### Task 5.3.1: Compile Typed Requirements into Delegation Claims

**Description:** Map operation IDs, canonical resources, argument constraints,
audience, and time bounds into the fixed UCAN subject, command, and policy
profile.

- [ ] **Task 5.3.1 Complete**

#### Subtask 5.3.1.1: Define the Command and Policy Registry

**Description:** Assign fixed command paths for model, workspace, and trace
operations and define a total mapping from typed normalized constraints to the
safe profile policy subset.

- [ ] **Subtask 5.3.1.1 Complete**

#### Subtask 5.3.1.2: Issue Short Attenuated Delegations

**Description:** Derive a session grant that is a subset of deployment
authority and the task requirement, bind it to the session DID, impose a short
expiry, calculate its CID, and store its complete proof path.

- [ ] **Subtask 5.3.1.2 Complete**

### Task 5.3.2: Construct Signed Invocations from Durable Intents

**Description:** Turn a typed, canonical, locally authorized effect intent into
a short-lived signed Invocation that identifies the exact operation,
arguments, proof path, and replay identity.

- [ ] **Task 5.3.2 Complete**

#### Subtask 5.3.2.1: Bind Canonical Arguments and Intent Identity

**Description:** Use the registry's exact canonical argument representation,
bind large content by digest and size when appropriate, and align invocation
nonce and task identity with the durable journal's replay semantics.

- [ ] **Subtask 5.3.2.1 Complete**

#### Subtask 5.3.2.2: Sign Without Exposing General Authority

**Description:** Permit the broker to sign only an invocation matching the
task's stored grant and intent, and expose neither the session private key nor
an arbitrary sign or delegate operation to the task process or model.

- [ ] **Subtask 5.3.2.2 Complete**

## Section 5.4: Execution-Time Validation and Status State

**Description:** Validate portable proof at the effect boundary and then apply
the same authoritative resource, budget, cancellation, and journal checks
that remain outside UCAN.

- [ ] **Section 5.4 Complete**

### Task 5.4.1: Integrate UCAN Validation with Broker Decisions

**Description:** Verify canonical encoding, CID, signature, principal chain,
subject, command coverage, accumulated policies, time bounds, proof
availability, resource ownership, and local state immediately before effect
submission.

- [ ] **Task 5.4.1 Complete**

#### Subtask 5.4.1.1: Produce a Normalized Authorization Fact

**Description:** Return only validated subject, invoker, command, canonical
arguments, proof CIDs, and expiry to the broker and keep parsing and
cryptographic details outside adapter execution.

- [ ] **Subtask 5.4.1.1 Complete**

#### Subtask 5.4.1.2: Reapply Dynamic A-Lang Policy

**Description:** Check workspace ownership, path containment, budgets,
deadlines, cancellation, and current journal state after UCAN validation and
before recording submission.

- [ ] **Subtask 5.4.1.2 Complete**

### Task 5.4.2: Integrate Replay, Cache, and Grant Status

**Description:** Coordinate UCAN CID uniqueness, invocation replay state,
validation memoization, expiry, and A-Lang-managed grant disablement without
depending on RC Revocation for correctness.

- [ ] **Task 5.4.2 Complete**

#### Subtask 5.4.2.1: Implement Seen-CID and Validation Caches

**Description:** Record non-idempotent invocation identities durably, cache
only validated dependencies, index them by expiry and proof CID, and invalidate
derived decisions whenever a dependency becomes unusable.

- [ ] **Subtask 5.4.2.1 Complete**

#### Subtask 5.4.2.2: Implement Online Grant Disablement

**Description:** Let the broker reject a locally disabled grant immediately,
show that this is an online A-Lang policy rather than distributed UCAN
revocation, and retain short expiry as the offline exposure bound.

- [ ] **Subtask 5.4.2.2 Complete**

## Section 5.5: Phase 5 Integration Tests

**Description:** Demonstrate portable authorization for the existing durable
effect path and prove that cryptographic validity never bypasses resource,
stateful policy, replay, or journal checks.

- [ ] **Section 5.5 Complete**

### Task 5.5.1: Validate Delegation and Invocation Interoperability

**Description:** Create, serialize, sign, resolve, and validate the PoC grant
and invocation across independent implementations and the BEAM gateway.

- [ ] **Task 5.5.1 Complete**

#### Subtask 5.5.1.1: Run Positive Cross-Implementation Fixtures

**Description:** Confirm canonical bytes, CIDs, proof order, signatures,
subjects, audiences, commands, policies, arguments, and time decisions agree
for the final scenario.

- [ ] **Subtask 5.5.1.1 Complete**

#### Subtask 5.5.1.2: Run Negative Proof and Policy Fixtures

**Description:** Deny wrong order, missing proof, altered bytes, bad signature,
wrong subject or audience, expanded command, relaxed policy, expired time,
unsupported algorithm, replay, and locally disabled grant.

- [ ] **Subtask 5.5.1.2 Complete**

### Task 5.5.2: Validate Key Isolation and Durable Integration

**Description:** Execute the workspace effect through UCAN while proving that
compiled tasks and model-visible traces cannot obtain keys, raw broad grants,
or an arbitrary signer.

- [ ] **Task 5.5.2 Complete**

#### Subtask 5.5.2.1: Inspect Runtime Authority Surfaces

**Description:** Audit messages, process state, logs, crash reports, journals,
and model context for private keys, handle entropy, root grants, Powerline,
and unrestricted delegation operations.

- [ ] **Subtask 5.5.2.1 Complete**

#### Subtask 5.5.2.2: Run Phase Completion Gates

**Description:** Run profile fixtures, cross-validator, port isolation,
proof-store, policy, replay, cache, durable-effect, fault, and complete
repository suites and publish exact pinned versions.

- [ ] **Subtask 5.5.2.2 Complete**

### Phase 5 Completion Evidence

**Description:** Record the evidence that authorizes Phase 6 to give bounded
LLM and child-task execution access to portable authority through the broker.

- [ ] `alang-ucan-profile/0` and proof-order decision published
- [ ] Independent validators agree on positive and negative fixtures
- [ ] Keys and proof material remain isolated behind the port and broker
- [ ] Typed requirements lower to subset-preserving Delegations
- [ ] Durable intents lower to signed, replay-controlled Invocations
- [ ] UCAN and dynamic A-Lang policy jointly gate the existing effect path
