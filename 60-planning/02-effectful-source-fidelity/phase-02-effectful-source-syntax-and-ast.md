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

**Status:** Complete; the reproducible results are recorded in the
[Phase 2 frontend evidence](../../src/effectful-source-fidelity/phase-02-integration-evidence.md).

**Dependencies:** Phase 1 complete with frozen representation and corpus
contracts. The Phase 2 v1 frontend remains supported, and the Phase 3 IR/runtime
vocabulary defines the maximum semantic surface this parser may expose.

## Section 2.1: Versioned Lexical and Declaration Surface

**Description:** Add only the tokens, literals, built-in types, and declaration
clauses used by the pre-registered effectful corpus while retaining bounded
input, source-local origins, and binary identifiers.

- [x] **Section 2.1 Complete**

### Task 2.1.1: Extend the Lexer Without Expanding Trust

**Description:** Recognize the frozen v2 shebang, clause keywords, qualified
names, and punctuation with stable byte, line, and column origins, bounded
UTF-8 strings, and no atoms created from source-controlled text.

- [x] **Task 2.1.1 Complete**

#### Subtask 2.1.1.1: Add Closed V2 Tokens and Literals

**Description:** Add `task`, `facts`, `input`, `effects`, `requirements`,
`scopes`, and `limits` forms plus bounded strings, binary identifiers,
qualified names, braces, brackets, commas, colons, and semicolons; reject
interpolation, arbitrary escapes, and unsupported punctuation.

- [x] **Subtask 2.1.1.1 Complete**

#### Subtask 2.1.1.2: Preserve Bounds, Origins, and V1 Behavior

**Description:** Keep the 1 MiB lexer ceiling, enforce the frozen 8,192-byte v2
document bound, preserve deterministic tokens and v1 dispatch, and validate
Unicode without normalizing identifiers implicitly.

- [x] **Subtask 2.1.1.2 Complete**

### Task 2.1.2: Parse V2 Task Declarations and Limits

**Description:** Parse facts, typed inputs, effects, requirements, scopes, and a
closed limit record in presentation-independent clause order so declared
authority and resource bounds are explicit at the source boundary. Empty
authority is retained for the pre-registered clarification-only cases.

- [x] **Task 2.1.2 Complete**

#### Subtask 2.1.2.1: Parse the Frozen Built-In Input Types

**Description:** Accept only `bool`, `json`, `model-profile`, `nat`, `path`, and
`text` in v2 input declarations; preserve v1 `Int` and `Bool` behavior through
the unchanged legacy frontend while rejecting user-defined or polymorphic
types.

- [x] **Subtask 2.1.2.1 Complete**

#### Subtask 2.1.2.2: Parse Authority and Runtime Limits

**Description:** Accept closed lists containing only `child.run`,
`model.generate`, and `workspace.write`, model/workspace requirements, declared
resource scopes, and the seven frozen integer limits; reject duplicate or
unknown fields and values.

- [x] **Subtask 2.1.2.2 Complete**

## Section 2.2: Ordered Effects, Error Results, Child Attenuation, and Completion

**Description:** Parse the minimal ordered action, error, child, and completion
declarations frozen in Phase 1 so they can map directly to the existing typed
IR and runtime concepts without executing source.

- [x] **Section 2.2 Complete**

### Task 2.2.1: Parse Ordered Steps and Closed Operations

**Description:** Parse ordered `step` declarations with explicit dependency
lists and a closed `on-error` table so failure behavior remains data rather than
exceptions, implicit retries, or unstructured control flow.

- [x] **Task 2.2.1 Complete**

#### Subtask 2.2.1.1: Parse Steps, Dependencies, and Error Branches

**Description:** Parse named actions, ordered dependency lists, and explicit
`action reason => terminal-class` branches; do not add loops, recursion,
mutation, early return, or unstructured control flow.

- [x] **Subtask 2.2.1.1 Complete**

#### Subtask 2.2.1.2: Parse the Registered Step Operations

**Description:** Accept only `model.generate`, `model.repair`,
`workspace.write`, `child.run`, and `complete` as step operations. Runtime
operation identities and arguments remain compiler-derived; reject dynamic
operation, adapter, endpoint, credential, module, and function selection.

- [x] **Subtask 2.2.1.2 Complete**

### Task 2.2.2: Parse Restricted Delegation and Completion Clauses

**Description:** Represent the existing child attenuation and artifact verifier
as source-owned declarations rather than adding a generic spawn primitive or a
model-controlled completion decision.

- [x] **Task 2.2.2 Complete**

#### Subtask 2.2.2.1: Parse a Mechanically Bounded Child Record

**Description:** Accept `child none` or one closed child record containing only
effects, requirements, scopes, and limits. Prohibit grant values, process
identifiers, nested delegation, combination, and dynamic task names.

- [x] **Subtask 2.2.2.1 Complete**

#### Subtask 2.2.2.2: Parse Structured Artifact Completion

**Description:** Accept only the frozen `artifact-exists`, `markdown-h1`,
`utf8`, `max-bytes`, `journal-succeeded`, and `clarification-recorded`
predicates with typed expected values, followed by explicit clarification and
terminal declarations; prohibit arbitrary predicates and model assertions of
completion.

- [x] **Subtask 2.2.2.2 Complete**

## Section 2.3: V2 AST, Canonical Boundary, and Diagnostics

**Description:** Preserve exact source meaning and local origins in a bounded,
versioned AST that later semantic passes can consume deterministically.

- [x] **Section 2.3 Complete**

### Task 2.3.1: Define and Validate `alang_source_ast_v2`

**Description:** Give every declaration, expression, effect call, branch,
child restriction, limit, and completion field an exact closed AST shape and
origin.

- [x] **Task 2.3.1 Complete**

#### Subtask 2.3.1.1: Reject Partial and Ambiguous AST Shapes

**Description:** Require exact node fields, bounded collection and child
depths, unique names and set entries, one instance of every singleton task
clause, and no representation of unsupported constructs.

- [x] **Subtask 2.3.1.1 Complete**

#### Subtask 2.3.1.2: Extend Deterministic Canonical ETF

**Description:** Encode and decode v2 AST with safe, bounded, deterministic ETF,
reject trailing or compressed data, revalidate after decoding, and keep v1 and
v2 format identities distinct.

- [x] **Subtask 2.3.1.2 Complete**

### Task 2.3.2: Produce Stable Source-Local Diagnostics

**Description:** Return deterministic codes, messages, and smallest relevant
origins for lexical, grammatical, version, duplicate-field, and structural
errors without silently inserting or repairing syntax.

- [x] **Task 2.3.2 Complete**

#### Subtask 2.3.2.1: Cover Every New Rejection Boundary

**Description:** Add diagnostics for unknown effects, operations, types, and
limits; incomplete or duplicate clauses; widened child syntax; invalid
completion values; unsafe workspace paths; oversized values; and unsupported
constructs.

- [x] **Subtask 2.3.2.1 Complete**

#### Subtask 2.3.2.2: Bound Malformed-Input Work

**Description:** Ensure invalid UTF-8, adversarial nesting, long tokens,
truncation, and random bytes terminate within declared time and memory bounds
without crashes, atom growth, partial acceptance, or filesystem/network work.

- [x] **Subtask 2.3.2.2 Complete**

## Section 2.4: Phase 2 Integration Tests

**Description:** Prove all 24 A-Lang corpus sources parse and round-trip on ERTS
while negative and legacy inputs fail or succeed at the intended boundary.

- [x] **Section 2.4 Complete**

### Task 2.4.1: Run Golden, Round-Trip, and Compatibility Suites

**Description:** Compile the lexer/parser modules to BEAM, parse every frozen
source, reproduce AST digests, and rerun the complete v1 frontend suite.

- [x] **Task 2.4.1 Complete**

#### Subtask 2.4.1.1: Validate the Frozen V2 Corpus

**Description:** Require all 24 candidate documents to produce their declared
AST identities and source maps with no hand-edited parser fixture or
condition-specific parser branch.

- [x] **Subtask 2.4.1.1 Complete**

#### Subtask 2.4.1.2: Reassert V1 Compatibility

**Description:** Require byte-identical v1 canonical products and unchanged
diagnostics for the existing counter fixtures so v2 does not rewrite completed
Phase 2 evidence.

- [x] **Subtask 2.4.1.2 Complete**

### Task 2.4.2: Run Negative and Generative Parser Tests

**Description:** Exercise seeded syntax violations and generated bounded input
against both text and canonical boundaries on the pinned ERTS runtime.

- [x] **Task 2.4.2 Complete**

#### Subtask 2.4.2.1: Detect One Seeded Defect per New Construct

**Description:** Prove tests fail when effect or operation names become dynamic,
the error table is omitted, child restrictions widen, completion paths accept
traversal, limits duplicate, or unsupported control syntax is accepted.

- [x] **Subtask 2.4.2.1 Complete**

#### Subtask 2.4.2.2: Publish Phase 2 Evidence

**Description:** Record module residency, corpus and negative-case counts,
stable AST/canonical digests, legacy compatibility, resource bounds, and exact
commands needed to reproduce the parser gate.

- [x] **Subtask 2.4.2.2 Complete**

## Phase 2 Completion Evidence

**Description:** Authorize semantic checking only after effectful user source
has one deterministic, bounded, BEAM-resident parse path.

- [x] All 24 A-Lang corpus documents parse as `alang_source_ast_v2`
- [x] Model, workspace, repair, delegation, limits, results, and completion have closed AST shapes
- [x] Every AST node and diagnostic retains a precise source origin
- [x] Canonical ETF round-trips safely and deterministically
- [x] V1 parsing and canonical evidence remain unchanged
- [x] Unsupported and widened syntax fails closed
- [x] Malformed and generated inputs remain bounded without atom growth
- [x] No parser path interprets source or performs a runtime effect
