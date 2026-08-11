---
title: "Phase 5: Authorized Two-Model Campaign"
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

# Phase 5: Authorized Two-Model Campaign

**Description:** Execute the immutable 2,304-cell confirmatory schedule against
two exact model families, preserve every definitive result and bounded
transport event, and produce a redacted evidence set that replays without
network access.

**Status:** Planned and authorization-gated. Offline fixtures, adapter probes,
partial schedules, or development-corpus calls cannot complete this phase.

**Dependencies:** Phase 4 must publish the exact preregistration digest and a
green offline qualification record. The operator must separately authorize the
registered model identities, request ceiling, cost or compute ceiling, and
retention policy immediately before execution.

## Section 5.1: Preflight and Explicit Authorization

**Description:** Prove the environment can run exactly the registered campaign
without profile substitution, altered inputs, secret leakage, or an unbounded
external effect.

- [ ] **Section 5.1 Complete**

### Task 5.1.1: Verify Immutable Campaign Identity

**Description:** Recompute the registration manifest, trusted module closure,
schedule, prompts, legends, cases, profiles, and ceilings and compare every
digest before opening an adapter.

- [ ] **Task 5.1.1 Complete**

#### Subtask 5.1.1.1: Reproduce the Registration Digest Cleanly

**Description:** Build deterministic BEAM artifacts from a clean checkout,
recreate all model-visible bytes and the schedule, and fail on source, asset,
profile, tokenizer, parameter, or generated-evidence drift.

- [ ] **Subtask 5.1.1.1 Complete**

#### Subtask 5.1.1.2: Probe Exact Model and Usage Support

**Description:** Perform only the registered non-content identity and usage
probe, require exact model revision and token-usage fields, and block rather
than substituting when either family is unavailable.

- [ ] **Subtask 5.1.1.2 Complete**

### Task 5.1.2: Record Operator Authorization and Bounds

**Description:** Capture an explicit campaign authorization that names both
profiles, the registration digest, maximum provider requests, cost or compute
ceiling, output location, and expiry without retaining credentials.

- [ ] **Task 5.1.2 Complete**

#### Subtask 5.1.2.1: Isolate Secrets inside Fixed Adapters

**Description:** Load each credential or local access configuration only in
its owning BEAM adapter, redact it from requests, journals, diagnostics, crash
reports, and evidence, and refuse redirects or arbitrary endpoints.

- [ ] **Subtask 5.1.2.1 Complete**

#### Subtask 5.1.2.2: Initialize Fresh Durable Evidence

**Description:** Create one empty ignored campaign directory, record start
provenance and ceilings, ensure no prior observation or scratch response is
present, and append the hash-chained `campaign_started` event.

- [ ] **Subtask 5.1.2.2 Complete**

## Section 5.2: Bounded Schedule Execution

**Description:** Process the frozen cells in deterministic blocked order while
retaining condition counterbalancing and exactly-once logical accounting.

- [ ] **Section 5.2 Complete**

### Task 5.2.1: Execute Every Primary Cell

**Description:** Send one stateless bounded request per scheduled cell, append
intent before submission and the normalized definitive result afterward, and
advance only when journal state is durable.

- [ ] **Task 5.2.1 Complete**

#### Subtask 5.2.1.1: Complete Both Model and Repetition Blocks

**Description:** Account for all comprehension, generation, repair, and
action/completion cells for both exact model families and both repetitions,
preserving registered order and separation between repeated cases.

- [ ] **Subtask 5.2.1.1 Complete**

#### Subtask 5.2.1.2: Preserve Definitive Failures and Safety Events

**Description:** Retain refusals, truncation, invalid outputs, semantic misses,
unsafe judgments, and zero scores as primary observations; never resubmit them
or pause to tune a legend, prompt, alias, decoder, or threshold.

- [ ] **Subtask 5.2.1.2 Complete**

### Task 5.2.2: Handle Transport Uncertainty Conservatively

**Description:** Classify pre-submission, definitive, and uncertain outcomes
using adapter evidence and enforce the one-linked-replacement and total-request
ceilings without silently losing a cell.

- [ ] **Task 5.2.2 Complete**

#### Subtask 5.2.2.1: Link Every Permitted Replacement

**Description:** Preserve the original attempt and reason, assign the single
registered replacement slot, maintain opaque trial pairing, and block a second
replacement or any request beyond the hard ceiling.

- [ ] **Subtask 5.2.2.1 Complete**

#### Subtask 5.2.2.2: Abort and Resume Without Reinterpretation

**Description:** On operator abort, expired authority, cost ceiling, adapter
fault, or process interruption, close or resume strictly from journal state;
if state is ambiguous or immutable inputs changed, declare the campaign
invalid rather than improvising.

- [ ] **Subtask 5.2.2.2 Complete**

## Section 5.3: Evidence Freeze and Descriptive Analysis

**Description:** Close the observation ledger, normalize and score it with the
registered code, and freeze the evidence before inspecting or narrating
condition-level results.

- [ ] **Section 5.3 Complete**

### Task 5.3.1: Validate Completeness and Freeze Observations

**Description:** Reconcile every schedule cell with one definitive observation
or a registered invalidity reason, enforce all attempt and resource ceilings,
scan retained material for secrets, and append `campaign_closed`.

- [ ] **Task 5.3.1 Complete**

#### Subtask 5.3.1.1: Account for All Cells and Attempts

**Description:** Require exact primary counts by model, task, condition,
family, and repetition; identify missing, extra, duplicate, replaced, aborted,
and uncertain attempts without filling gaps after results are visible.

- [ ] **Subtask 5.3.1.1 Complete**

#### Subtask 5.3.1.2: Canonicalize and Digest the Evidence Set

**Description:** Validate and sort retained requests, responses, usage, scores,
and provenance, redact prohibited transport fields, and bind the immutable set
to one content manifest before analysis tables are opened.

- [ ] **Subtask 5.3.1.2 Complete**

### Task 5.3.2: Compute Registered Results Without Decision Drift

**Description:** Run semantic, safety, token, cost, perturbation, validity, and
bootstrap analysis exactly as registered, retaining per-model and per-task
tables before any pooled descriptive view.

- [ ] **Task 5.3.2 Complete**

#### Subtask 5.3.2.1: Produce the Token-Fidelity Pareto Tables

**Description:** Report `R3 − R0` token and exact-fidelity results, all six
comprehension mechanisms, provider/local tokenizer reconciliation, repair and
validity rates, safety events, worst strata, latency, and total cost.

- [ ] **Subtask 5.3.2.1 Complete**

#### Subtask 5.3.2.2: Separate Registered Inference from Sensitivity Context

**Description:** Mark model/task gates and seeded bootstrap intervals as
canonical; label alternative margins, pooling, per-repetition variation,
document-only cost, or excluded transport cases as descriptive and prevent
them from changing the disposition.

- [ ] **Subtask 5.3.2.2 Complete**

## Section 5.4: Phase 5 Integration Tests

**Description:** Reproduce the completed campaign from retained evidence in a
clean, offline environment and prove that records, scores, tokens, intervals,
and validity have not depended on live provider state.

- [ ] **Section 5.4 Complete**

### Task 5.4.1: Replay the Entire Campaign Offline

**Description:** Remove network access and credentials, rebuild the analysis
modules, validate all registration and evidence digests, and regenerate every
derived artifact from normalized observations.

- [ ] **Task 5.4.1 Complete**

#### Subtask 5.4.1.1: Reproduce Scores, Tokens, and Intervals

**Description:** Require byte-identical semantic scores, safety classifications,
provider/local token tables, costs, perturbation summaries, bootstrap samples,
intervals, and validity results.

- [ ] **Subtask 5.4.1.1 Complete**

#### Subtask 5.4.1.2: Verify Identity, Completeness, and Secret Absence

**Description:** Recheck profiles, schedule, cell counts, attempt lineage,
ceilings, request/response digests, ignored raw files, and secret/header scans;
fail the replay on any mismatch.

- [ ] **Subtask 5.4.1.2 Complete**

### Task 5.4.2: Publish Phase 5 Evidence

**Description:** Index the authorization, registration and evidence digests,
cell accounting, validity, token-fidelity tables, safety observations,
limitations, and clean replay commands without applying the Phase 6 decision.

- [ ] **Task 5.4.2 Complete**

#### Subtask 5.4.2.1: Record Operational Deviations

**Description:** Preserve model unavailability, replacements, pauses, aborts,
latency anomalies, usage disagreement, and ceiling pressure even when they do
not invalidate the campaign.

- [ ] **Subtask 5.4.2.1 Complete**

#### Subtask 5.4.2.2: Keep Outcome Interpretation Sealed

**Description:** Publish only validated measurement outputs and predicates;
defer the ordered architecture disposition and archive reconciliation to Phase
6 so analysis cannot be rewritten to match a desired conclusion.

- [ ] **Subtask 5.4.2.2 Complete**

## Phase 5 Completion Evidence

**Description:** Authorize a decision only when the real campaign is complete
or formally invalid and its entire retained evidence trail reproduces offline.

- [ ] Exact preregistration digest and explicit operator authorization preceded every model call
- [ ] Both exact model profiles passed identity and usage preflight without substitution
- [ ] All 2,304 primary cells, or a machine-valid invalid campaign, are accounted for
- [ ] No definitive refusal, invalid output, semantic failure, or safety event was retried or replaced
- [ ] Every permitted replacement is linked and all request, cost, time, token, and byte ceilings hold
- [ ] The closed evidence manifest contains normalized observations and no credential, header, or raw envelope
- [ ] Per-model and per-task token, fidelity, validity, safety, robustness, latency, and cost tables exist
- [ ] Registered inference is clearly separated from pooled and sensitivity descriptions
- [ ] Clean offline replay reproduces every score, token table, interval, and validity result byte-for-byte
- [ ] Phase 5 evidence reports limitations and operational deviations without selecting the architecture outcome
