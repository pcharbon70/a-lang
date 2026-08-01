---
title: "Phase 2: BEAM-Resident Compiler Frontend and Typed Task IR"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - beam
  - categorical-semantics
  - compiler-design
  - implementation-planning
aliases:
  - "Phase 2 native frontend"
---

# Phase 2: BEAM-Resident Compiler Frontend and Typed Task IR

**Description:** This phase replaces the initial foreign-toolchain approach
with a compiler whose lexer, parser, canonical decoder, semantic checker,
typed IR lowering, views, bridge, and command driver are all `.beam` modules
executed by ERTS. Erlang source bootstraps the compiler modules; it does not
interpret A-Lang programs. The intentionally narrow counter profile then feeds
the Phase 1 OTP 29 Abstract Format path and executes as a separate BEAM module.

**Status:** Complete for the minimal counter profile — evidence: [Phase 2
integration evidence](../../src/phase-02/phase-02-integration-evidence.md).

**Dependencies:** Phase 1 complete with a generated artifact compiled through
the pinned OTP boundary, inspected, loaded, spawned, and observed as a BEAM
process with the no-interpreter gate accepted.

## Section 2.1: BEAM-Resident Source Frontend

**Description:** Accept the minimal textual language and deterministic
canonical form entirely through compiler passes loaded into an OTP 29 ERTS
node.

- [x] **Section 2.1 Complete** — evidence: [language surface](../../src/phase-02/language-surface.md), [lexer](../../src/phase-02/alang_phase2_lexer.erl), and [parser](../../src/phase-02/alang_phase2_parser.erl)

### Task 2.1.1: Enforce Compiler Residency

**Description:** Compile every trusted Phase 2 source-to-artifact component to
BEAM, invoke the compiler driver with `erl`, and reject Rust, Cargo, or any
other foreign executable from the compiler dependency graph.

- [x] **Task 2.1.1 Complete** — evidence: [compiler driver](../../src/phase-02/alang_phase2_compiler.erl) and [residency test](../../src/phase-02/alang_phase2_compiler_tests.erl)

#### Subtask 2.1.1.1: Bootstrap Compiler Modules on OTP 29

**Description:** Build deterministic `.beam` files for the lexer, parser,
semantic checker, typed IR, projections, bridge, and command driver under the
pinned OTP release.

- [x] **Subtask 2.1.1.1 Complete** — evidence: [`compile-phase-2-toolchain`](../../Makefile)

#### Subtask 2.1.1.2: Record Machine-Checkable Residency Evidence

**Description:** Record the loaded file of each compiler module, the OTP and
ERTS identity, and the empty list of foreign compiler executables in each
generated compiler evidence record.

- [x] **Subtask 2.1.1.2 Complete** — evidence: [compiler evidence implementation](../../src/phase-02/alang_phase2_compiler.erl)

### Task 2.1.2: Implement Textual and Canonical Frontends

**Description:** Parse the counter profile with stable byte/line/column
origins and encode the same AST as bounded deterministic Erlang External Term
Format for internal compiler interchange.

- [x] **Task 2.1.2 Complete** — evidence: [lexer](../../src/phase-02/alang_phase2_lexer.erl), [parser](../../src/phase-02/alang_phase2_parser.erl), and [canonical ETF boundary](../../src/phase-02/alang_phase2_canonical.erl)

#### Subtask 2.1.2.1: Parse the Frozen Counter Grammar

**Description:** Recognize module and task declarations, `Int` and `Bool`,
parameters, pure effect and requirement lists, integer addition, equality, and
completion predicates with deterministic precedence.

- [x] **Subtask 2.1.2.1 Complete** — evidence: [textual grammar](../../src/phase-02/language-surface.md#textual-grammar)

#### Subtask 2.1.2.2: Bound and Validate Canonical ETF

**Description:** Reject oversized, malformed, unsafe, trailing, unsupported,
or semantically invalid terms and require byte-identical deterministic
round-trips.

- [x] **Subtask 2.1.2.2 Complete** — evidence: [canonical tests](../../src/phase-02/alang_phase2_compiler_tests.erl)

## Section 2.2: Minimal Static Semantics

**Description:** Resolve names and check the deliberately closed pure counter
profile before any backend work begins.

- [x] **Section 2.2 Complete** — evidence: [static semantics](../../src/phase-02/static-semantics.md) and [semantic checker](../../src/phase-02/alang_phase2_semantics.erl)

### Task 2.2.1: Resolve Stable Task and Parameter Identities

**Description:** Detect duplicate tasks and parameters, reject unresolved
variables, and assign stable task identities without creating atoms from
source-controlled identifiers.

- [x] **Task 2.2.1 Complete** — evidence: [semantic checker](../../src/phase-02/alang_phase2_semantics.erl)

#### Subtask 2.2.1.1: Preserve Source Origins in Diagnostics

**Description:** Carry source locations into duplicate, unresolved-name,
version, literal-range, and type diagnostics.

- [x] **Subtask 2.2.1.1 Complete** — evidence: [semantic tests](../../src/phase-02/alang_phase2_compiler_tests.erl)

#### Subtask 2.2.1.2: Assign Stable Callable Identities

**Description:** Derive `task:<module>.<name>/<arity>` identities from checked
binary names so later IR nodes and observations do not depend on process or VM
identity.

- [x] **Subtask 2.2.1.2 Complete** — evidence: [identity construction](../../src/phase-02/alang_phase2_semantics.erl)

### Task 2.2.2: Check the Minimal Data and Authority Profile

**Description:** Type `Int`, `Bool`, addition, equality, task results, and
completion predicates while requiring empty effect and capability-requirement
sets in this first frontend slice.

- [x] **Task 2.2.2 Complete** — evidence: [data and authority contract](../../src/phase-02/effects-and-requirements.md)

#### Subtask 2.2.2.1: Reject Type and Name Errors

**Description:** Fail closed on unresolved variables, invalid arithmetic,
incomparable equality operands, result mismatch, and non-Boolean completion.

- [x] **Subtask 2.2.2.1 Complete** — evidence: [negative semantic tests](../../src/phase-02/alang_phase2_compiler_tests.erl)

#### Subtask 2.2.2.2: Freeze the Pure Authority Boundary

**Description:** Reject nonempty `effect` and `requires` lists until Phase 4
introduces the runtime broker and an enforceable typed authority domain.

- [x] **Subtask 2.2.2.2 Complete** — evidence: [parser and semantic rejection paths](../../src/phase-02/alang_phase2_parser.erl)

## Section 2.3: Typed IR, Laws, and Test Views

**Description:** Lower checked source to stable A-Lang-owned IR and validate
its structural and categorical obligations on the same ERTS VM.

- [x] **Section 2.3 Complete** — evidence: [typed task IR](../../src/phase-02/typed-task-ir.md) and [IR implementation](../../src/phase-02/alang_phase2_ir.erl)

### Task 2.3.1: Construct and Validate the Counter IR

**Description:** Lower input, literal, addition, result, equality, and verifier
nodes with deterministic preorder identities and fail on duplicate or dangling
references and invalid roots.

- [x] **Task 2.3.1 Complete** — evidence: [IR lowering and validation](../../src/phase-02/alang_phase2_ir.erl)

#### Subtask 2.3.1.1: Stabilize Node Identity

**Description:** Generate reproducible `node:<task-id>:<preorder>` identities
and deterministic ETF artifacts from identical checked source.

- [x] **Subtask 2.3.1.1 Complete** — evidence: [stability test](../../src/phase-02/alang_phase2_compiler_tests.erl)

#### Subtask 2.3.1.2: Execute Initial Category-Law Tests on ERTS

**Description:** Exhaustively test left identity, right identity, and
associativity for the small pure transformation family on a bounded integer
domain. Treat these as executable checks, not universal proof.

- [x] **Subtask 2.3.1.2 Complete** — evidence: [EUnit law tests](../../src/phase-02/alang_phase2_compiler_tests.erl)

### Task 2.3.2: Implement Nondeployable Reference and Semantic Views

**Description:** Evaluate the fixture under a bounded BEAM test oracle and
derive dry-run, trace, manifest, completion, and explanation projections
without allowing either path to satisfy runtime execution.

- [x] **Task 2.3.2 Complete** — evidence: [reference oracle](../../src/phase-02/alang_phase2_reference.erl) and [semantic views](../../src/phase-02/alang_phase2_views.erl)

#### Subtask 2.3.2.1: Bound and Label the Reference Oracle

**Description:** Limit evaluation steps, deny filesystem and network effects,
and emit `deployable => false` with `engine => beam_test_oracle`.

- [x] **Subtask 2.3.2.1 Complete** — evidence: [oracle result contract](../../src/phase-02/typed-task-ir.md#test-only-reference-oracle)

#### Subtask 2.3.2.2: Cover Every Promoted Node in Views

**Description:** Project every node identity into the trace skeleton and every
task completion root into the completion checklist.

- [x] **Subtask 2.3.2.2 Complete** — evidence: [view coverage tests](../../src/phase-02/alang_phase2_compiler_tests.erl)

## Section 2.4: BEAM Compiler Driver and OTP Bridge

**Description:** Run the complete source-to-fixture command as BEAM code and
connect the checked counter profile to the proven Phase 1 artifact builder.

- [x] **Section 2.4 Complete** — evidence: [compiler driver](../../src/phase-02/alang_phase2_compiler.erl) and [bridge](../../src/phase-02/alang_phase2_bridge.erl)

### Task 2.4.1: Emit Deterministic Compiler Products

**Description:** Write canonical AST, typed IR, semantic views, reference
observation, agreement, bridge input, and compiler residency evidence from one
BEAM-resident command.

- [x] **Task 2.4.1 Complete** — evidence: [`compile-phase-2-source`](../../Makefile)

#### Subtask 2.4.1.1: Hash Canonical and IR Products

**Description:** Record SHA-256 identities over deterministic ETF so repeated
compiler runs can be compared without depending on presentation text.

- [x] **Subtask 2.4.1.1 Complete** — evidence: [evidence record](../../src/phase-02/alang_phase2_compiler.erl)

#### Subtask 2.4.1.2: Keep Compiler and Program Processes Distinct

**Description:** Terminate the build ERTS invocation after artifact creation,
then load and spawn the generated program in the isolated runtime ERTS node.

- [x] **Subtask 2.4.1.2 Complete** — evidence: [Makefile execution boundary](../../Makefile)

### Task 2.4.2: Bridge Only the Proven Counter Profile

**Description:** Recognize the exact checked successor graph and emit the
Phase 1 semantic fixture; reject every other IR shape until Phase 3 implements
general Abstract Format lowering.

- [x] **Task 2.4.2 Complete** — evidence: [fail-closed bridge](../../src/phase-02/alang_phase2_bridge.erl)

#### Subtask 2.4.2.1: Compare the Golden Semantic Fixture

**Description:** Require the generated bridge input to be byte-identical to
the fixture already validated by Phase 1.

- [x] **Subtask 2.4.2.1 Complete** — evidence: [bridge test](../../src/phase-02/alang_phase2_compiler_tests.erl)

#### Subtask 2.4.2.2: Reject Unsupported IR

**Description:** Return a closed error for a different module, task, type,
effect, requirement, or expression graph instead of guessing a lowering.

- [x] **Subtask 2.4.2.2 Complete** — evidence: [negative bridge test](../../src/phase-02/alang_phase2_compiler_tests.erl)

## Section 2.5: Phase 2 Integration Tests

**Description:** Prove that the BEAM-resident compiler produces the proven
artifact and that only the loaded generated BEAM module satisfies the runtime
gate.

- [x] **Section 2.5 Complete** — evidence: [integration evidence](../../src/phase-02/phase-02-integration-evidence.md) and [complete Phase 2 gate](../../Makefile)

### Task 2.5.1: Run Compiler and Robustness Suites on ERTS

**Description:** Execute frontend, canonical, semantic, IR, law, oracle, view,
bridge, residency, and deterministic malformed-input tests as EUnit code on
the pinned VM.

- [x] **Task 2.5.1 Complete** — evidence: [compiler tests](../../src/phase-02/alang_phase2_compiler_tests.erl)

#### Subtask 2.5.1.1: Reject Malformed and Oversized Inputs

**Description:** Exercise all one-byte inputs plus focused truncated and
invalid programs without compiler crashes or atom creation from identifiers.

- [x] **Subtask 2.5.1.1 Complete** — evidence: [malformed-input smoke test](../../src/phase-02/alang_phase2_compiler_tests.erl)

#### Subtask 2.5.1.2: Reproduce Deterministic Products

**Description:** Re-run the compiler and confirm stable canonical and IR
digests and the Phase 1 artifact identity.

- [x] **Subtask 2.5.1.2 Complete** — evidence: [reproduced identities](../../src/phase-02/phase-02-integration-evidence.md#reproduced-artifact-and-observation)

### Task 2.5.2: Reassert Both Residency and No-Interpreter Gates

**Description:** Consult compiler evidence showing a wholly BEAM-resident
toolchain, then run the generated module on a named ERTS node and compare its
public result with the nondeployable oracle.

- [x] **Task 2.5.2 Complete** — evidence: [ERTS integration tests](../../src/phase-02/alang_phase2_integration_tests.erl)

#### Subtask 2.5.2.1: Assert Compiler Residency

**Description:** Require all compiler module paths to end in `.beam`, the
foreign compiler executable list to be empty, and Rust/Cargo artifacts to be
absent from the repository compiler path.

- [x] **Subtask 2.5.2.1 Complete** — evidence: [residency assertions](../../src/phase-02/alang_phase2_compiler_tests.erl)

#### Subtask 2.5.2.2: Assert Generated BEAM Execution

**Description:** Require the observed result `42`, normal process termination,
loaded module `phase1_counter_v1`, scheduler-visible execution, and the Phase 1
no-interpreter proof.

- [x] **Subtask 2.5.2.2 Complete** — evidence: [runtime agreement test](../../src/phase-02/alang_phase2_integration_tests.erl)

## Phase 2 Completion Evidence

**Description:** Record the evidence that authorizes Phase 3 to generalize the
already-working BEAM-resident compiler and runtime semantics.

- [x] The complete trusted compiler path executes as `.beam` modules on ERTS
- [x] No Rust, Cargo, or other foreign executable participates in compilation
- [x] Erlang bootstrap modules compile A-Lang; they never interpret it
- [x] Textual source and deterministic canonical ETF produce identical AST
- [x] Minimal name, data, effect, and requirement checks fail closed
- [x] Typed IR identities and deterministic digests are reproducible
- [x] Initial identity and associativity checks execute on the pinned ERTS VM
- [x] Reference and semantic views are explicitly nondeployable
- [x] The bridge accepts only the exact proven counter profile
- [x] Accepted source executes as an isolated generated BEAM process
