---
title: "Phase 4: Token-Positive Decision and Roadmap Handoff"
kind: note
created: 2026-08-25
maturity: developing
tags:
  - decision-rules
  - evaluation
  - implementation-planning
  - token-efficiency
aliases: []
---

# Phase 4: Token-Positive Decision and Roadmap Handoff

**Description:** Reproduce the complete campaign offline, apply validity,
token, safety, and fidelity predicates in their preregistered order, report
model families and protocols separately, and translate the bounded result into
an architecture decision without changing readable A-Lang semantics.

## Section 4.1: Reproduce the Registered Analysis

**Description:** Validate campaign identity and completeness, compute paired
token and fidelity estimands with the semantic case as the unit, and preserve
all protocol, model-family, runtime-family, and perturbation boundaries.

- [ ] **Section 4.1 Complete**

### Task 4.1.1: Reconcile Campaign Validity and Pairing

**Description:** Recompute registration, code, profile, corpus, prompt,
schedule, observation, usage, score, ceiling, and replay digests before any
efficiency or efficacy result is interpreted.

- [ ] **Task 4.1.1 Complete**

#### Subtask 4.1.1.1: Stop on Invalid Evidence

**Description:** Produce `stop-invalid-token-positive-campaign` for missing or
extra cells, identity drift, unregistered replacement, ceiling excess,
provider-usage failure, replay mismatch, or any other preregistered invalidity
and make no token or fidelity claim.

- [ ] **Subtask 4.1.1.1 Complete**

#### Subtask 4.1.1.2: Preserve the Semantic-case Unit

**Description:** Keep conditions, protocols, and both repetitions paired
inside each case, stratify resampling by runtime family, and reject call-level,
repetition-level, or pooled-model pseudoreplication.

- [ ] **Subtask 4.1.1.2 Complete**

### Task 4.1.2: Run the Seeded Paired Analysis

**Description:** Compute exact offline and provider token contrasts, exact-
fidelity differences, validity, repair, component recovery, robustness, and
safety outcomes with 20,000 deterministic bootstrap resamples from seed
`2026082504`.

- [ ] **Task 4.1.2 Complete**

#### Subtask 4.1.2.1: Report Families and Protocols Separately

**Description:** Emit every primary predicate for each model family and task
protocol, plus runtime-family and perturbation tables; label pooled and per-
repetition summaries descriptive and prohibit compensation across strata.

- [ ] **Subtask 4.1.2.1 Complete**

#### Subtask 4.1.2.2: Reproduce Intervals and Point Gates

**Description:** Require byte-identical cluster-bootstrap intervals, pairwise
token maxima, aggregate and median savings, validity differences, repair
differences, and safety-event classifications across clean ERTS processes.

- [ ] **Subtask 4.1.2.2 Complete**

## Section 4.2: Apply the Ordered Promotion Decision

**Description:** Evaluate the candidate's stated token purpose before safety
and fidelity, with no weighted score, post-hoc threshold, favorable-pool
selection, or manual promotion override.

- [ ] **Section 4.2 Complete**

### Task 4.2.1: Apply Token-positive Predicates First

**Description:** After validity, require every offline and provider token gate
to pass before the candidate can enter the safety and fidelity branch.

- [ ] **Task 4.2.1 Complete**

#### Subtask 4.2.1.1: Reject Pairwise or Aggregate Token Regression

**Description:** Produce `ineligible-token-negative-candidate` on any
noncheaper offline document or request, any higher provider-input pair, less
than 5% provider-input savings in a family/protocol, or increased operational
total tokens in a family/protocol.

- [ ] **Subtask 4.2.1.1 Complete**

#### Subtask 4.2.1.2: Prevent Fidelity from Offsetting Token Cost

**Description:** Mutation-test the decision so perfect fidelity, better
repair, lower latency, or zero safety failures cannot promote a candidate
after one token predicate fails.

- [ ] **Subtask 4.2.1.2 Complete**

### Task 4.2.2: Apply Safety and Fidelity Predicates

**Description:** For a valid token-positive campaign, reject candidate-only
safety failures, then require the registered non-inferiority, validity, repair,
and perturbation results in both model families and all four protocols.

- [ ] **Task 4.2.2 Complete**

#### Subtask 4.2.2.1: Veto Candidate-only Authority Failures

**Description:** Produce `reject-unsafe-mnemonic-candidate` for any candidate-
only unauthorized effect, scope or budget widening, child-authority widening,
false completion, round-trip failure, or inherited enforcement regression.

- [ ] **Subtask 4.2.2.1 Complete**

#### Subtask 4.2.2.2: Distinguish Insufficient Evidence from Superiority

**Description:** Produce `retain-readable-insufficient-fidelity` when token and
safety gates pass but a non-inferiority, validity, repair, or robustness gate
does not; do not call readable source superior unless a separately registered
superiority contrast supports that claim.

- [ ] **Subtask 4.2.2.2 Complete**

### Task 4.2.3: Limit a Positive Architecture Decision

**Description:** Produce `promote-token-positive-mnemonic-view` only when every
gate passes and enable only the exact checked, reversible, source-mapped
candidate version behind compiler tooling.

- [ ] **Task 4.2.3 Complete**

#### Subtask 4.2.3.1: Retain Readable Source and Diagnostics

**Description:** Keep readable v2 canonical for authoring, review, storage,
diagnostics, and execution provenance, and make the promoted view replaceable
or disableable per model profile.

- [ ] **Subtask 4.2.3.1 Complete**

#### Subtask 4.2.3.2: Exclude Broader Claims

**Description:** State that a positive campaign does not establish human
usability, a universal tokenizer optimum, learned-token value, authored
mnemonic syntax, opaque identifier safety, or performance on unregistered
models and tasks.

- [ ] **Subtask 4.2.3.2 Complete**

## Section 4.3: Phase 4 Integration Tests and Handoff

**Description:** Mutation-test every decision branch, reproduce the final
evidence and disposition from clean processes, and update the archive so maps,
inquiries, references, planning status, limitations, and deferred work agree.

- [ ] **Section 4.3 Complete**

### Task 4.3.1: Test Decision Precedence and Immutability

**Description:** Seed invalidity, token, safety, fidelity, validity, repair,
robustness, pooling, threshold, and override defects and require the exact
registered branch and failed-predicate record.

- [ ] **Task 4.3.1 Complete**

#### Subtask 4.3.1.1: Cover Every Terminal Outcome

**Description:** Construct valid evidence fixtures for invalid campaign,
token-negative candidate, unsafe candidate, insufficient fidelity, and
promotion and prove no fixture reaches more than one terminal disposition.

- [ ] **Subtask 4.3.1.1 Complete**

#### Subtask 4.3.1.2: Reproduce the Final Evidence Digest

**Description:** Run independent clean ERTS processes that emit byte-identical
analysis tables, intervals, failed predicates, disposition, limitations, and
architecture-decision digests without network access.

- [ ] **Subtask 4.3.1.2 Complete**

### Task 4.3.2: Reconcile Research and Implementation State

**Description:** Update the compact-projection inquiry, token-efficiency note
and map, language and implementation references, planning indexes, campaign
status, and supported architecture to reflect exactly the bounded result.

- [ ] **Task 4.3.2 Complete**

#### Subtask 4.3.2.1: Preserve Negative and Null Results

**Description:** Record failed token, fidelity, repair, robustness, or safety
predicates and retain useful candidate and ablation evidence even when the
default remains readable source.

- [ ] **Subtask 4.3.2.1 Complete**

#### Subtask 4.3.2.2: Publish Follow-up Boundaries

**Description:** Route new tokenizer profiles, model families, authored
mnemonic syntax, learned tokens, human usability, and broader tasks to new
inquiries or planning streams rather than weakening this frozen campaign.

- [ ] **Subtask 4.3.2.2 Complete**

## Phase 4 Completion Evidence

**Description:** The roadmap completes only when the exact preregistered
decision reproduces, no token-negative candidate can be promoted, and the
archive communicates the bounded result without outcome switching.

- [ ] Campaign identity and completeness are evaluated before all result gates
- [ ] Pairwise and aggregate token predicates precede safety and fidelity
- [ ] No model family, protocol, repetition, or pool compensates for a failed gate
- [ ] Candidate-only safety failures mechanically veto promotion
- [ ] Non-inferiority, validity, repair, and robustness use registered thresholds
- [ ] Every terminal disposition has positive and negative test coverage
- [ ] Final analysis and decision reproduce byte-for-byte offline
- [ ] A positive result enables only the exact checked model-facing version
- [ ] Readable A-Lang remains canonical in every outcome
- [ ] Maps, inquiries, notes, references, indexes, limitations, and deferred work agree

## Connections

- [Phase 3](phase-03-authorized-two-model-campaign.md) supplies the complete,
  replayed observation evidence this phase analyzes.
- [Token-positive promotion note](../../20-notes/model-facing-alang-promotion-must-be-token-positive.md)
  defines the policy the decision implementation must preserve.
