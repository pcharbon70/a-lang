---
title: "Phase 4: Local Capability Broker and Effect Boundary"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - beam
  - capability-security
  - effect-systems
  - implementation-planning
aliases: []
---

# Phase 4: Local Capability Broker and Effect Boundary

**Description:** This phase introduces the smallest trusted effect path for
BEAM-executed A-Lang processes. Generated code can request only closed,
statically declared operations; a supervised BEAM broker resolves opaque local
references, validates typed arguments and dynamic policy, and calls one
OS-bounded adapter without portable delegation or ambient authority.

**Status:** In progress — Sections 4.1–4.2 have reproducible implementation evidence.

**Dependencies:** Phase 3 complete with generated A-Lang modules executing as
supervised BEAM processes through a versioned runtime ABI, bounded mailboxes,
classified failures, and inspected artifact imports.

## Section 4.1: Closed Effect Registry

**Description:** Define a single source of truth connecting language effects,
typed arguments, required authority, runtime operations, adapters, and
observable results.

- [x] **Section 4.1 Complete** — evidence: [closed effect registry](../../src/phase-04/alang_phase4_effect_registry.erl) and [registry contract tests](../../src/phase-04/alang_phase4_effect_registry_tests.erl)

### Task 4.1.1: Define Stable Effect Identities

**Description:** Assign compiler-known identifiers and schemas to every effect
in the proof of concept so generated code never selects arbitrary modules or
functions.

- [x] **Task 4.1.1 Complete** — evidence: [stable registry identities and schemas](../../src/phase-04/alang_phase4_effect_registry.erl)

#### Subtask 4.1.1.1: Register the Initial Operations

**Description:** Register model completion and one workspace write operation
with closed request, success, denial, timeout, cancellation, and failure
variants.

- [x] **Subtask 4.1.1.1 Complete** — evidence: model completion and workspace write definitions in the [closed registry](../../src/phase-04/alang_phase4_effect_registry.erl)

#### Subtask 4.1.1.2: Generate Compiler and Runtime Views

**Description:** Derive type-checker signatures, manifest declarations, broker
decoders, adapter dispatch, and trace names from the same registry definition.

- [x] **Subtask 4.1.1.2 Complete** — evidence: [derived-view consistency tests](../../src/phase-04/alang_phase4_effect_registry_tests.erl)

### Task 4.1.2: Enforce Typed Effect Requests

**Description:** Make every request a versioned value whose resource and
arguments are decoded before policy evaluation or adapter dispatch.

- [x] **Task 4.1.2 Complete** — evidence: [versioned request decoder and manifest binder](../../src/phase-04/alang_phase4_effect_registry.erl)

#### Subtask 4.1.2.1: Reject Dynamic Dispatch Inputs

**Description:** Reject user-controlled module names, function names, atoms,
adapter identifiers, unknown fields, oversized binaries, and schema versions
outside the registry.

- [x] **Subtask 4.1.2.1 Complete** — evidence: [dynamic-dispatch, schema, bounds, and atom-safety tests](../../src/phase-04/alang_phase4_effect_registry_tests.erl)

#### Subtask 4.1.2.2: Bind Requests to Artifact Manifests

**Description:** Deny any operation absent from the loaded artifact's effect
manifest even when a session happens to hold a broader runtime grant.

- [x] **Subtask 4.1.2.2 Complete** — evidence: [independent artifact-manifest upper-bound tests](../../src/phase-04/alang_phase4_effect_registry_tests.erl)

## Section 4.2: Opaque Local Capability References

**Description:** Represent runtime authority as broker-owned state addressed by
unforgeable, process-local references with no portable or self-certifying wire
meaning.

- [x] **Section 4.2 Complete** — evidence: [opaque grant store](../../src/phase-04/alang_phase4_grants.erl) and [grant law and lifetime tests](../../src/phase-04/alang_phase4_grants_tests.erl)

### Task 4.2.1: Define Grant State and Restriction Laws

**Description:** Model each grant as a set of permitted typed invocations plus
resource scope, budgets, deadlines, owner, lifecycle, and revocation state.

- [x] **Task 4.2.1 Complete** — evidence: [structural invocation sets, shared budgets, and restriction laws](../../src/phase-04/alang_phase4_grants.erl)

#### Subtask 4.2.1.1: Specify Local Least Authority

**Description:** Require a granted invocation set to be a subset of the parent
session authority and make every narrowing operation monotonically reduce or
preserve that set.

- [x] **Subtask 4.2.1.1 Complete** — evidence: [generated monotone-restriction tests](../../src/phase-04/alang_phase4_grants_tests.erl)

#### Subtask 4.2.1.2: Specify Combination and Revocation

**Description:** Define when local grants may combine, how budgets compose,
how revocation invalidates descendants, and how stale references fail without
revealing broker state.

- [x] **Subtask 4.2.1.2 Complete** — evidence: [policy-gated intersection, shared-budget, and descendant-revocation tests](../../src/phase-04/alang_phase4_grants_tests.erl)

### Task 4.2.2: Issue and Resolve Opaque References

**Description:** Create high-entropy references inside the trusted broker and
bind them to one session, artifact, process lineage, and runtime instance.

- [x] **Task 4.2.2 Complete** — evidence: [broker-local opaque reference issuance and resolution](../../src/phase-04/alang_phase4_grants.erl)

#### Subtask 4.2.2.1: Prevent Reference Forgery and Leakage

**Description:** Keep broker state out of A-Lang values, prompts, model
responses, logs, traces, artifacts, and external adapter payloads; expose only
redacted reference identifiers where correlation is necessary.

- [x] **Subtask 4.2.2.1 Complete** — evidence: [unique-reference and redacted-description tests](../../src/phase-04/alang_phase4_grants_tests.erl)

#### Subtask 4.2.2.2: Bind References to Runtime Lifetimes

**Description:** Reject references presented by the wrong node, session,
artifact, process lineage, or runtime generation and remove them when their
owner terminates or their deadline expires.

- [x] **Subtask 4.2.2.2 Complete** — evidence: [node, runtime, generation, session, artifact, owner, task, presenter, expiry, and owner-removal checks](../../src/phase-04/alang_phase4_grants_tests.erl)

## Section 4.3: Supervised BEAM Reference Monitor

**Description:** Implement authorization and dispatch as an explicit BEAM
process boundary with bounded requests, observable decisions, and fail-closed
restart behavior.

- [ ] **Section 4.3 Complete**

### Task 4.3.1: Implement the Broker Decision Pipeline

**Description:** Evaluate request decoding, manifest allowance, reference
resolution, ownership, resource scope, budget, deadline, cancellation, and
policy in a fixed order before dispatch.

- [ ] **Task 4.3.1 Complete**

#### Subtask 4.3.1.1: Return Typed Decision Reasons

**Description:** Produce stable allow and denial variants that separate bad
input, undeclared effect, unknown grant, scope mismatch, exhausted budget,
expired deadline, cancellation, and policy failure.

- [ ] **Subtask 4.3.1.1 Complete**

#### Subtask 4.3.1.2: Emit Redacted Authorization Events

**Description:** Record correlation identifiers, effect identity, normalized
resource, decision class, policy version, and remaining budget without logging
secrets, raw capability references, or prompt content.

- [ ] **Subtask 4.3.1.2 Complete**

### Task 4.3.2: Supervise and Bound the Broker

**Description:** Give the broker an explicit supervision strategy, queue
limits, timeouts, overload behavior, and restart contract that cannot widen
authority after failure.

- [ ] **Task 4.3.2 Complete**

#### Subtask 4.3.2.1: Enforce Admission and Backpressure

**Description:** Bound outstanding decisions and adapter calls per session and
globally, reject excess work predictably, and keep one tenant from starving
unrelated BEAM processes.

- [ ] **Subtask 4.3.2.1 Complete**

#### Subtask 4.3.2.2: Fail Closed Across Broker Restarts

**Description:** Start a restarted broker with no implicit grants, require
explicit state restoration in Phase 5, and classify in-flight requests as
unknown rather than replaying them automatically.

- [ ] **Subtask 4.3.2.2 Complete**

## Section 4.4: Isolated Effect Adapter

**Description:** Exercise one real external effect through a narrow adapter
boundary while treating BEAM process isolation as orchestration rather than a
security sandbox.

- [ ] **Section 4.4 Complete**

### Task 4.4.1: Implement the Workspace Adapter Contract

**Description:** Accept only normalized workspace identifiers, relative path
segments, bounded bytes, an operation identifier, and a deadline, and return a
typed result with an artifact digest.

- [ ] **Task 4.4.1 Complete**

#### Subtask 4.4.1.1: Enforce Filesystem Scope

**Description:** Reject absolute paths, traversal, symlink escape, wrong
workspace identity, oversized content, special files, and destinations outside
the broker-authorized root.

- [ ] **Subtask 4.4.1.1 Complete**

#### Subtask 4.4.1.2: Define Idempotent Operation Identity

**Description:** Require a stable operation identifier and make repeated calls
with the same identifier and payload observable as the same logical attempt,
without yet claiming crash-safe durability.

- [ ] **Subtask 4.4.1.2 Complete**

### Task 4.4.2: Isolate Adapter Failure and Resource Use

**Description:** Run the adapter through the narrowest practical OS boundary
with explicit CPU, memory, filesystem, output, and time limits.

- [ ] **Task 4.4.2 Complete**

#### Subtask 4.4.2.1: Frame and Validate Adapter Messages

**Description:** Use length-bounded frames, reject malformed responses, map
adapter exits to typed failures, and prevent protocol desynchronization from
corrupting the broker mailbox.

- [ ] **Subtask 4.4.2.1 Complete**

#### Subtask 4.4.2.2: Contain Crashes and Timeouts

**Description:** Kill and replace stuck adapter workers without crashing the
session coordinator or treating an unknown external outcome as a successful
effect.

- [ ] **Subtask 4.4.2.2 Complete**

## Section 4.5: Capability and Effect Integration Test

**Description:** Prove that a compiled A-Lang process can exercise exactly one
authorized workspace effect through the BEAM broker and cannot bypass or widen
that authority.

- [ ] **Section 4.5 Complete**

### Task 4.5.1: Run the Authorized Effect Path

**Description:** Load the compiled artifact, issue a minimal local grant, send
the typed effect request, authorize it in the broker, execute the adapter, and
return the artifact digest to the originating BEAM process.

- [ ] **Task 4.5.1 Complete**

#### Subtask 4.5.1.1: Verify the Successful Trace

**Description:** Assert the request, decision, adapter, result, budget, trace,
and process events and prove that the output exists only at the authorized
workspace path.

- [ ] **Subtask 4.5.1.1 Complete**

#### Subtask 4.5.1.2: Verify BEAM Ownership and Dispatch

**Description:** Show that the requesting A-Lang program, session coordinator,
and broker are BEAM processes and that no host interpreter or direct generated
module call performs the external effect.

- [ ] **Subtask 4.5.1.2 Complete**

### Task 4.5.2: Run Least-Authority Rejection Cases

**Description:** Exercise forged, stale, wrong-session, overbroad, exhausted,
expired, revoked, and undeclared requests plus direct adapter and module-call
bypass attempts.

- [ ] **Task 4.5.2 Complete**

#### Subtask 4.5.2.1: Assert No Unauthorized Side Effect

**Description:** Verify the workspace and adapter logs remain unchanged for
every denied request and that retries cannot turn a denial into execution.

- [ ] **Subtask 4.5.2.1 Complete**

#### Subtask 4.5.2.2: Assert Stable Failure Evidence

**Description:** Check that each rejection produces the expected typed result,
redacted audit event, unchanged budget where appropriate, and healthy BEAM
supervision tree.

- [ ] **Subtask 4.5.2.2 Complete**

## Phase 4 Completion Evidence

**Description:** Phase 4 is complete only when the repository contains
reproducible evidence for all items below.

- [ ] The effect registry generates consistent compiler, manifest, broker, and adapter views
- [ ] Generated BEAM code can request only manifest-declared operations through the ABI
- [ ] Opaque grants are local, unforgeable, scoped, bounded, expiring, and revocable
- [ ] Broker decisions are typed, ordered, redacted, supervised, and fail closed
- [ ] The workspace adapter enforces path and resource isolation
- [ ] The authorized end-to-end effect succeeds only through the BEAM broker
- [ ] Forgery, scope escape, exhaustion, expiry, revocation, and bypass cases cause no effect
- [ ] No portable authorization protocol is required or implemented
