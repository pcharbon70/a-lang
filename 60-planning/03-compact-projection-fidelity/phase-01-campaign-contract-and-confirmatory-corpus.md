---
title: "Phase 1: Campaign Contract and Confirmatory Corpus"
kind: note
created: 2026-08-11
maturity: developing
tags:
  - evaluation
  - implementation-planning
  - llm-agents
  - token-efficiency
aliases: []
---

# Phase 1: Campaign Contract and Confirmatory Corpus

**Description:** Freeze the causal question, representation conditions, task
protocols, model profiles, power assumptions, independent semantic cases,
metrics, safety vetoes, operational ceilings, and ordered outcomes before a
model can observe any new campaign material.

**Status:** Section 1.1 complete; Sections 1.2–1.4 remain planned. Reproduce
the completed contract and decision gate with `make test-compact-section-1-1`.

**Dependencies:** The compact-syntax
[synthesis](../../20-notes/token-efficient-syntax-for-a-lang.md),
[inquiry](../../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md),
and the frozen contracts from
[planning stream 02](../02-effectful-source-fidelity/README.md) define the
starting semantics. They do not authorize mutation or reuse of prior outcomes.

## Section 1.1: Estimand, Conditions, and Outcomes

**Description:** Express the question as machine-readable contrasts with no
post-hoc composite score or ambiguity about what a positive result promotes.

- [x] **Section 1.1 Complete** — see the
  [integration evidence](../../src/compact-projection-fidelity/section-01-01-integration-evidence.md).

### Task 1.1.1: Register the Representation Contrasts

**Description:** Define `R0` through `R5`, their generation paths, exposure
legends, eligible task protocols, and scientific roles so every pair differs
only by the intended representation transform.

- [x] **Task 1.1.1 Complete**

#### Subtask 1.1.1.1: Freeze the Six Comprehension Conditions

**Description:** Register readable v2, layout-minified, mnemonic-alias,
checked-compact, opaque-identifier, and typed-JSON forms with stable IDs;
require common semantics and declare `R3` the only promotion candidate.

- [x] **Subtask 1.1.1.1 Complete**

#### Subtask 1.1.1.2: Freeze the Core Bidirectional Contrast

**Description:** Restrict generation, repair, and action/completion protocols
to paired `R0` and `R3` cells, and register comprehension ablations as
mechanism evidence rather than alternative promotion paths.

- [x] **Subtask 1.1.1.2 Complete**

### Task 1.1.2: Register Metrics and the Ordered Decision

**Description:** Encode token, fidelity, validity, robustness, safety, and
cost measures separately and define the only valid final dispositions before
any campaign output exists.

- [x] **Task 1.1.2 Complete**

#### Subtask 1.1.2.1: Define Primary and Secondary Estimands

**Description:** Make paired token reduction and exact semantic non-
inferiority primary; register component recovery, parse/check validity,
repair, perturbation strata, latency, cost, and mechanism ablations as named
secondary results without a hidden weighted aggregate.

- [x] **Subtask 1.1.2.1 Complete**

#### Subtask 1.1.2.2: Encode Promotion, Retention, Rejection, and Invalidity

**Description:** Implement the exact ordered predicates in data: invalidity
precedes safety rejection, promotion requires every gate, and a valid
nonpromotion records insufficient evidence without claiming readable
superiority unless a separate registered contrast supports it.

- [x] **Subtask 1.1.2.2 Complete**

## Section 1.2: Power, Pairing, and Schedule Contract

**Description:** Choose the smallest campaign capable of answering the
registered non-inferiority question while treating semantic cases—not calls
or repetitions—as independent evidence.

- [ ] **Section 1.2 Complete**

### Task 1.2.1: Perform the Simulation-Based Power Audit

**Description:** Simulate paired exact-fidelity outcomes over plausible
baseline rates and compact/readable discordance, document the assumptions,
and verify the initial 24-case design has acceptable power for the pooled
five-point non-inferiority gate.

- [ ] **Task 1.2.1 Complete**

#### Subtask 1.2.1.1: Register Power Scenarios and Acceptance

**Description:** Include optimistic, central, and adverse baseline and
discordance scenarios; require at least 80% power under the registered central
no-loss scenario and report where the design remains underpowered.

- [ ] **Subtask 1.2.1.1 Complete**

#### Subtask 1.2.1.2: Freeze Any Corpus Expansion Before Observation

**Description:** If the minimum design fails the audit, expand in balanced
24-case blocks, recalculate every cell and ceiling, and freeze the larger count
before prompts are exposed; forbid outcome-dependent stopping or shrinkage.

- [ ] **Subtask 1.2.1.2 Complete**

### Task 1.2.2: Materialize the Paired Randomized Schedule

**Description:** Expand case, task, condition, model, and repetition factors
into opaque cells while preserving paired comparisons, family balance, and
separation between repetitions.

- [ ] **Task 1.2.2 Complete**

#### Subtask 1.2.2.1: Apply Seeded Counterbalancing

**Description:** Use seed `2026081103` to randomize condition order within
model/task/family/repetition blocks, prevent adjacent repetitions of one case,
and retain a deterministic inverse map outside model-visible material.

- [ ] **Subtask 1.2.2.1 Complete**

#### Subtask 1.2.2.2: Validate Counts, Pairing, and Leakage Controls

**Description:** Require exactly the registered cells, two condition members
for every core pair, all six comprehension members, no duplicate trial, and no
condition label, oracle, digest, source filename, or expected result in a
model-visible request.

- [ ] **Subtask 1.2.2.2 Complete**

## Section 1.3: Confirmatory Corpus and Operational Registration

**Description:** Build an independent semantic sample and freeze the exact
profiles and resource bounds needed to run it without touching the prior
campaign.

- [ ] **Section 1.3 Complete**

### Task 1.3.1: Author the Held-Out Semantic Cases

**Description:** Create at least 24 new cases with representation-neutral
oracles and balanced families, perturbations, authority boundaries, and
terminal outcomes; do not copy names, paths, facts, or answer keys from the
development corpus.

- [ ] **Task 1.3.1 Complete**

#### Subtask 1.3.1.1: Cover the Three Runtime Families and Eight Strata

**Description:** Author eight cases each for single-model artifact, repair and
publish, and attenuated delegation, crossing simple, constraint-heavy,
scope/budget, error, missing-information, irrelevant-context, injection, and
lexical/value perturbation strata.

- [ ] **Subtask 1.3.1.1 Complete**

#### Subtask 1.3.1.2: Review Independence and Semantic Balance

**Description:** Run a blinded content audit for copied phrasing, tokenizer-
specific alias favoritism, unequal field density, inconsistent authority, and
oracle leakage; record exclusions and replacements before the digest freeze.

- [ ] **Subtask 1.3.1.2 Complete**

### Task 1.3.2: Freeze Model Profiles and Campaign Ceilings

**Description:** Pin two exact model families and all provider parameters,
token accounting, availability probes, call bounds, latency limits, accepted
bytes, credentials policy, and monetary or local-compute ceiling.

- [ ] **Task 1.3.2 Complete**

#### Subtask 1.3.2.1: Register Exact Model and Tokenizer Identity

**Description:** Prefer the two valid profiles from stream 02 for
comparability; otherwise choose replacements only before preregistration,
record the reason and exact immutable identities, and prohibit aliases or
silent upgrades during execution.

- [ ] **Subtask 1.3.2.1 Complete**

#### Subtask 1.3.2.2: Register Request and Evidence Ceilings

**Description:** Freeze the 1,152-primary-cell baseline, 2,304 hard request
ceiling, per-request input/output/time/byte bounds, total cost authorization,
replacement semantics, retention policy, and invalid-campaign triggers.

- [ ] **Subtask 1.3.2.2 Complete**

## Section 1.4: Phase 1 Integration Tests

**Description:** Prove the proposed experiment is internally complete,
balanced, independent from development data, and reproducible before any
projector or campaign implementation can claim alignment with it.

- [ ] **Section 1.4 Complete**

### Task 1.4.1: Validate Contracts, Corpus, and Schedule

**Description:** Run BEAM validators over every schema, oracle, corpus entry,
condition, profile, metric, decision predicate, cell, and ceiling from a clean
checkout.

- [ ] **Task 1.4.1 Complete**

#### Subtask 1.4.1.1: Reject Experimental-Contract Mutants

**Description:** Detect missing cells, duplicate cases, leaked labels, changed
seeds, pooled model gates, repetition pseudoreplication, promotable controls,
weakened margins, expanded authority, and unbounded replacements.

- [ ] **Subtask 1.4.1.1 Complete**

#### Subtask 1.4.1.2: Reproduce the Registration Inputs

**Description:** Canonicalize and hash the contracts, cases, oracles, profiles,
legends, prompts, power report, schedule, and decision data; reproduce the
ordered manifest and digest byte-for-byte in a clean ERTS process.

- [ ] **Subtask 1.4.1.2 Complete**

### Task 1.4.2: Audit Scope and Research Traceability

**Description:** Confirm every condition and metric traces to a documented
hypothesis and that no compact authored surface, macro training, human-
usability claim, or unrelated language feature entered the campaign.

- [ ] **Task 1.4.2 Complete**

#### Subtask 1.4.2.1: Preserve the Prior Campaign Boundary

**Description:** Verify no file or digest under the frozen stream-02 corpus,
contracts, schedule, prompts, evidence, or decision changed as part of this
campaign design.

- [ ] **Subtask 1.4.2.1 Complete**

#### Subtask 1.4.2.2: Publish Phase 1 Evidence

**Description:** Record power, balance, independence, manifest, profile,
ceiling, negative-test, and traceability results with reproduction commands
and clearly mark that no model observation has occurred.

- [ ] **Subtask 1.4.2.2 Complete**

## Phase 1 Completion Evidence

**Description:** Authorize projection implementation only after the scientific
contract can no longer drift in response to implementation convenience or
model behavior.

- [ ] Machine-readable conditions, task protocols, metrics, margins, vetoes, and outcomes validate
- [ ] The power audit and any resulting balanced corpus expansion are frozen
- [ ] Development and confirmatory cases are content-separated and labeled
- [ ] Every confirmatory case has one checked representation-neutral oracle
- [ ] Model profiles, tokenizers, parameters, legends, prompts, ceilings, and schedule are exact
- [ ] The primary-cell and hard-request counts reconcile mechanically
- [ ] Mutants prove that leakage, pooling, pseudoreplication, substitution, and threshold weakening fail
- [ ] The prior campaign's frozen bytes and digests remain unchanged
- [ ] One canonical Phase 1 evidence record reproduces from a clean checkout
- [ ] Evidence explicitly states that no model call or efficacy observation has occurred
