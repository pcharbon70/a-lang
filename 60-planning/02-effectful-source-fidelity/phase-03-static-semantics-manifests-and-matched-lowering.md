---
title: "Phase 3: Static Semantics, Manifests, and Matched Lowering"
kind: note
created: 2026-08-05
maturity: developing
tags:
  - beam
  - compiler-design
  - effect-systems
  - implementation-planning
  - typed-ir
aliases: []
---

# Phase 3: Static Semantics, Manifests, and Matched Lowering

**Description:** Implement the BEAM-resident resolver, type/effect checker,
authority and limit analysis, typed-JSON control frontend, and deterministic
lowering that make the two representation conditions semantically comparable.
Both paths must produce the same validated `alang_typed_task_ir_v2` meaning
without accepting manually constructed IR as campaign input.

**Status:** Planned; every item remains unchecked until reproducible evidence
exists.

**Dependencies:** Phase 1 has frozen the paired semantics and JSON schema;
Phase 2 produces validated `alang_source_ast_v2` with exact origins. Existing
Phase 3–6 contracts define the backend nodes, registry operations, grants,
durability, repair, child attenuation, and completion behavior to preserve.

## Section 3.1: Typed-JSON Control Frontend

**Description:** Decode the conventional control through an independent,
bounded BEAM frontend while converging on the same checked semantic model as
A-Lang.

- [ ] **Section 3.1 Complete**

### Task 3.1.1: Decode and Validate `alang-task-json-v1`

**Description:** Use OTP JSON with duplicate-aware object handling, explicit
depth/size/list bounds, exact schema fields, and JSON-pointer origins; never
decode arbitrary ETF or create atoms from input strings.

- [ ] **Task 3.1.1 Complete**

#### Subtask 3.1.1.1: Preserve Duplicate and Origin Evidence

**Description:** Retain object-member order long enough to reject duplicate
semantic keys and attach a stable JSON pointer plus byte offset to every
decoded declaration and expression before converting closed tags through an
allowlist.

- [ ] **Subtask 3.1.1.1 Complete**

#### Subtask 3.1.1.2: Reject IR and Runtime Escape Fields

**Description:** Deny node IDs, Abstract Format, module/function names,
adapter/endpoint selection, credentials, capability handles, process terms,
raw grants, operation identities, and any unknown field instead of treating
JSON as a direct IR or runtime command channel.

- [ ] **Subtask 3.1.1.2 Complete**

### Task 3.1.2: Normalize JSON into the Shared Checked Input

**Description:** Translate only schema-valid JSON declarations into the same
representation-neutral semantic input used by the A-Lang checker, preserving
JSON origins for diagnostics but no condition-specific execution behavior.

- [ ] **Task 3.1.2 Complete**

#### Subtask 3.1.2.1: Map Closed JSON Forms to Semantic Forms

**Description:** Map built-in types, sequential binding, result matching,
registered effects, limits, child restrictions, and artifact completion to
closed semantic tags with exactly the same defaults and required fields as v2
source.

- [ ] **Subtask 3.1.2.1 Complete**

#### Subtask 3.1.2.2: Produce JSON-Local Diagnostics

**Description:** Report stable codes at the smallest JSON pointer for invalid
types, unknown names, malformed operations, widened child authority, unsafe
paths, and limit violations without mentioning A-Lang grammar or backend terms.

- [ ] **Subtask 3.1.2.2 Complete**

## Section 3.2: Shared Name, Type, Control, and Completion Semantics

**Description:** Resolve and check both frontends through one semantic core so
the comparison cannot hide different acceptance rules behind the two surfaces.

- [ ] **Section 3.2 Complete**

### Task 3.2.1: Resolve Tasks, Bindings, Calls, and Branches

**Description:** Assign stable binary task and binding identities, resolve only
statically named local tasks and registered intrinsics, and enforce lexical
scope and total result branches.

- [ ] **Task 3.2.1 Complete**

#### Subtask 3.2.1.1: Reject Duplicate and Unresolved Identities

**Description:** Detect duplicate tasks, parameters, bindings, named arguments,
and child names plus unresolved variables or task references without creating
source-controlled atoms or falling back to dynamic dispatch.

- [ ] **Subtask 3.2.1.1 Complete**

#### Subtask 3.2.1.2: Prove Sequential and Branch Reachability

**Description:** Require each binding to dominate its uses, each result match
to cover `ok` and `error` exactly once, each branch to terminate in the
declared result type, and each task to have a finite acyclic call/delegation
graph.

- [ ] **Subtask 3.2.1.2 Complete**

### Task 3.2.2: Check Data, Operations, and Completion Specifications

**Description:** Type built-in values, results, task calls, effect arguments,
child inputs/outputs, and completion fields against closed compiler-owned
contracts.

- [ ] **Task 3.2.2 Complete**

#### Subtask 3.2.2.1: Type the Effectful Expression Surface

**Description:** Check `Int`, `Bool`, `Binary`, built-in `Result`, sequential
bindings, result arms, local task calls, `model.complete`, and
`workspace.write`; reject implicit conversions, exception-like errors, and
branch result disagreement.

- [ ] **Subtask 3.2.2.1 Complete**

#### Subtask 3.2.2.2: Validate Child and Artifact Contracts Statically

**Description:** Require delegated task signatures and attenuated limits to be
closed subsets of the parent, and validate completion paths, canonical digest,
byte bound, UTF-8/Markdown predicates, required section, and journal binding
before lowering.

- [ ] **Subtask 3.2.2.2 Complete**

## Section 3.3: Effect, Authority, Limit, and IR Derivation

**Description:** Infer the complete static manifest and lower checked semantics
to one versioned IR whose meaning is independent of source notation.

- [ ] **Section 3.3 Complete**

### Task 3.3.1: Infer Effects, Requirements, and Bounds

**Description:** Calculate operations and maximum sequential/branch usage from
the finite graph, compare them with declarations, map registered operations to
requirements, and produce the least static runtime manifest.

- [ ] **Task 3.3.1 Complete**

#### Subtask 3.3.1.1: Require Declared and Inferred Authority Equality

**Description:** Reject undeclared effects, unused authority, missing or extra
requirements, dynamic resources, and registry mismatches; derive model and
workspace resource selectors without embedding a grant or credential.

- [ ] **Subtask 3.3.1.1 Complete**

#### Subtask 3.3.1.2: Prove Limits Cover the Static Upper Bound

**Description:** Count effect, repair, child, workspace, and step sites along
the maximum reachable branch, require declared ceilings to cover that bound,
and require child ceilings and deadlines to be no greater than the parent's.

- [ ] **Subtask 3.3.1.2 Complete**

### Task 3.3.2: Lower Both Conditions to `alang_typed_task_ir_v2`

**Description:** Extend the existing IR with versioned task limits, one closed
delegate node, and a structured completion specification while preserving all
v1 data, result, call, sequence, effect-request, and verifier semantics.

- [ ] **Task 3.3.2 Complete**

#### Subtask 3.3.2.1: Produce Stable Nodes, Manifests, and Source Maps

**Description:** Assign deterministic preorder identities, retain frontend-local
origins in separate source maps, attach the inferred manifest and limits, and
encode the normalized IR with deterministic ETF. Record closed effect-site
ordinals from which trusted runtime state can derive operation identities;
never accept an identity supplied by either frontend.

- [ ] **Subtask 3.3.2.1 Complete**

#### Subtask 3.3.2.2: Enforce the No-Manual-IR Campaign Gate

**Description:** Require each campaign artifact to cite an accepted source or
JSON digest, frontend identity, and normalized semantic digest; reject direct
IR files, fixture constructors, reference evaluators, and missing provenance
from acceptance execution.

- [ ] **Subtask 3.3.2.2 Complete**

## Section 3.4: Phase 3 Integration Tests

**Description:** Prove both frontends accept and reject the same semantics,
derive the same authority, and lower every frozen pair to one normalized IR
meaning.

- [ ] **Section 3.4 Complete**

### Task 3.4.1: Run Paired Differential and Negative Suites

**Description:** Check all 24 representation pairs plus seeded name, type,
effect, limit, child, path, and completion violations through both frontend
paths.

- [ ] **Task 3.4.1 Complete**

#### Subtask 3.4.1.1: Require Pairwise Semantic Digest Equality

**Description:** Strip representation-specific origins, canonicalize the
checked semantic model and IR, and require equal digests, manifests, task
limits, delegate bounds, and completion specifications for every valid pair.

- [ ] **Subtask 3.4.1.1 Complete**

#### Subtask 3.4.1.2: Require Equivalent Rejection Classes

**Description:** Mutate each pair with the same semantic defect and require the
same stable error class at the appropriate A-Lang origin or JSON pointer,
without requiring presentation-specific messages to be identical.

- [ ] **Subtask 3.4.1.2 Complete**

### Task 3.4.2: Reassert IR Laws, Bounds, and Residency

**Description:** Run deterministic serialization, manifest agreement, child
attenuation, node-reference, acyclic-call, and selected composition properties
entirely as BEAM tests.

- [ ] **Task 3.4.2 Complete**

#### Subtask 3.4.2.1: Detect Seeded Checker and Lowering Defects

**Description:** Prove the suite detects removed effect inference, widened
child limits, ignored completion fields, condition-specific defaults,
unstable node identities, and acceptance of direct IR.

- [ ] **Subtask 3.4.2.1 Complete**

#### Subtask 3.4.2.2: Publish Phase 3 Evidence

**Description:** Record frontend and checker residency, paired digest matrix,
manifest/limit equality, negative-case equivalence, property counts, mutant
detection, and exact commands needed to reproduce the phase gate.

- [ ] **Subtask 3.4.2.2 Complete**

## Phase 3 Completion Evidence

**Description:** Authorize backend integration only after both notations have
one shared, statically enforced meaning.

- [ ] Typed JSON is decoded and checked entirely on BEAM
- [ ] JSON cannot inject IR, runtime, adapter, credential, or process terms
- [ ] A-Lang and JSON use one resolver and static semantic core
- [ ] Declared effects and requirements exactly match inferred authority
- [ ] Limits cover finite static upper bounds and child limits are attenuated
- [ ] Every valid pair yields equal normalized `alang_typed_task_ir_v2` digests
- [ ] Equivalent semantic defects receive equivalent rejection classes
- [ ] Direct IR and fixture constructors cannot enter campaign execution
- [ ] Seeded semantic and lowering defects are detected
