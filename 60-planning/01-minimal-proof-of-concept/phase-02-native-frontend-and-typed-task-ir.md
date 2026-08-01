---
title: "Phase 2: Native Frontend and Typed Task IR"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - categorical-semantics
  - compiler-design
  - effect-system
  - implementation-planning
aliases: []
---

# Phase 2: Native Frontend and Typed Task IR

**Description:** This phase implements the canonical JSON input, a small native
textual frontend, source-oriented resolution and type-and-effect checking, a
normalized A-Lang-owned task IR, capability-requirement inference, and
independent test-only reference, simulation, trace, and manifest views. The
phase ends by compiling source through the Phase 1 path and executing it on
ERTS.

**Status:** Planned.

**Dependencies:** Phase 1 complete with a generated artifact compiled through
the pinned OTP boundary, inspected, loaded, spawned, and observed as a BEAM
process with the no-interpreter gate accepted.

## Section 2.1: Canonical and Textual Frontends

**Description:** Accept one familiar canonical representation and one minimal
human-facing syntax that produce the same untyped AST with complete source
origins.

- [x] **Section 2.1 Complete** — evidence: [frozen source surface](../../src/phase-02/language-surface.md) and [frontend tests](../../src/phase-02/parser.rs)

### Task 2.1.1: Implement the Canonical JSON Frontend

**Description:** Decode and validate the versioned canonical source schema as
the stable fixture and tooling input for the PoC language.

- [x] **Task 2.1.1 Complete** — evidence: [canonical JSON decoder](../../src/phase-02/json_frontend.rs)

#### Subtask 2.1.1.1: Decode the Complete Planned Surface

**Description:** Decode modules, type declarations, functions, tasks, records,
results, expressions, effects, requirements, completion predicates, and source
origins without silently accepting unknown constructs.

- [x] **Subtask 2.1.1.1 Complete** — evidence: [complete declared surface](../../src/phase-02/language-surface.md#complete-declared-surface) and [source AST](../../src/phase-02/source.rs)

#### Subtask 2.1.1.2: Reject Schema and Version Violations

**Description:** Produce stable diagnostics for missing fields, unknown tags,
invalid identifiers, oversized inputs, unsupported versions, and malformed
source locations.

- [x] **Subtask 2.1.1.2 Complete** — evidence: [schema and boundary diagnostics](../../src/phase-02/json_frontend.rs)

### Task 2.1.2: Implement the Native Textual Lexer and Parser

**Description:** Build the minimal human-facing A-Lang frontend in the selected
native compiler implementation and lower its parse tree to the same AST used
by canonical JSON fixtures. The host implementation is a compiler, not an
A-Lang runtime.

- [x] **Task 2.1.2 Complete** — evidence: [native lexer](../../src/phase-02/lexer.rs) and [native parser](../../src/phase-02/parser.rs)

#### Subtask 2.1.2.1: Implement Tokens, Grammar, and Precedence

**Description:** Recognize the frozen keywords, identifiers, literals,
delimiters, type forms, declarations, expressions, `effect`, `requires`,
`perform`, `ensures`, and sequential composition with no speculative syntax.

- [x] **Subtask 2.1.2.1 Complete** — evidence: [grammar and precedence](../../src/phase-02/language-surface.md#textual-grammar)

#### Subtask 2.1.2.2: Preserve Locations and Recover Diagnostics

**Description:** Preserve byte spans and line-column locations through every
AST node and recover far enough from common delimiter or declaration errors to
report multiple independent issues without inventing nodes.

- [x] **Subtask 2.1.2.2 Complete** — evidence: [source locations and recovery contract](../../src/phase-02/language-surface.md#diagnostics-and-recovery) and [recovering parser tests](../../src/phase-02/parser.rs)

## Section 2.2: Resolution and Data Typing

**Description:** Resolve every name and assign ordinary data types before
effects, requirements, or backend concerns enter the semantic judgment.

- [x] **Section 2.2 Complete** — evidence: [static semantics](../../src/phase-02/static-semantics.md) and [Section 2.2 gate](../../Makefile)

### Task 2.2.1: Implement Modules, Scopes, and Symbol Resolution

**Description:** Bind module, type, constructor, field, parameter, function,
task, effect, operation, resource, and verifier names into stable semantic
identities.

- [x] **Task 2.2.1 Complete** — evidence: [resolver](../../src/phase-02/resolver.rs) and [semantic identities](../../src/phase-02/static-semantics.md#stable-semantic-identities)

#### Subtask 2.2.1.1: Build Scope and Definition Tables

**Description:** Detect duplicates, shadowing outside the accepted rule,
unknown names, wrong namespaces, and arity mismatches while preserving the
origin of each definition and use.

- [x] **Subtask 2.2.1.1 Complete** — evidence: [scope and namespace rules](../../src/phase-02/static-semantics.md#scope-and-namespace-rules) and [resolution tests](../../src/phase-02/resolver.rs)

#### Subtask 2.2.1.2: Normalize Resource and Operation Identities

**Description:** Assign stable identifiers to `Model.complete`,
`Workspace.write`, `Trace.emit`, resource parameters, and completion
predicates so later manifests and runtime messages do not depend on spelling.

- [x] **Subtask 2.2.1.2 Complete** — evidence: [canonical semantic identities](../../src/phase-02/semantic.rs)

### Task 2.2.2: Implement the Minimal Data Type Checker

**Description:** Check primitives, opaque identifiers, records, products,
results, functions, tasks, applications, `let`, and exhaustive result matches
without introducing deferred polymorphism.

- [x] **Task 2.2.2 Complete** — evidence: [minimal data checker](../../src/phase-02/type_checker.rs)

#### Subtask 2.2.2.1: Check Expressions and Composition

**Description:** Enforce input-output compatibility, field and constructor
typing, branch agreement, function arity, and typed sequential composition
with source-local expected-versus-actual diagnostics.

- [x] **Subtask 2.2.2.1 Complete** — evidence: [data-type contract](../../src/phase-02/static-semantics.md#minimal-data-types) and [composition tests](../../src/phase-02/type_checker.rs)

#### Subtask 2.2.2.2: Check Exhaustiveness and Opaque Boundaries

**Description:** Reject missing result alternatives, impossible constructor
uses, implicit coercions, and construction or inspection of opaque runtime
identifiers outside their approved operations.

- [x] **Subtask 2.2.2.2 Complete** — evidence: [opaque and exhaustiveness tests](../../src/phase-02/type_checker.rs)

## Section 2.3: Effects and Capability Requirements

**Description:** Distinguish what a task may do from what authority it
requires, and calculate both as deterministic semantic artifacts independent
of any portable authorization protocol or concrete runtime grant.

- [ ] **Section 2.3 Complete**

### Task 2.3.1: Implement Closed Effect Checking

**Description:** Infer and check closed monomorphic effect sets for functions,
tasks, operations, calls, branches, and sequential composition.

- [ ] **Task 2.3.1 Complete**

#### Subtask 2.3.1.1: Propagate Declared Operations

**Description:** Make `perform` introduce its named effect, pure functions
retain the empty effect set, composition combine effect sets by union, and
annotations reject missing or unexpected effects.

- [ ] **Subtask 2.3.1.1 Complete**

#### Subtask 2.3.1.2: Reject Effect Escapes

**Description:** Reject undeclared operations, model or workspace calls from
pure functions, unsupported handlers, and any construct whose effects cannot
be represented in the closed PoC effect system.

- [ ] **Subtask 2.3.1.2 Complete**

### Task 2.3.2: Normalize Capability Requirements

**Description:** Compile each `requires` clause into an A-Lang-owned typed
authority predicate and prove that every effect operation is covered by a
requirement independent of any runtime grant.

- [ ] **Task 2.3.2 Complete**

#### Subtask 2.3.2.1: Define Requirement Algebra and Canonical Form

**Description:** Define resource identity, operation, typed constraints,
deadline, call and byte budgets, union, equality, subsumption, and deterministic
serialization for the minimal requirement domain.

- [ ] **Subtask 2.3.2.1 Complete**

#### Subtask 2.3.2.2: Check Effect-to-Requirement Coverage

**Description:** Require each `Model.complete` and `Workspace.write` site to
fall within the task's declared requirement and report the smallest uncovered
operation or widened argument constraint.

- [ ] **Subtask 2.3.2.2 Complete**

## Section 2.4: Typed IR and Test-Only Semantic Views

**Description:** Lower checked source into a small categorical task IR and
give the IR several explicit test views while preserving compiled BEAM as the
only execution path accepted by the proof of concept.

- [ ] **Section 2.4 Complete**

### Task 2.4.1: Define and Construct the Typed Task IR

**Description:** Represent typed values, pure arrows, products, results,
sequential tasks, effect requests, requirements, verifier nodes, and source
origins in a normalized, backend-independent form.

- [ ] **Task 2.4.1 Complete**

#### Subtask 2.4.1.1: Normalize Source Sugar and Identities

**Description:** Resolve names, make evaluation order explicit, assign stable
node and operation identifiers, retain effect and requirement annotations, and
eliminate only source constructs with a specified semantics-preserving rule.

- [ ] **Subtask 2.4.1.1 Complete**

#### Subtask 2.4.1.2: Validate IR Invariants

**Description:** Reject dangling identities, ill-typed edges, incomplete
branches, undeclared operations, missing verifier nodes, and noncanonical
requirements before any interpreter receives the IR.

- [ ] **Subtask 2.4.1.2 Complete**

### Task 2.4.2: Implement Test-Only Reference, Simulation, Trace, and Manifest Views

**Description:** Evaluate the same checked IR against fixture-provided values
and derive simulation, normalized trace, and capability-manifest views solely
for tests, diagnostics, and differential comparison.

- [ ] **Task 2.4.2 Complete**

#### Subtask 2.4.2.1: Implement the Deterministic Reference Evaluator

**Description:** Execute pure nodes and consume fixture-provided effect results
with explicit state transitions, stable observations, bounded steps, and no
host filesystem or network access. Mark the evaluator as nondeployable and
incapable of satisfying a runtime phase gate.

- [ ] **Subtask 2.4.2.1 Complete**

#### Subtask 2.4.2.2: Implement Nonexecuting Interpreters

**Description:** Produce dry-run plans, trace skeletons, capability manifests,
completion checklists, and human-readable explanations from the same IR and
verify that each interpreter covers every primitive node.

- [ ] **Subtask 2.4.2.2 Complete**

## Section 2.5: Phase 2 Integration Tests

**Description:** Prove that both frontends converge on one checked IR, invalid
programs fail before backend work, and accepted source feeds the already-proven
BEAM compiler and ERTS execution path.

- [ ] **Section 2.5 Complete**

### Task 2.5.1: Validate Frontend and Semantic Agreement

**Description:** Run paired textual and canonical JSON programs through
parsing, resolution, typing, effect checking, requirement normalization, and
IR validation and compare canonical outputs.

- [ ] **Task 2.5.1 Complete**

#### Subtask 2.5.1.1: Execute Positive Paired Fixtures

**Description:** Verify the final demo program and focused programs for every
promoted type, expression, effect, requirement, and verifier construct produce
the expected identical typed IR.

- [ ] **Subtask 2.5.1.1 Complete**

#### Subtask 2.5.1.2: Execute Negative Semantic Fixtures

**Description:** Verify malformed syntax, unknown symbols, type mismatches,
nonexhaustive results, undeclared effects, missing requirements, and deferred
features fail with stable source-oriented diagnostics.

- [ ] **Subtask 2.5.1.2 Complete**

### Task 2.5.2: Execute Frontend Programs on BEAM

**Description:** Lower checked IR through the Phase 1 Abstract Format adapter,
compile and inspect the artifact, run it as a BEAM process, and compare its
normalized observation with the test-only views.

- [ ] **Task 2.5.2 Complete**

#### Subtask 2.5.2.1: Assert BEAM and Test-View Agreement

**Description:** Confirm every promoted IR node lowers explicitly and that
compiled BEAM observations agree with the bounded reference result, trace
skeleton, effect manifest, and completion checklist within defined equality.

- [ ] **Subtask 2.5.2.1 Complete**

#### Subtask 2.5.2.2: Reassert the No-Interpreter Gate

**Description:** Run frontend, semantic, schema, snapshot, fuzz-smoke, artifact,
and isolated ERTS suites and prove that all successful A-Lang executions came
from loaded BEAM modules rather than the test evaluator.

- [ ] **Subtask 2.5.2.2 Complete**

## Phase 2 Completion Evidence

**Description:** Record the evidence that authorizes Phase 3 to generalize the
already-working BEAM lowering and runtime semantics.

- [ ] Textual and canonical JSON frontends produce identical checked IR
- [ ] Resolution, data typing, effects, and requirements fail closed
- [ ] Capability manifests remain independent of portable protocol concepts
- [ ] Reference, simulation, trace, and manifest views cover all IR
      primitives
- [ ] Accepted source compiles and executes as an isolated BEAM process
- [ ] Test-only evaluation is absent from the accepted runtime path
- [ ] Positive and negative fixtures pass with stable diagnostics
- [ ] Frontend fuzz-smoke and complete repository gates pass
