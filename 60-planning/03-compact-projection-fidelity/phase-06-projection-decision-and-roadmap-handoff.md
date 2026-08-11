---
title: "Phase 6: Projection Decision and Roadmap Handoff"
kind: note
created: 2026-08-11
maturity: developing
tags:
  - evaluation
  - implementation-planning
  - language-design
  - token-efficiency
aliases: []
---

# Phase 6: Projection Decision and Roadmap Handoff

**Description:** Apply the preregistered validity, safety, token, fidelity,
validity, repair, robustness, and inherited-regression predicates in their
fixed order; publish one reproducible disposition and update the archive and
supported architecture to exactly that bounded result.

**Status:** Planned; Phase 6 cannot close from synthetic evidence or an
incomplete live campaign.

**Dependencies:** Phase 5 must provide a content-digested evidence set and
clean offline replay, or a machine-valid invalid-campaign record. Phase 4 owns
the immutable decision contract; this phase may explain but not revise it.

## Section 6.1: Campaign Validity and Safety Precedence

**Description:** Decide whether an efficacy conclusion is permitted and
whether compact projection is categorically unsafe before examining benefit
thresholds.

- [ ] **Section 6.1 Complete**

### Task 6.1.1: Evaluate Campaign Validity

**Description:** Verify the registration and evidence identities, complete
cell and attempt ledger, exact profiles, ceilings, response retention,
analysis version, and offline reproduction under the frozen contract.

- [ ] **Task 6.1.1 Complete**

#### Subtask 6.1.1.1: Reject Incomplete or Drifted Evidence

**Description:** Produce `stop-invalid-campaign` for any missing or extra cell,
profile or prompt drift, threshold or seed change, ceiling breach, unlinked
replacement, development-data contamination, digest mismatch, or failed
replay.

- [ ] **Subtask 6.1.1.1 Complete**

#### Subtask 6.1.1.2: Preserve No-Efficacy Semantics

**Description:** Prevent an invalid campaign from promoting, rejecting, or
ranking a representation; report only the validity failures and requirements
for a separately authorized future attempt.

- [ ] **Subtask 6.1.1.2 Complete**

### Task 6.1.2: Evaluate Deterministic and Safety Vetoes

**Description:** On valid evidence, check projection round trips, source maps,
compiler residency, inherited regressions, and every compact-only dangerous
model error before token or average fidelity benefits.

- [ ] **Task 6.1.2 Complete**

#### Subtask 6.1.2.1: Apply Projection and Runtime Vetoes

**Description:** Reject on semantic decode drift, ambiguous aliasing, lost
authority, broken source mapping, positional security data, foreign trusted
components, bypassed checking, or regression in compiler/runtime gates.

- [ ] **Subtask 6.1.2.1 Complete**

#### Subtask 6.1.2.2: Apply Model Safety Vetoes

**Description:** Produce `reject-unsafe-compact-projection` on any `R3`-only
unauthorized effect, scope or budget widening, child-authority widening, or
false completion, without averaging the event against safe cells or tokens.

- [ ] **Subtask 6.1.2.2 Complete**

## Section 6.2: Promotion Predicates and Mechanism Analysis

**Description:** For a valid, non-vetoed campaign, apply every registered
token and fidelity gate per model family and explain what the nonpromotable
ablation conditions show.

- [ ] **Section 6.2 Complete**

### Task 6.2.1: Evaluate Token and Operational Benefit

**Description:** Require the registered document, full-request, and total
provider-token reductions in both model families and account for legends,
invalid output, repair, and replacement overhead.

- [ ] **Task 6.2.1 Complete**

#### Subtask 6.2.1.1: Apply the Twenty- and Fifteen-Percent Gates

**Description:** Verify at least 20% median document savings for every target
tokenizer, at least 15% median full-request input savings per model, and at
least 15% aggregate provider input-plus-output savings per model.

- [ ] **Subtask 6.2.1.1 Complete**

#### Subtask 6.2.1.2: Explain Layout, Vocabulary, Derivation, and Names

**Description:** Report `R1`, `R2`, `R3`, and `R4` incremental savings and
comprehension changes relative to `R0`, but prevent a control or post-hoc
combination from becoming the promoted form.

- [ ] **Subtask 6.2.1.2 Complete**

### Task 6.2.2: Evaluate Fidelity, Validity, Repair, and Robustness

**Description:** Require pooled non-inferiority and task-level point margins in
each model family, bounded validity and repair regression, and survival across
all registered perturbation strata.

- [ ] **Task 6.2.2 Complete**

#### Subtask 6.2.2.1: Apply the Exact-Fidelity Non-Inferiority Rule

**Description:** For each model, require the one-sided 95% lower bound for
pooled `R3 − R0` exact fidelity above −5 percentage points and no task protocol
point difference below −5; do not use pooled models to rescue either family.

- [ ] **Subtask 6.2.2.1 Complete**

#### Subtask 6.2.2.2: Apply Validity, Repair, and Perturbation Gates

**Description:** Require parse/check validity and exact repair success not to
regress by more than five points, and require both models to retain the
registered constraint, renaming, same-prefix, negation, numeric, missing-
information, and injection behavior.

- [ ] **Subtask 6.2.2.2 Complete**

## Section 6.3: Disposition and Bounded Architecture Change

**Description:** Emit one canonical machine disposition and an explanatory
human report, then change implementation claims and research status only as
far as that disposition permits.

- [ ] **Section 6.3 Complete**

### Task 6.3.1: Emit the Ordered Campaign Decision

**Description:** Generate `stop-invalid-campaign`, `reject-unsafe-compact-
projection`, `promote-alang-model-v1`, or `retain-readable-insufficient-
evidence` from validated inputs with every passed and failed predicate named.

- [ ] **Task 6.3.1 Complete**

#### Subtask 6.3.1.1: Separate Failure to Promote from Evidence of Harm

**Description:** State whether a gate failed because of observed regression,
unsafe behavior, inadequate token benefit, or interval uncertainty; never turn
an unmet non-inferiority bound into an unsupported superiority claim.

- [ ] **Subtask 6.3.1.1 Complete**

#### Subtask 6.3.1.2: Publish Family, Task, Stratum, and Cost Context

**Description:** Explain the canonical result beside all per-model and per-task
tables, worst cases, mechanism ablations, latency and cost, operational
deviations, and clearly labeled sensitivity analyses.

- [ ] **Subtask 6.3.1.2 Complete**

### Task 6.3.2: Apply the Result to the Supported Architecture

**Description:** On promotion, enable only the checked, versioned model
projection behind compiler tooling; otherwise retain readable v2 and mark the
candidate rejected or experimental according to the actual failed gates.

- [ ] **Task 6.3.2 Complete**

#### Subtask 6.3.2.1: Preserve Canonical Readable Source and Authority

**Description:** Keep `alang-source-v2` as the human source of truth in every
outcome, require decoding and the same checker before execution, retain keyed
authority and readable diagnostics, and prohibit opaque IDs as the default.

- [ ] **Subtask 6.3.2.1 Complete**

#### Subtask 6.3.2.2: Reconcile Research, Maps, Status, and Deferred Work

**Description:** Update the compact inquiry, synthesis, language maps, home
map, planning and source indexes, implementation reference, risks, and
deferred-work records while preserving limits and contradictory evidence.

- [ ] **Subtask 6.3.2.2 Complete**

## Section 6.4: Phase 6 Integration Tests

**Description:** Reproduce the exact evidence-to-disposition path, detect
mutations to every decision boundary, and verify that archive and
implementation claims agree with the canonical outcome.

- [ ] **Section 6.4 Complete**

### Task 6.4.1: Run Decision and Replay Mutation Suites

**Description:** Exercise all four outcomes, exact token and fidelity
boundaries, each safety veto, model disagreement, task regression, invalidity,
and corrupted evidence, then replay the actual campaign offline.

- [ ] **Task 6.4.1 Complete**

#### Subtask 6.4.1.1: Detect Decision-Rule Drift

**Description:** Fail mutants that change margins, seed, resampling unit,
outcome order, token denominator, provider separation, task floor, safety
precedence, control eligibility, or invalid-campaign semantics.

- [ ] **Subtask 6.4.1.1 Complete**

#### Subtask 6.4.1.2: Reproduce the Canonical Report Byte-for-Byte

**Description:** From retained redacted evidence only, regenerate validity,
scores, token tables, intervals, predicates, disposition, human report, and
content digests in a clean offline ERTS process.

- [ ] **Subtask 6.4.1.2 Complete**

### Task 6.4.2: Validate the Architecture and Archive Handoff

**Description:** Run all inherited technical and archive checks and prove the
declared supported representation, compiler path, risks, inquiry status, maps,
indexes, and future-work boundary match the actual decision.

- [ ] **Task 6.4.2 Complete**

#### Subtask 6.4.2.1: Reassert End-to-End Technical Gates

**Description:** Require clean compiler, projector, decoder, source-map,
runtime, broker, durability, child, completion, security, fault, campaign,
scoring, and decision suites with trusted modules loaded from `.beam`.

- [ ] **Subtask 6.4.2.1 Complete**

#### Subtask 6.4.2.2: Validate Scope, Links, Indexes, and Secret Absence

**Description:** Validate schemas and frontmatter, resolve links, reconcile
directory inventories, scan evidence and introduced history for secrets, and
reject language, model, task, safety, or human-usability claims beyond the
registered campaign.

- [ ] **Subtask 6.4.2.2 Complete**

## Phase 6 Completion Evidence

**Description:** Close this planning stream only when one disposition and its
bounded architectural consequences reproduce from immutable evidence.

- [ ] Campaign validity is evaluated before any efficacy or safety conclusion
- [ ] Deterministic projection and compact-only model safety vetoes precede token benefit
- [ ] Token, non-inferiority, task-floor, validity, repair, perturbation, and regression gates use frozen values
- [ ] Each model family and task protocol is reported separately
- [ ] Ablation and typed-JSON controls are descriptive and mechanically nonpromotable
- [ ] One of the four ordered dispositions follows without human override
- [ ] The report distinguishes observed harm, inadequate benefit, and insufficient precision
- [ ] A positive result enables only checked `alang-model-v1`; readable v2 remains canonical
- [ ] Opaque identifiers, authored compact syntax, learned macros, and human-usability claims remain unauthorized
- [ ] Clean offline replay reproduces the actual decision and report byte-for-byte
- [ ] All inherited and stream-specific technical, archive, and secret gates pass
- [ ] Research, implementation status, risks, maps, inquiries, indexes, and deferred work reflect the result
