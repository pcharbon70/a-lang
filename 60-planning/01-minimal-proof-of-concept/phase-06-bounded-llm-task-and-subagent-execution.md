---
title: "Phase 6: Bounded LLM Task and Subagent Execution"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - agent-runtime
  - implementation-planning
  - llm-agents
  - multi-agent-systems
aliases: []
---

# Phase 6: Bounded LLM Task and Subagent Execution

**Description:** This phase integrates the model as a bounded typed effect,
executes deterministic orchestration and limited repair around it, verifies
completion evidence, slices model context, and adds one child task whose
authority is mechanically attenuated without exposing a signing or delegation
primitive.

**Status:** Planned.

**Dependencies:** Phase 5 complete with the pinned UCAN profile, isolated
session keys, subset-preserving Delegations, signed Invocations, dynamic
policy, durable effects, and cross-validator evidence accepted.

## Section 6.1: Provider-Neutral Model Boundary

**Description:** Define one typed, bounded request and response protocol used
by the deterministic fixture adapter and any optional live model provider.

- [ ] **Section 6.1 Complete**

### Task 6.1.1: Define Model Profiles and Structured Results

**Description:** Represent the model, sampling policy, token and time budgets,
input context, requested output schema, provenance, and typed result without
allowing arbitrary provider fields into A-Lang semantics.

- [ ] **Task 6.1.1 Complete**

#### Subtask 6.1.1.1: Define the Bounded Completion Request

**Description:** Include profile ID, ordered context fragments, instruction,
output schema, maximum input and output size, deadline, retry class, and
redaction policy with deterministic canonical encoding.

- [ ] **Subtask 6.1.1.1 Complete**

#### Subtask 6.1.1.2: Define Typed Success and Failure Results

**Description:** Distinguish valid structured output, invalid syntax, schema
failure, content-policy denial, timeout, provider error, budget exhaustion,
and uncertain transport outcome with retained provider metadata.

- [ ] **Subtask 6.1.1.2 Complete**

### Task 6.1.2: Implement Mock and Optional Live Provider Adapters

**Description:** Make offline deterministic fixtures the acceptance path and
place any live provider behind the identical isolated adapter contract.

- [ ] **Task 6.1.2 Complete**

#### Subtask 6.1.2.1: Complete the Deterministic Mock Provider

**Description:** Select responses by canonical request fixture, emit stable
usage and provenance, and cover valid, malformed, timeout, transient,
permanent, and uncertain cases without network or secrets.

- [ ] **Subtask 6.1.2.1 Complete**

#### Subtask 6.1.2.2: Add a Feature-Gated Live Provider

**Description:** If implemented, keep credentials in the adapter process,
enforce the model profile, redact traces, support no arbitrary URL or model
selection, and exclude live nondeterminism from mandatory phase acceptance.

- [ ] **Subtask 6.1.2.2 Complete**

## Section 6.2: Deterministic Task Orchestration and Context Slicing

**Description:** Keep workflow control, budgets, state, and effect order in the
compiled runtime while giving the model only the smallest context needed for
one declared judgment.

- [ ] **Section 6.2 Complete**

### Task 6.2.1: Implement the Minimal Task State Machine

**Description:** Execute prepare-context, request-model, decode, verify-draft,
request-write, verify-artifact, complete, fail, and cancel states as explicit
compiled transitions.

- [ ] **Task 6.2.1 Complete**

#### Subtask 6.2.1.1: Bind State Transitions to Typed Results

**Description:** Require each transition to consume the declared result
variant, reject unexpected replies, persist checkpoints before consequential
effects, and preserve the original goal independently from the current plan.

- [ ] **Subtask 6.2.1.1 Complete**

#### Subtask 6.2.1.2: Enforce Bounds and Stop Conditions

**Description:** Enforce maximum model calls, repair attempts, task steps,
elapsed time, context bytes, output bytes, and effect count and terminate with
a typed incomplete result when a bound is exhausted.

- [ ] **Subtask 6.2.1.2 Complete**

### Task 6.2.2: Implement Capability-Aware Context Slicing

**Description:** Build the model request from the current goal fragment,
relevant typed inputs, allowed action summaries, evidence, and diagnostics
without copying the full proof or runtime state.

- [ ] **Task 6.2.2 Complete**

#### Subtask 6.2.2.1: Define Context Selection Rules

**Description:** Include only declared public or task-local fields, summarize
available effects and constraints, exclude private state and irrelevant
history, and preserve provenance for every included fragment.

- [ ] **Subtask 6.2.2.1 Complete**

#### Subtask 6.2.2.2: Prevent Authority and Instruction Leakage

**Description:** Exclude private keys, raw grants, proof chains, opaque handles,
adapter credentials, unredacted traces, and retrieved text with undeclared
instruction authority from model-visible context.

- [ ] **Subtask 6.2.2.2 Complete**

## Section 6.3: Structured Repair and Completion Verification

**Description:** Use parser and verifier diagnostics to repair only the failed
model-produced fragment and require independent evidence before the task can
report success.

- [ ] **Section 6.3 Complete**

### Task 6.3.1: Implement Bounded Diagnostic Repair

**Description:** Retry only invalid structured model output with the original
schema, the smallest failing fragment, and stable diagnostics under one
explicit repair budget.

- [ ] **Task 6.3.1 Complete**

#### Subtask 6.3.1.1: Classify Repairable and Terminal Failures

**Description:** Permit repair for syntax and schema failures, prohibit blind
retry after uncertain or consequential effects, and route policy, budget,
authorization, and cancellation failures directly to typed termination.

- [ ] **Subtask 6.3.1.1 Complete**

#### Subtask 6.3.1.2: Preserve Repair Provenance

**Description:** Link each repair request and response to its original model
call, diagnostic, attempt number, context digest, and resulting accepted or
rejected fragment.

- [ ] **Subtask 6.3.1.2 Complete**

### Task 6.3.2: Implement Completion Predicates and Witnesses

**Description:** Evaluate machine-checkable success predicates against durable
artifact and trace evidence rather than treating normal termination or model
assertion as completion.

- [ ] **Task 6.3.2 Complete**

#### Subtask 6.3.2.1: Verify the Published Artifact

**Description:** Check expected relative path, existence, digest, byte bound,
UTF-8 and Markdown constraints, nonempty required section, and binding to the
journaled workspace result.

- [ ] **Subtask 6.3.2.1 Complete**

#### Subtask 6.3.2.2: Emit a Completion Witness

**Description:** Record each predicate, its pass or fail result, supporting
artifact or trace references, unresolved uncertainty, and final complete or
incomplete status.

- [ ] **Subtask 6.3.2.2 Complete**

## Section 6.4: Mechanically Attenuated Child Task

**Description:** Demonstrate one parent-to-child task boundary with typed
inputs, reduced context, a narrower capability requirement, an ephemeral
principal, and broker-enforced non-redelegation.

- [ ] **Section 6.4 Complete**

### Task 6.4.1: Define and Spawn the Child Task

**Description:** Extract one bounded drafting or formatting step into a child
task whose interface and requirement are explicit in the parent IR.

- [ ] **Task 6.4.1 Complete**

#### Subtask 6.4.1.1: Define the Child Interface and Context

**Description:** Pass only the required topic, source draft or formatting
input, output schema, completion predicate, and summarized capabilities and
exclude unrelated parent state and proof material.

- [ ] **Subtask 6.4.1.1 Complete**

#### Subtask 6.4.1.2: Create and Supervise the Child Session

**Description:** Allocate a child task ID and ephemeral DID, monitor lifecycle,
propagate deadline and cancellation, correlate the typed result, and discard
late or wrong-session replies.

- [ ] **Subtask 6.4.1.2 Complete**

### Task 6.4.2: Attenuate and Constrain Child Authority

**Description:** Derive the child's grant as a subset of both the parent grant
and child requirement and prevent model-controlled redelegation through signer
custody.

- [ ] **Task 6.4.2 Complete**

#### Subtask 6.4.2.1: Issue the Narrow Child Delegation

**Description:** Narrow operation, resource, arguments, audience, budget, and
expiry; reject any widening; and retain the proof path outside child context.

- [ ] **Subtask 6.4.2.1 Complete**

#### Subtask 6.4.2.2: Deny Arbitrary Subdelegation

**Description:** Expose typed effect invocation only, provide no sign or
delegate operation, and document that this is broker-enforced confinement and
not a protocol guarantee for external key holders.

- [ ] **Subtask 6.4.2.2 Complete**

## Section 6.5: Phase 6 Integration Tests

**Description:** Execute the full deterministic parent-and-child model workflow
through compiled BEAM, UCAN authorization, durable effects, repair, artifact
verification, and completion evidence.

- [ ] **Section 6.5 Complete**

### Task 6.5.1: Validate the Bounded Agent Workflow

**Description:** Demonstrate successful completion and every declared model,
repair, verifier, bound, policy, and child-task failure without letting model
output control orchestration or authority.

- [ ] **Task 6.5.1 Complete**

#### Subtask 6.5.1.1: Run Positive Parent and Child Scenarios

**Description:** Produce the expected artifact and completion witness through
the mock provider, child task, broker, UCAN port, journal, workspace adapter,
and verifier with a causally connected trace.

- [ ] **Subtask 6.5.1.1 Complete**

#### Subtask 6.5.1.2: Run Negative Model and Delegation Scenarios

**Description:** Cover malformed output, exhausted repair, prompt injection in
data, deadline, cancellation, widened child requirement, wrong audience,
attempted redelegation, forged child reply, and failed completion predicate.

- [ ] **Subtask 6.5.1.2 Complete**

### Task 6.5.2: Validate Context and Authority Nonexposure

**Description:** Inspect every parent, child, adapter, log, journal, and trace
surface for prohibited secret, credential, key, proof, handle, or unrelated
context disclosure.

- [ ] **Task 6.5.2 Complete**

#### Subtask 6.5.2.1: Run Model-Visible Data Snapshots

**Description:** Snapshot deterministic parent and child requests, assert
their provenance and minimality, and scan for authority material, hidden
runtime state, and irrelevant private inputs.

- [ ] **Subtask 6.5.2.1 Complete**

#### Subtask 6.5.2.2: Run Phase Completion Gates

**Description:** Run model adapter, task-state, repair, verifier, context,
subagent, attenuation, durable-effect, and complete repository suites and
publish exact step, token, and effect counts.

- [ ] **Subtask 6.5.2.2 Complete**

### Phase 6 Completion Evidence

**Description:** Record the evidence that authorizes Phase 7 to evaluate the
complete PoC rather than isolated compiler or runtime pieces.

- [ ] Deterministic model and optional live adapters share one typed boundary
- [ ] Workflow control, budgets, and repair limits remain runtime-owned
- [ ] Completion depends on verified evidence, not model or process assertion
- [ ] Parent and child context snapshots satisfy declared minimization rules
- [ ] Child authority is mechanically attenuated and cannot sign delegations
- [ ] The full deterministic parent-child artifact scenario passes
