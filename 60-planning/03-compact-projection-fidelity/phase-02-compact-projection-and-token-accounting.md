---
title: "Phase 2: Compact Projection and Token Accounting"
kind: note
created: 2026-08-11
maturity: developing
tags:
  - beam
  - implementation-planning
  - language-design
  - token-efficiency
aliases: []
---

# Phase 2: Compact Projection and Token Accounting

**Description:** Implement the six registered surfaces, canonical inverse
decoding, source and alias maps, section-level token accounting, and semantic
round-trip gates as trusted BEAM modules operating on checked A-Lang IR.

**Status:** Planned; every checkbox requires implementation and negative
evidence rather than a text transformation or token-count demonstration.

**Dependencies:** Phase 1 must freeze the projection vocabulary and scientific
roles. The existing v2 frontend, checker, typed IR, semantic digest, and JSON
control remain authoritative.

## Section 2.1: Token Audit and Representation Registry

**Description:** Make token cost attributable, reproducible, and explicitly
dependent on a declared model profile rather than character length.

- [ ] **Section 2.1 Complete**

### Task 2.1.1: Implement the BEAM Token-Audit Contract

**Description:** Define a closed record for representation bytes, document and
full-request token counts, lexeme and section attribution, provider usage,
tokenizer identity, and count provenance.

- [ ] **Task 2.1.1 Complete**

#### Subtask 2.1.1.1: Count Registered Tokenizers Deterministically

**Description:** Implement or bind only approved BEAM-resident tokenizer logic,
pin vocabulary and pre-tokenizer digests, reject unknown model aliases, and
separate exact counts from proxy estimates.

- [ ] **Subtask 2.1.1.1 Complete**

#### Subtask 2.1.1.2: Attribute Cost to Stable Semantic Sections

**Description:** Report layout, keywords, identifiers, facts, paths, budgets,
authority, completion, legends, common instructions, and output scaffolding so
savings cannot be credited to accidentally omitted semantics.

- [ ] **Subtask 2.1.1.2 Complete**

### Task 2.1.2: Register Canonical Surface IDs and Renderers

**Description:** Dispatch `R0` through `R5` by closed IDs, return byte-stable
model-visible forms and provenance, and reject unregistered flags or condition
combinations.

- [ ] **Task 2.1.2 Complete**

#### Subtask 2.1.2.1: Render Readable, Minified, Alias, and JSON Controls

**Description:** Preserve readable v2 semantics, remove only grammar-optional
layout for `R1`, apply only registered mnemonic aliases for `R2`, and reuse the
independent typed-JSON path for `R5`.

- [ ] **Subtask 2.1.2.1 Complete**

#### Subtask 2.1.2.2: Reject Surface and Version Ambiguity

**Description:** Require an exact representation version, one canonical byte
rendering per semantic input, duplicate-aware decoding, bounded inputs, and
stable failures for unknown versions, aliases, fields, or encodings.

- [ ] **Subtask 2.1.2.2 Complete**

## Section 2.2: Checked Compact Projection and Inverse Decoder

**Description:** Serialize checked semantics compactly without inventing a
parallel unchecked language or relying on positional security fields.

- [ ] **Section 2.2 Complete**

### Task 2.2.1: Implement `alang-model-v1`

**Description:** Project the canonical checked IR into fixed mnemonic
vocabulary, repeated-reference aliases, and reconstructible schema elision
while retaining keyed authority, budgets, errors, and completion predicates.

- [ ] **Task 2.2.1 Complete**

#### Subtask 2.2.1.1: Derive Only Reconstructible Declarations

**Description:** Omit a field only when the registered decoder derives its
exact checked value from retained structure; reject ambiguous effects,
requirements, scopes, child grants, limits, or completion evidence.

- [ ] **Subtask 2.2.1.1 Complete**

#### Subtask 2.2.1.2: Assign Reversible Local Aliases

**Description:** Emit descriptive identities once, assign deterministic
compiler-local aliases only to repeated references, include a bounded reverse
map, and reject collisions, shadowing, same-prefix ambiguity, or map tampering.

- [ ] **Subtask 2.2.1.2 Complete**

### Task 2.2.2: Implement Canonical Decoding and Semantic Equality

**Description:** Parse the projection into A-Lang-owned forms, restore every
derived or aliased value, run the same checker, and compare canonical semantic
digests before the result can proceed.

- [ ] **Task 2.2.2 Complete**

#### Subtask 2.2.2.1: Prove Checked-IR Round Trip

**Description:** Require `decode(encode(IR))` to reproduce the origin-free
canonical IR and semantic digest for every corpus case and generated valid
task, with stable errors at the smallest compact and readable source paths.

- [ ] **Subtask 2.2.2.1 Complete**

#### Subtask 2.2.2.2: Reject Authority and Meaning Mutants

**Description:** Seed dropped negations, transposed digits, changed units,
missing effects, wider scopes, extra child grants, altered dependencies,
weakened completion, alias swaps, and unknown fields; require every mutant to
fail or produce a different semantic digest.

- [ ] **Subtask 2.2.2.2 Complete**

## Section 2.3: Opaque-Identifier Control and Source Mapping

**Description:** Isolate identifier compression as a nonpromotable ablation
while ensuring all model-facing failures remain explainable in readable-source
terms.

- [ ] **Section 2.3 Complete**

### Task 2.3.1: Implement the `R4` Negative Control

**Description:** Replace eligible user identifiers with deterministic opaque
aliases after checked projection, preserving literal facts, paths, units, and
security vocabulary and carrying an exact reverse map.

- [ ] **Task 2.3.1 Complete**

#### Subtask 2.3.1.1: Define Eligible and Protected Names

**Description:** Register which task, binding, action, and resource references
may be renamed and protect strings, paths, enum tags, effect names, scopes,
budgets, model profiles, and completion predicates from accidental rewriting.

- [ ] **Subtask 2.3.1.1 Complete**

#### Subtask 2.3.1.2: Enforce Nonpromotion and Reverse Mapping

**Description:** Mark all `R4` observations as ablation-only in contracts,
schedules, evidence, and decision code; prove the control cannot be selected
as a default even if it wins every token and fidelity metric.

- [ ] **Subtask 2.3.1.2 Complete**

### Task 2.3.2: Produce Readable Source Maps and Diagnostics

**Description:** Map every compact byte range, alias, restored declaration,
and checker error back to its readable source construct and semantic path.

- [ ] **Task 2.3.2 Complete**

#### Subtask 2.3.2.1: Validate Bidirectional Origin Maps

**Description:** Require every compact token to have a declared generated or
source origin and every security-relevant readable field to have a compact
location or explicit derivation witness.

- [ ] **Subtask 2.3.2.1 Complete**

#### Subtask 2.3.2.2: Render Diagnostics in Canonical Source Terms

**Description:** Report original task, action, resource, budget, and field
names with readable spans and optional compact spans; never expose only an
opaque alias or make a user edit generated compact text.

- [ ] **Subtask 2.3.2.2 Complete**

## Section 2.4: Phase 2 Integration Tests

**Description:** Prove all six representations are deterministic, semantically
matched, bounded, mutation-sensitive, source-mapped, and implemented wholly on
the trusted BEAM path.

- [ ] **Section 2.4 Complete**

### Task 2.4.1: Run Corpus, Property, and Mutation Suites

**Description:** Render and decode the development and confirmatory corpora,
then generate valid and invalid checked tasks across every registered field,
boundary, alias count, and representation version.

- [ ] **Task 2.4.1 Complete**

#### Subtask 2.4.1.1: Reproduce All Surfaces and Token Reports

**Description:** Require byte-identical renderings, semantic digests, source
maps, and token reports across clean ERTS processes and shuffled input map
orders.

- [ ] **Subtask 2.4.1.1 Complete**

#### Subtask 2.4.1.2: Measure Mutation Adequacy

**Description:** Prove seeded decoder, derivation, alias, token-attribution,
source-map, version, and authority defects cause the named test gates to fail.

- [ ] **Subtask 2.4.1.2 Complete**

### Task 2.4.2: Reassert Compiler Residency and Isolation

**Description:** Inspect loaded modules, build inputs, runtime calls, and
artifacts to prove every trusted transform runs from `.beam` on ERTS and no
foreign tokenizer or language interpreter entered the path.

- [ ] **Task 2.4.2 Complete**

#### Subtask 2.4.2.1: Inspect the Trusted Module Closure

**Description:** Enumerate lexer, parser, checker, projector, decoder, audit,
source-map, and validator modules and fail on interpreted forms, provider SDKs,
ports, NIFs, shell commands, or non-BEAM executables.

- [ ] **Subtask 2.4.2.1 Complete**

#### Subtask 2.4.2.2: Publish Phase 2 Evidence

**Description:** Index round trips, semantic equality, negative cases, token
attribution, source maps, mutation results, module closure, and clean-build
commands without claiming model fidelity from offline transformations.

- [ ] **Subtask 2.4.2.2 Complete**

## Phase 2 Completion Evidence

**Description:** Authorize model-task harness work only when the compact form
is a deterministic projection of checked semantics rather than a plausible
but unverified string rewrite.

- [ ] All six registered surfaces have canonical byte renderings and closed versions
- [ ] Every surface decodes or normalizes to the same case semantic digest
- [ ] `alang-model-v1` uses only registered aliases and reconstructible elisions
- [ ] Keyed budgets, scopes, effects, child grants, errors, and completion remain exact
- [ ] Opaque identifiers are isolated and mechanically nonpromotable
- [ ] Source maps cover every compact token and every security-relevant readable field
- [ ] Token reports distinguish exact provider/profile counts from proxies
- [ ] Property and mutation suites detect semantic, authority, alias, version, and accounting defects
- [ ] Trusted projection modules load from deterministic `.beam` artifacts on ERTS
- [ ] Clean-process evidence reproduces without network access or foreign executables
