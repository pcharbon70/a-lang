---
title: "Phase 1: Experiment Contract and Frozen Corpus"
kind: note
created: 2026-08-05
maturity: developing
tags:
  - evaluation
  - implementation-planning
  - llm-agents
  - task-language
aliases: []
---

# Phase 1: Experiment Contract and Frozen Corpus

**Description:** Freeze the semantic question, paired representations, task
corpus, model cells, deterministic scorer, statistical rule, safety vetoes,
budget, and evidence policy before extending the compiler or observing a hosted
model. This prevents the language or threshold from being tuned after results
are known.

**Status:** In progress — Section 1.1 is complete and Sections 1.2–1.4 remain
planned.

**Dependencies:** The [Phase 8 architecture decision](../../src/phase-08/proof-of-concept-architecture-decision.md)
has authorized only this effectful-source fidelity question. The existing typed
IR, broker, durability, model, child, workspace, and completion contracts are
the fixed substrate rather than experimental variables.

## Section 1.1: Operational Fidelity and Decision Contract

**Description:** Turn “task-specification fidelity” into a closed record,
deterministic observations, and a pre-registered architecture decision.

- [x] **Section 1.1 Complete** — reproduce with
  `make test-fidelity-section-1-1`; inspect the [BEAM validators](../../src/effectful-source-fidelity/README.md)
  and [frozen contracts](../../assets/effectful-source-fidelity/contracts/README.md).

### Task 1.1.1: Define the Comprehension Record and Semantic Oracle

**Description:** Define the exact information a model must recover from either
surface and a representation-neutral answer key against which recovery can be
scored without an LLM judge.

- [x] **Task 1.1.1 Complete**

#### Subtask 1.1.1.1: Specify `alang_task_comprehension_v1`

**Description:** Create a closed JSON schema and matching BEAM validator for
case identity, goal facts, inputs, ordered actions and dependencies, effects,
requirements, scopes, budgets, error branches, child attenuation, completion
predicates, clarification needs, and terminal class; reject unknown fields,
duplicates, dynamic tags, and out-of-bound values.

- [x] **Subtask 1.1.1.1 Complete** — the closed schema and duplicate-aware
  BEAM validator reject unknown fields, dynamic operations, invalid
  dependencies, out-of-bound values, and child authority widening.

#### Subtask 1.1.1.2: Specify Representation-Neutral Answer Keys

**Description:** Store each case's expected comprehension record and semantic
digest independently from A-Lang and JSON origins, comments, key order, and
spelling so only meaning contributes to the primary score.

- [x] **Subtask 1.1.1.2 Complete** — answer keys bind a case to the canonical
  digest of its origin-free, presentation-normalized semantic record.

### Task 1.1.2: Freeze Metrics, Statistics, and Outcomes

**Description:** Make every reported metric and the promote/replace/stop rule
machine-readable before a hosted request can run.

- [x] **Task 1.1.2 Complete**

#### Subtask 1.1.2.1: Register Primary and Secondary Metrics

**Description:** Make exact normalized semantic fidelity primary; register
component exactness, omissions, inventions, authority widening, false
completion, repair yield, latency, tokens, and cost as secondary observations
with no hidden weighting or model-graded field. Score every definitive refusal,
truncation, malformed JSON, and schema-invalid first response as zero exact
fidelity rather than excluding or replacing it.

- [x] **Subtask 1.1.2.1 Complete** — the machine-readable contract freezes one
  exact primary metric, nine secondary observations, and zero-credit invalid
  first-response classes.

#### Subtask 1.1.2.2: Encode the Frozen Decision Rule

**Description:** Require a five-point A-Lang advantage and a positive paired
95% percentile interval in each model family, resampling the eight semantic
cases within each task family while retaining all three paired repetitions,
using 10,000 resamples with seed `20260805`; otherwise replace with JSON when
both families reach 80%, or stop surface expansion when they do not, with any
safety regression acting as a veto.

- [x] **Subtask 1.1.2.2 Complete** — the BEAM decision module enforces the
  per-family five-point and positive-interval gate, JSON floor, invalid-run
  outcome, and safety veto without configurable thresholds.

## Section 1.2: Paired Representation Contract

**Description:** Define the user-authored A-Lang and typed-JSON conditions so
they differ only in source notation and both remain compiler inputs.

- [ ] **Section 1.2 Complete**

### Task 1.2.1: Freeze the A-Lang and JSON Surface Roles

**Description:** Declare `alang-source-v2` as the candidate and
`alang-task-json-v1` as the sole conventional control, with both covering the
same types, effects, requirements, limits, sequencing, result matching, child
attenuation, and completion vocabulary.

- [ ] **Task 1.2.1 Complete**

#### Subtask 1.2.1.1: Define the Candidate Source Contract

**Description:** Record the minimal effectful constructs that Phase 2 must
parse, preserve `alang-source-v1`, and prohibit recursion, polymorphism,
parallelism, dynamic operations, arbitrary calls, and categorical surface
notation.

- [ ] **Subtask 1.2.1.1 Complete**

#### Subtask 1.2.1.2: Define the Closed JSON Control Schema

**Description:** Define a versioned object schema decoded with OTP JSON,
retain source pointers for diagnostics, reject unknown or duplicate semantic
fields, and prohibit direct typed-IR node identifiers or backend terms.

- [ ] **Subtask 1.2.1.2 Complete**

### Task 1.2.2: Define Semantic Pairing and Leakage Controls

**Description:** Ensure each hand-authored pair has one shared answer key while
preventing either notation, prompt, filename, or ordering from revealing that
answer.

- [ ] **Task 1.2.2 Complete**

#### Subtask 1.2.2.1: Specify Normalized Semantic Equality

**Description:** Define a canonical representation that removes origins and
presentation order but retains task order, dependencies, authority, budgets,
branches, child bounds, and completion semantics; require equal digests before
a pair enters the corpus.

- [ ] **Subtask 1.2.2.1 Complete**

#### Subtask 1.2.2.2: Specify Opaque Trial Materialization

**Description:** Assign opaque case and condition identifiers only after corpus
validation, randomize presentation order with schedule seed `2026080501`, and
keep notation labels and answer keys out of the model-visible prompt. Treat the
surface representation itself as the visible experimental treatment rather
than claiming that the model is blind to it.

- [ ] **Subtask 1.2.2.2 Complete**

## Section 1.3: Corpus, Provider, and Evidence Registration

**Description:** Pre-register all 24 cases, two exact model profiles, operational
ceilings, and retained evidence before implementation can run a live campaign.

- [ ] **Section 1.3 Complete**

### Task 1.3.1: Author and Review the Twenty-Four Semantic Cases

**Description:** Hand-author eight cases for each of the single-model,
repair-and-publish, and attenuated-delegation families without generating an
acceptance case from IR.

- [ ] **Task 1.3.1 Complete**

#### Subtask 1.3.1.1: Cover the Eight Required Variants per Family

**Description:** Include simple, constraint-heavy, scope/budget, error-branch,
missing-information, irrelevant-context, prompt-injection, and
semantics-preserving perturbation cases, each with a declared expected
terminal class.

- [ ] **Subtask 1.3.1.1 Complete**

#### Subtask 1.3.1.2: Review Corpus Balance and Independence

**Description:** Confirm equal condition counts, equivalent semantic detail,
no copied answer-key serialization, no condition-specific demonstrations, and
no topic or difficulty imbalance that predicts notation.

- [ ] **Subtask 1.3.1.2 Complete**

### Task 1.3.2: Register Hosted Profiles and Operational Bounds

**Description:** Pin the two provider families and define live-call, retry,
repair, timeout, cost, privacy, and retention behavior without making the
default test suite network-dependent.

- [ ] **Task 1.3.2 Complete**

#### Subtask 1.3.2.1: Pin Exact Provider Profiles

**Description:** Register OpenAI `gpt-5.6-terra` and Anthropic
`claude-sonnet-5`, medium effort, one turn, no tools or provider schema
constraint, 8,192-token provider output and 8,192-byte accepted-output bounds,
and fail when an exact identifier is unavailable.

- [ ] **Subtask 1.3.2.1 Complete**

#### Subtask 1.3.2.2: Freeze Campaign and Evidence Ceilings

**Description:** Require explicit live-call consent and both credentials, cap
primary calls at 288 and all calls at 576 or USD 200, classify uncertain
outcomes without blind retry, allow replacements only where no definitive model
response exists, and retain only redacted prompts, normalized responses,
scores, bounded metadata, and digests.

- [ ] **Subtask 1.3.2.2 Complete**

## Section 1.4: Phase 1 Integration Tests

**Description:** Prove the experiment is complete, internally coherent, and
frozen before any compiler or hosted-model implementation begins.

- [ ] **Section 1.4 Complete**

### Task 1.4.1: Validate Contracts and Corpus Mechanically

**Description:** Run BEAM-native validators over schemas, configurations,
semantic answer keys, pair counts, required variants, unique identities,
bounded values, and equal normalized pair digests.

- [ ] **Task 1.4.1 Complete**

#### Subtask 1.4.1.1: Reject Contract and Corpus Mutants

**Description:** Seed unknown fields, duplicate cases, missing cells, leaked
answers, unequal semantics, unbounded limits, alias model identifiers, and
post-freeze threshold changes and require specific failures.

- [ ] **Subtask 1.4.1.1 Complete**

#### Subtask 1.4.1.2: Reproduce the Pre-Registration Digest

**Description:** Hash the ordered contract, corpus, answer keys, provider
profiles, prompt template, scoring rules, and decision rule twice from a clean
checkout and require byte-identical pre-registration evidence.

- [ ] **Subtask 1.4.1.2 Complete**

### Task 1.4.2: Audit Scope and Research Traceability

**Description:** Confirm every planned construct answers the Phase 8 boundary,
every frozen feature stays absent, and every claimed metric maps to the active
task-language inquiry.

- [ ] **Task 1.4.2 Complete**

#### Subtask 1.4.2.1: Run the Frozen-Scope Audit

**Description:** Search contracts and fixtures for recursion, polymorphism,
parallelism, distribution, delegation protocols, extra effect families,
self-hosting, package management, and user-visible categorical syntax and fail
on any occurrence outside explicit non-goals.

- [ ] **Subtask 1.4.2.1 Complete**

#### Subtask 1.4.2.2: Publish Phase 1 Evidence

**Description:** Record the pre-registration digest, corpus inventory, model
profiles, cost/call bounds, metric definitions, decision outcomes, review
findings, and exact commands needed to reproduce the phase gate.

- [ ] **Subtask 1.4.2.2 Complete**

## Phase 1 Completion Evidence

**Description:** Authorize source implementation only after the experiment can
no longer be silently reshaped around observed results.

- [ ] Closed comprehension and answer-key schemas validate
- [ ] Twenty-four balanced semantic cases and forty-eight source documents exist
- [ ] Every A-Lang/JSON pair has one equal normalized semantic digest
- [ ] Exact model profiles, prompts, repetitions, call limits, and cost ceiling are frozen
- [ ] Metrics, bootstrap method, safety vetoes, and outcomes are machine-readable
- [ ] Negative contract and corpus mutants are detected
- [ ] Pre-registration evidence reproduces byte-for-byte
- [ ] No hosted model has been called before the pre-registration digest is frozen
