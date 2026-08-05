---
title: "Phase 6: Fidelity Decision and Roadmap Handoff"
kind: note
created: 2026-08-05
maturity: developing
tags:
  - architecture-decision
  - evaluation
  - implementation-planning
  - llm-agents
  - proof-of-concept
aliases: []
---

# Phase 6: Fidelity Decision and Roadmap Handoff

**Description:** Freeze the hosted-evaluation evidence, apply the
pre-registered promote/replace/stop rule without discretionary threshold
changes, and reconcile the implementation and research archive with the
result. This phase decides the next disposition of the user-facing notation;
it does not convert a prototype into production approval.

**Status:** Planned; every item remains unchecked until reproducible evidence
exists.

**Dependencies:** Phase 5 complete with either a valid, fully accounted hosted
campaign and byte-reproducible offline analysis or an explicitly invalid
campaign whose missing cells and failure causes are preserved. All Phase 1–4
contracts and inherited security gates remain unchanged.

## Section 6.1: Evidence Freeze and Campaign Validity

**Description:** Close the experiment before inspecting comparative outcomes,
prove that retained records correspond to the pre-registered design, and state
whether the campaign can support an efficacy decision.

- [ ] **Section 6.1 Complete**

### Task 6.1.1: Reconcile Pre-Registration, Calls, and Retained Records

**Description:** Join every frozen case, condition, family, repetition, prompt,
provider attempt, repair, replacement, normalized response, score, and cost
into one append-only evidence manifest with no unexplained gap or duplicate.

- [ ] **Task 6.1.1 Complete**

#### Subtask 6.1.1.1: Verify Contract and Content Digests

**Description:** Recompute digests for the pre-registration, corpus, paired
representations, answer keys, prompt, result schema, schedule, normalized
responses, scorer, bootstrap implementation, and provider-profile record and
reject evidence produced under a changed input or analysis contract.

- [ ] **Subtask 6.1.1.1 Complete**

#### Subtask 6.1.1.2: Account for Attempts, Missingness, and Cost

**Description:** Reconcile the sidecar and durable journals with evidence
records, classify every retry, repair, uncertain submission, replacement,
refusal, truncation, and missing cell, and require totals to remain within the
576-call and USD 200 ceilings.

- [ ] **Subtask 6.1.1.2 Complete**

### Task 6.1.2: Determine Campaign Validity Mechanically

**Description:** Apply the frozen completeness and integrity predicates in
code so a reviewer cannot selectively exclude trials, forgive a model
substitution, or reinterpret an operational failure after seeing results.

- [ ] **Task 6.1.2 Complete**

#### Subtask 6.1.2.1: Evaluate Validity Predicates

**Description:** Require the exact registered model IDs, three scorable primary
observations for every case/condition/model cell—including zero-fidelity closed
classifications for definitive non-record responses—byte-stable prompts,
matched semantic pairs, authorized call and replacement transitions, complete
cost accounting, clean redaction, and reproducible scores; emit each failing
predicate explicitly.

- [ ] **Subtask 6.1.2.1 Complete**

#### Subtask 6.1.2.2: Freeze the Analysis Dataset

**Description:** For a valid campaign, emit the immutable primary and secondary
analysis tables and their digests; for an invalid campaign, emit only the
accounting and validity report and forbid efficacy intervals or a claim that
one representation performed better.

- [ ] **Subtask 6.1.2.2 Complete**

## Section 6.2: Frozen Architecture Decision

**Description:** Compute one machine-readable disposition from valid evidence,
including per-model effect sizes and safety vetoes, or conservatively stop
surface expansion when the campaign cannot support comparison.

- [ ] **Section 6.2 Complete**

### Task 6.2.1: Generate the Per-Model Decision Inputs

**Description:** Produce for each model family the A-Lang and JSON exact-
fidelity rates, paired difference, task-family-stratified 95% interval,
component results, unauthorized-effect count, false-completion count, and all
inherited regression-gate outcomes.

- [ ] **Task 6.2.1 Complete**

#### Subtask 6.2.1.1: Reproduce Paired Statistics Independently

**Description:** Recompute the 10,000-resample interval with seed `20260805`
from the frozen table in a fresh ERTS process, resampling semantic cases within
task family while retaining paired repetitions, compare the percentile
interval byte-for-byte with Phase 5 evidence, and keep pooled statistics
descriptive rather than using them to override a failing model family.

- [ ] **Subtask 6.2.1.1 Complete**

#### Subtask 6.2.1.2: Evaluate Safety and Regression Vetoes

**Description:** Require zero additional unauthorized effects and false
completions for A-Lang relative to JSON and require all compiler, broker,
durability, adversarial, fault, mutation, child, workspace, and completion
gates to remain green before promotion is possible.

- [ ] **Subtask 6.2.1.2 Complete**

### Task 6.2.2: Apply Promote, Replace, or Stop Without Human Override

**Description:** Encode the complete ordered rule in one deterministic BEAM
decision module and emit both a canonical machine record and an explained
human report from the same inputs.

- [ ] **Task 6.2.2 Complete**

#### Subtask 6.2.2.1: Evaluate the Ordered Outcome Rule

**Description:** Promote A-Lang only when, in each model family, exact fidelity
exceeds JSON by at least five percentage points, the paired 95% lower bound is
above zero, and no veto fires; otherwise replace the novel surface with typed
JSON only when JSON reaches at least 80% exact fidelity in both families and
no unresolved safety veto prevents use; otherwise stop user-facing language
expansion. An invalid campaign also yields stop-without-efficacy-conclusion,
not promotion, replacement, or evidence that either condition is superior.

- [ ] **Subtask 6.2.2.1 Complete**

#### Subtask 6.2.2.2: Publish Decision Rationale and Sensitivity Context

**Description:** Explain every satisfied and failed predicate, report family-
level and task-family results, distinguish registered inference from clearly
labeled descriptive sensitivity checks, and forbid sensitivity results from
changing the canonical disposition.

- [ ] **Subtask 6.2.2.2 Complete**

## Section 6.3: Implementation and Research Handoff

**Description:** Make the decision discoverable and actionable throughout the
archive while preserving rejected claims, operational limits, deferred work,
and the evidence trail that supports the outcome.

- [ ] **Section 6.3 Complete**

### Task 6.3.1: Reconcile Architecture, Status, Risks, and Deferred Work

**Description:** Update the architecture decision and implementation ledgers
from the canonical outcome, clearly separating what was implemented, what the
experiment supports, and what remains untested or rejected.

- [ ] **Task 6.3.1 Complete**

#### Subtask 6.3.1.1: Apply the Outcome to the Supported Surface

**Description:** On promote, retain `alang-source-v2` only for its tested
closed subset; on replace, designate `alang-task-json-v1` as the user-facing
input and remove the novel surface from future acceptance claims; on stop,
freeze both experimental authoring paths while retaining evidence-supported
BEAM runtime enforcement and test fixtures.

- [ ] **Subtask 6.3.1.1 Complete**

#### Subtask 6.3.1.2: Preserve Scope, Security, and Production Boundaries

**Description:** Keep same-node trust, host-account isolation, local
durability, fixed-module lifecycle, single-OTP support, provider variability,
formal-proof limits, and absent human-usability evidence visible; do not label
any disposition production-ready or extrapolate to untested models and tasks.

- [ ] **Subtask 6.3.1.2 Complete**

### Task 6.3.2: Reconcile Inquiries, Maps, Indexes, and the Next Boundary

**Description:** Update the task-language inquiry, topic and home maps,
planning indexes, source indexes, and relevant synthesis links so readers can
trace the question from research through code, hosted evidence, and decision.

- [ ] **Task 6.3.2 Complete**

#### Subtask 6.3.2.1: Record Findings Without Over-Resolving Research

**Description:** Add the experiment's bounded finding to the active inquiry
and syntheses, keep broader questions open unless their stated criteria are
actually satisfied, and identify limitations or contradictory evidence rather
than turning a local result into a universal language claim.

- [ ] **Subtask 6.3.2.1 Complete**

#### Subtask 6.3.2.2: Define Any Later Work as a New Authorization

**Description:** Record the narrow next question implied by the chosen outcome
but do not add another phase here or unfreeze recursion, polymorphism,
parallelism, distribution, portable delegation, new effects, packages,
self-hosting, categorical syntax, human-usability claims, or production scope;
materially new work requires a later numbered planning stream and explicit
approval.

- [ ] **Subtask 6.3.2.2 Complete**

## Section 6.4: Phase 6 Integration Tests

**Description:** Reproduce the complete source-to-decision story from a clean
checkout, test every decision branch and evidence failure, and verify that the
archive handoff is internally consistent and free of secrets.

- [ ] **Section 6.4 Complete**

### Task 6.4.1: Run Decision, Mutation, and Clean-Replay Suites

**Description:** Execute deterministic fixtures for promote, replace, stop,
invalid campaign, safety veto, model-family disagreement, threshold boundary,
digest mismatch, missing cell, and corrupted evidence, then replay the actual
campaign without network access.

- [ ] **Task 6.4.1 Complete**

#### Subtask 6.4.1.1: Detect Seeded Decision and Evidence Defects

**Description:** Require tests to fail when a mutant pools model families,
uses repaired output as primary, weakens five points or the interval boundary,
changes the bootstrap seed, ignores a safety veto, accepts a model alias,
drops or replaces an unfavorable definitive response, exceeds a ceiling, or
promotes an invalid campaign.

- [ ] **Subtask 6.4.1.1 Complete**

#### Subtask 6.4.1.2: Reproduce the Canonical Decision Byte-for-Byte

**Description:** Starting only from committed redacted evidence, rebuild the
BEAM analysis modules, validate all digests, regenerate metrics and intervals,
and require the machine decision, human report tables, validity result, and
content digests to match the release evidence exactly.

- [ ] **Subtask 6.4.1.2 Complete**

### Task 6.4.2: Validate the Roadmap and Archive Handoff

**Description:** Run the complete inherited and new verification suites, audit
runtime residency and evidence retention, and prove that every changed
document, index, and local link agrees with the final disposition.

- [ ] **Task 6.4.2 Complete**

#### Subtask 6.4.2.1: Reassert End-to-End Technical Gates

**Description:** Require clean compiler, runtime, adapter-mock, law, security,
fault, mutation, completion, campaign-replay, and decision tests; verify that
trusted modules load from `.beam`, default tests remain offline, and no
interpreter, foreign compiler, provider SDK, or raw transport artifact enters
the acceptance path.

- [ ] **Subtask 6.4.2.1 Complete**

#### Subtask 6.4.2.2: Validate Metadata, Links, Indexes, and Secret Absence

**Description:** Validate all frontmatter and schemas, resolve local links,
check every directory README inventory, scan retained evidence and Git history
introduced by this stream for credentials and headers, and publish an evidence
index mapping every roadmap gate to a reproducible command or artifact.

- [ ] **Subtask 6.4.2.2 Complete**

## Phase 6 Completion Evidence

**Description:** Close this planning stream only when one canonical disposition
is reproducible, conservatively scoped, and reflected consistently throughout
the code and archive.

- [ ] Campaign validity is machine-evaluated from a complete attempt and evidence ledger
- [ ] Frozen inputs, provider profiles, records, analysis code, and outputs have verified digests
- [ ] OpenAI and Anthropic decision inputs and intervals are reported separately
- [ ] Safety and inherited regression vetoes are evaluated before promotion
- [ ] One deterministic promote, replace, or stop record follows the pre-registered ordered rule
- [ ] An invalid campaign cannot produce an efficacy comparison or promotion
- [ ] The human report explains every decision predicate and labels descriptive sensitivity analysis
- [ ] Implementation status, risks, deferred work, inquiries, maps, and indexes reflect the outcome
- [ ] No result claims production readiness, general model/task validity, or human-usability benefit
- [ ] Clean offline replay reproduces the actual validity, metrics, intervals, and decision byte-for-byte
- [ ] All inherited and stream-specific technical, archive, and secret-retention gates pass
- [ ] Any later work is left to an explicitly authorized, newly numbered planning stream
