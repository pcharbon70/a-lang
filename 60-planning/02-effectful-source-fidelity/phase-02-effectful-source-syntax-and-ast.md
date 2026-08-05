---
title: "Phase 2: Effectful Source Syntax and AST"
kind: note
created: 2026-08-05
maturity: developing
tags:
  - beam
  - compiler-design
  - implementation-planning
  - language-design
  - parsing
aliases: []
---

# Phase 2: Effectful Source Syntax and AST

**Description:** Extend the BEAM-resident A-Lang lexer, parser, and canonical
AST boundary from the pure `alang-source-v1` counter slice to the frozen
`alang-source-v2` effectful surface. The new syntax expresses the existing
model, workspace, repair, child, limit, result, and completion semantics without
adding general-purpose language features or interpreting source.

**Status:** Planned; every item remains unchecked until reproducible evidence
exists.

**Dependencies:** Phase 1 complete with frozen representation and corpus
contracts. The Phase 2 v1 frontend remains supported, and the Phase 3 IR/runtime
vocabulary defines the maximum semantic surface this parser may expose.

## Section 2.1: Versioned Lexical and Declaration Surface

**Description:** Add only the tokens, literals, built-in types, and task clauses
needed by the pre-registered effectful corpus while retaining bounded input and
binary identifiers.

- [ ] **Section 2.1 Complete**

### Task 2.1.1: Extend the Lexer Without Expanding Trust

**Description:** Recognize the v2 keywords and punctuation with stable byte,
line, and column origins, bounded UTF-8 strings, and no atoms created from
source-controlled text.

- [ ] **Task 2.1.1 Complete**

#### Subtask 2.1.1.1: Add Closed V2 Tokens and Literals

**Description:** Add `Binary`, `Result`, `do`, `let`, `return`, `match`, `ok`,
`error`, `limits`, `delegate`, `with`, and `artifact` forms plus quoted binary
literals, named arguments, braces, brackets, commas, and assignment arrows;
reject interpolation and arbitrary operator names.

- [ ] **Subtask 2.1.1.1 Complete**

#### Subtask 2.1.1.2: Preserve Bounds, Origins, and V1 Behavior

**Description:** Keep the 1 MiB source ceiling, deterministic token stream,
bounded literal and identifier sizes, comment behavior, and v1 token meanings;
add Unicode validation without normalizing identifiers implicitly.

- [ ] **Subtask 2.1.1.2 Complete**

### Task 2.1.2: Parse V2 Task Headers and Limits

**Description:** Parse nonempty effect and requirement lists plus a closed limit
record before the task body so static authority is explicit at the source
boundary.

- [ ] **Task 2.1.2 Complete**

#### Subtask 2.1.2.1: Parse Built-In Data and Result Types

**Description:** Accept `Int`, `Bool`, `Binary`, and the built-in
`Result<Success, Failure>` form only; retain task parameters and results while
rejecting user-defined, polymorphic, recursive, or higher-kinded types.

- [ ] **Subtask 2.1.2.1 Complete**

#### Subtask 2.1.2.2: Parse Authority and Runtime Limits

**Description:** Accept closed lists containing only `model.complete` and
`workspace.write`, their matching requirements, and named integer limits for
steps, model calls, repairs, workspace writes, child calls, output bytes, and
deadline milliseconds; reject duplicate or unknown keys.

- [ ] **Subtask 2.1.2.2 Complete**

## Section 2.2: Sequential Effects, Results, Child Tasks, and Completion

**Description:** Parse the minimal structured control forms that map directly
to already implemented typed-IR and Phase 6 runtime concepts.

- [ ] **Section 2.2 Complete**

### Task 2.2.1: Parse Sequential Bodies and Closed Effect Calls

**Description:** Add a `do` body containing ordered `let` bindings and one
terminal `return`, with explicit result matching around model and workspace
operations rather than exceptions or implicit retries.

- [ ] **Task 2.2.1 Complete**

#### Subtask 2.2.1.1: Parse `do`, Binding, Return, and Result Match

**Description:** Parse sequential bindings and `match value { ok(name) => ...,
error(name) => ... }` with lexical scopes and total branches; do not add loops,
recursion, mutation, early return, or unstructured control flow.

- [ ] **Subtask 2.2.1.1 Complete**

#### Subtask 2.2.1.2: Parse the Two Registered Effect Intrinsics

**Description:** Parse named, closed arguments for `model.complete` and
`workspace.write`, including model/workspace identity, prompt/path/content,
maximum bytes, and relative deadline. Operation identities remain compiler- and
runtime-derived rather than source-authored; reject dynamic operation, adapter,
endpoint, credential, module, and function selection.

- [ ] **Subtask 2.2.1.2 Complete**

### Task 2.2.2: Parse Restricted Delegation and Completion Clauses

**Description:** Represent the existing child attenuation and artifact verifier
as source-owned declarations rather than adding a generic spawn primitive or a
model-controlled completion decision.

- [ ] **Task 2.2.2 Complete**

#### Subtask 2.2.2.1: Parse `delegate` with Mechanical Bounds

**Description:** Accept a statically named local child task, typed arguments,
and a `with` record that can only reduce effects, requirements, model calls,
output bytes, and deadline; prohibit grant values, process identifiers,
delegation, combination, and dynamic task names.

- [ ] **Subtask 2.2.2.1 Complete**

#### Subtask 2.2.2.2: Parse Structured Artifact Completion

**Description:** Accept an `ensures artifact(...)` clause with a safe relative
path, expected canonical digest, maximum bytes, UTF-8 and Markdown-H1 flags,
required H2 section, and successful-journal requirement; prohibit arbitrary
predicates and model assertions of completion.

- [ ] **Subtask 2.2.2.2 Complete**

## Section 2.3: V2 AST, Canonical Boundary, and Diagnostics

**Description:** Preserve exact source meaning and local origins in a bounded,
versioned AST that later semantic passes can consume deterministically.

- [ ] **Section 2.3 Complete**

### Task 2.3.1: Define and Validate `alang_source_ast_v2`

**Description:** Give every declaration, expression, effect call, branch,
child restriction, limit, and completion field an exact closed AST shape and
origin.

- [ ] **Task 2.3.1 Complete**

#### Subtask 2.3.1.1: Reject Partial and Ambiguous AST Shapes

**Description:** Require exact fields, bounded list and nesting depths, unique
named arguments, one terminal return per branch, one completion clause per
task, and no representation of unsupported constructs.

- [ ] **Subtask 2.3.1.1 Complete**

#### Subtask 2.3.1.2: Extend Deterministic Canonical ETF

**Description:** Encode and decode v2 AST with safe, bounded, deterministic ETF,
reject trailing or compressed data, revalidate after decoding, and keep v1 and
v2 format identities distinct.

- [ ] **Subtask 2.3.1.2 Complete**

### Task 2.3.2: Produce Stable Source-Local Diagnostics

**Description:** Return deterministic codes, messages, and smallest relevant
origins for lexical, grammatical, version, duplicate-field, and structural
errors without silently inserting or repairing syntax.

- [ ] **Task 2.3.2 Complete**

#### Subtask 2.3.2.1: Cover Every New Rejection Boundary

**Description:** Add diagnostics for unknown effect or limit names, malformed
result types, incomplete match arms, invalid named arguments, widened child
syntax, unsafe completion paths, oversized values, and unsupported constructs.

- [ ] **Subtask 2.3.2.1 Complete**

#### Subtask 2.3.2.2: Bound Malformed-Input Work

**Description:** Ensure invalid UTF-8, adversarial nesting, long tokens,
truncation, and random bytes terminate within declared time and memory bounds
without crashes, atom growth, partial acceptance, or filesystem/network work.

- [ ] **Subtask 2.3.2.2 Complete**

## Section 2.4: Phase 2 Integration Tests

**Description:** Prove all 24 A-Lang corpus sources parse and round-trip on ERTS
while negative and legacy inputs fail or succeed at the intended boundary.

- [ ] **Section 2.4 Complete**

### Task 2.4.1: Run Golden, Round-Trip, and Compatibility Suites

**Description:** Compile the lexer/parser modules to BEAM, parse every frozen
source, reproduce AST digests, and rerun the complete v1 frontend suite.

- [ ] **Task 2.4.1 Complete**

#### Subtask 2.4.1.1: Validate the Frozen V2 Corpus

**Description:** Require all 24 candidate documents to produce their declared
AST identities and source maps with no hand-edited parser fixture or
condition-specific parser branch.

- [ ] **Subtask 2.4.1.1 Complete**

#### Subtask 2.4.1.2: Reassert V1 Compatibility

**Description:** Require byte-identical v1 canonical products and unchanged
diagnostics for the existing counter fixtures so v2 does not rewrite completed
Phase 2 evidence.

- [ ] **Subtask 2.4.1.2 Complete**

### Task 2.4.2: Run Negative and Generative Parser Tests

**Description:** Exercise seeded syntax violations and generated bounded input
against both text and canonical boundaries on the pinned ERTS runtime.

- [ ] **Task 2.4.2 Complete**

#### Subtask 2.4.2.1: Detect One Seeded Defect per New Construct

**Description:** Prove tests fail when effect names become dynamic, a result arm
is skipped, child restrictions widen, completion paths accept traversal,
limits duplicate, or unsupported syntax is accepted.

- [ ] **Subtask 2.4.2.1 Complete**

#### Subtask 2.4.2.2: Publish Phase 2 Evidence

**Description:** Record module residency, corpus and negative-case counts,
stable AST/canonical digests, legacy compatibility, resource bounds, and exact
commands needed to reproduce the parser gate.

- [ ] **Subtask 2.4.2.2 Complete**

## Phase 2 Completion Evidence

**Description:** Authorize semantic checking only after effectful user source
has one deterministic, bounded, BEAM-resident parse path.

- [ ] All 24 A-Lang corpus documents parse as `alang_source_ast_v2`
- [ ] Model, workspace, repair, delegation, limits, results, and completion have closed AST shapes
- [ ] Every AST node and diagnostic retains a precise source origin
- [ ] Canonical ETF round-trips safely and deterministically
- [ ] V1 parsing and canonical evidence remain unchanged
- [ ] Unsupported and widened syntax fails closed
- [ ] Malformed and generated inputs remain bounded without atom growth
- [ ] No parser path interprets source or performs a runtime effect
