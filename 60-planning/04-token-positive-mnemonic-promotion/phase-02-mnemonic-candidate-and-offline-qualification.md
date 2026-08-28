---
title: "Phase 2: Mnemonic Candidate and Offline Qualification"
kind: note
created: 2026-08-25
maturity: developing
tags:
  - beam
  - implementation-planning
  - language-design
  - token-efficiency
aliases: []
---

# Phase 2: Mnemonic Candidate and Offline Qualification

**Description:** Operationalize the exact R2 re-registration as a checked,
reversible, source-mapped BEAM view without changing its rendering or decoding
behavior; implement all four deterministic protocol oracles; prove the hard
token-positive gate on the frozen corpus; and publish the canonical
preregistration digest that alone can authorize model calls.

## Section 2.1: Bind the Exact R2 Representation

**Description:** Bind the existing R2 representation to the campaign-local P1
role without changing its model-visible bytes, then add exact conformance,
inverse-semantics, source-map, bounds, and readable-diagnostic evidence around
it.

- [x] **Section 2.1 Complete** — see the
  [integration evidence](../../src/token-positive-mnemonic-promotion/section-02-01-integration-evidence.md).

### Task 2.1.1: Reuse Canonical R2 Rendering for `P1`

**Description:** Route P1 rendering through the registered R2 implementation
and version, decode through the existing A-Lang-owned parser and checker, and
require both byte equality with R2 and the same origin-free semantic digest as
readable `P0`.

- [x] **Task 2.1.1 Complete**

#### Subtask 2.1.1.1: Freeze Closed Group-Sensitive Aliases

**Description:** Import without modification the registered R2 mnemonic
declaration, scope, budget, operation, predicate, and relation aliases by
semantic group; preserve unknown readable vocabulary and reject cross-group
meaning, collisions, and unregistered flags.

- [x] **Subtask 2.1.1.1 Complete**

#### Subtask 2.1.1.2: Enforce Bounds and Version Closure

**Description:** Reject oversized representations, unknown versions, duplicate
fields, invalid encodings, excessive aliases, ambiguous values, any candidate
bytes not produced by the canonical renderer, and any canonical P1 rendering
that differs from R2 by even one byte. Require P1 and R2 to accept, reject, and
decode the same valid and invalid conformance inputs.

- [x] **Subtask 2.1.1.2 Complete**

### Task 2.1.2: Produce Readable Source Maps and Diagnostics

**Description:** Map every candidate token and security-relevant semantic field
to readable source spans, original names, or an explicit deterministic
derivation witness.

- [x] **Task 2.1.2 Complete**

#### Subtask 2.1.2.1: Validate Complete Bidirectional Coverage

**Description:** Require contiguous representation coverage, exact alias
origins, keyed authority locations, versioned empty witnesses, and stable maps
under input-map order changes.

- [x] **Subtask 2.1.2.1 Complete**

#### Subtask 2.1.2.2: Keep Readable Source as the Edit Target

**Description:** Render parser, checker, generation, and repair diagnostics in
canonical readable terms and never instruct a person to edit only generated
mnemonic text.

- [x] **Subtask 2.1.2.2 Complete**

## Section 2.2: Implement Protocols and the Authorization Gate

**Description:** Give `P0` and `P1` identical model-task coverage and make
exact token qualification a mechanical prerequisite of any live execution.

- [x] **Section 2.2 Complete** — see the
  [integration evidence](../../src/token-positive-mnemonic-promotion/section-02-02-integration-evidence.md).

### Task 2.2.1: Implement Four Paired Protocol Oracles

**Description:** Materialize comprehension, generation, diagnostic-repair,
and action/completion prompts from the same case semantics and score them
without an LLM judge.

- [x] **Task 2.2.1 Complete**

#### Subtask 2.2.1.1: Freeze Model-visible Bytes

**Description:** Include common instructions, condition legends, case
material, diagnostics, and output scaffolding in canonical prompt records;
exclude condition roles, answer keys, semantic digests, hidden examples, and
cross-trial state.

- [x] **Subtask 2.2.1.1 Complete**

#### Subtask 2.2.1.2: Reject Semantic and Authority Mutants

**Description:** Seed every registered field, negation, digit, unit, path,
dependency, error, child grant, and completion predicate and prove both
condition oracles reject or score the changed meaning distinctly.

- [x] **Subtask 2.2.1.2 Complete**

### Task 2.2.2: Execute the Offline Token-Positive Gate

**Description:** Produce exact document and complete-request reports for every
case and registered tokenizer, then block authorization unless all pairwise,
aggregate, and median predicates pass.

- [x] **Task 2.2.2 Complete**

#### Subtask 2.2.2.1: Count and Attribute Every Request Section

**Description:** Pin tokenizer identities and vocabularies, distinguish exact
counts from unavailable provider usage, and attribute layout, vocabulary,
identifiers, facts, paths, budgets, authority, completion, legends,
instructions, and output scaffolding.

- [x] **Subtask 2.2.2.1 Complete**

#### Subtask 2.2.2.2: Fail on Any Token-negative Pair

**Description:** Reject a candidate when any document or full request is not
strictly cheaper under either tokenizer, when aggregate or median savings fall
below 5%, or when a count, digest, or attribution category is missing.

- [x] **Subtask 2.2.2.2 Complete**

### Task 2.2.3: Freeze the Canonical Preregistration Digest

**Description:** Bind candidate bytes and contracts, corpus, profiles, prompts,
oracles, schedule, token reports, thresholds, bootstrap, ceilings, and code
artifacts into one verified no-call evidence record.

- [x] **Task 2.2.3 Complete**

#### Subtask 2.2.3.1: Reconcile Every Frozen Input

**Description:** Require schema-valid closed records, exact cross-file
identities, complete traceability, clean source maps, green inherited gates,
and no mutable path outside the registration digest.

- [x] **Subtask 2.2.3.1 Complete**

#### Subtask 2.2.3.2: Require Explicit Live Authorization

**Description:** Keep network access disabled by default and require both the
exact qualifying digest and the registered opt-in value before the runner can
submit a model-visible request.

- [x] **Subtask 2.2.3.2 Complete**

## Section 2.3: Phase 2 Integration Tests

**Description:** Prove canonical semantics, protocol symmetry, source mapping,
token eligibility, compiler residency, preregistration immutability, and zero-
call isolation from clean ERTS processes.

- [ ] **Section 2.3 Complete**

### Task 2.3.1: Run Corpus, Property, and Mutation Suites

**Description:** Exercise all frozen and generated valid tasks across both
conditions and four protocols, then seed renderer, decoder, alias, source-map,
accounting, oracle, version, and authority defects.

- [ ] **Task 2.3.1 Complete**

#### Subtask 2.3.1.1: Reproduce Candidate and Token Evidence

**Description:** Require P1/R2 rendering, acceptance, and decoding equality
plus byte-identical semantic digests, source maps, prompts, token reports, and
registration evidence across clean processes and recursively shuffled input
maps.

- [ ] **Subtask 2.3.1.1 Complete**

#### Subtask 2.3.1.2: Measure Mutation Adequacy

**Description:** Report every seeded defect and fail the phase if any mutant
survives its named semantic, token, authorization, or residency gate.

- [ ] **Subtask 2.3.1.2 Complete**

### Task 2.3.2: Inspect Trusted Residency and Isolation

**Description:** Enumerate loaded modules, BEAM imports, build inputs, runtime
calls, and artifacts and reject provider SDKs, ports, NIFs, shell commands,
interpreted forms, or foreign tokenizer executables.

- [ ] **Task 2.3.2 Complete**

#### Subtask 2.3.2.1: Publish the Trusted Module Closure

**Description:** Record deterministic source and BEAM digests for lexer,
parser, checker, renderer, decoder, tokenizer, map, protocol, scorer,
registration, authorization, and replay modules.

- [ ] **Subtask 2.3.2.1 Complete**

#### Subtask 2.3.2.2: Publish Phase 2 Evidence

**Description:** Index all round trips, token-positive predicates, prompt and
schedule reconciliation, mutations, residency, no-call evidence, and clean
commands without making a model-fidelity claim.

- [ ] **Subtask 2.3.2.2 Complete**

## Phase 2 Completion Evidence

**Description:** Model calls are authorized only when the candidate is exactly
reversible, materially token-positive on every frozen case, and bound into an
immutable prospective registration.

- [ ] `P0` and `P1` are canonical, bounded, versioned, and semantically equal
- [ ] `P1` output is byte-for-byte identical to registered R2 on all frozen and generated cases
- [ ] `P1` acceptance and decoding match registered R2 on valid and invalid conformance cases
- [ ] Every mnemonic alias is registered, reversible, and group-sensitive
- [ ] Source maps cover every token and security-relevant field
- [ ] All four protocols have deterministic condition-symmetric oracles
- [ ] Every document and full request is strictly token-positive under both tokenizers
- [ ] Aggregate and median document and request savings are at least 5%
- [ ] Mutations detect semantic, authority, alias, mapping, accounting, and authorization defects
- [ ] Trusted modules load from deterministic `.beam` artifacts on ERTS
- [ ] One complete preregistration digest reproduces with zero model calls
- [ ] Live authorization fails on any digest, profile, prompt, corpus, or code drift

## Connections

- [Phase 1](phase-01-token-positive-contract-and-fresh-corpus.md) supplies the
  prospective contract, fresh corpus, exact profiles, and paired schedule.
- [Campaign README](README.md) defines the token and fidelity rules this phase
  must implement without relaxation.
