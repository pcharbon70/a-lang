---
title: "Phase 3: Model Task Protocols and Semantic Oracles"
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

# Phase 3: Model Task Protocols and Semantic Oracles

**Description:** Implement four closed, independently scored model tasks that
test reading, writing, repair, and safe operational judgment without using an
LLM judge or allowing a model response to cross an execution boundary.

**Status:** Planned; protocol examples, hand inspection, and successful mock
outputs do not complete a task without deterministic positive and negative
oracles.

**Dependencies:** Phase 2 must provide canonical `R0` through `R5` renderers,
`R0`/`R3` decoders, readable diagnostics, and semantic digests. Phase 1 owns
the exact prompts, outputs, conditions, and registered mutant strata.

## Section 3.1: Comprehension and Generation Protocols

**Description:** Test both directions between task semantics and
representations while keeping instructions, answer schemas, and scoring fixed.

- [ ] **Section 3.1 Complete**

### Task 3.1.1: Implement Closed Task Comprehension

**Description:** Present each of the six surfaces and require one normalized
record covering goals, inputs, ordered actions, dependencies, effects,
requirements, scopes, budgets, errors, child attenuation, completion,
clarification, and terminal class.

- [ ] **Task 3.1.1 Complete**

#### Subtask 3.1.1.1: Render Common Instructions and Condition Legends

**Description:** Build byte-stable requests with the same output schema and
semantic demands, attach only the registered minimal legend for the observed
surface, and count all legend and instruction tokens.

- [ ] **Subtask 3.1.1.1 Complete**

#### Subtask 3.1.1.2: Score Exact and Component Fidelity

**Description:** Validate UTF-8 and the closed response schema, canonicalize
the record, compare it with the case oracle, and classify omissions,
inventions, authority widening, false completion, and clarification errors.

- [ ] **Subtask 3.1.1.2 Complete**

### Task 3.1.2: Implement Representation Generation

**Description:** Present representation-neutral natural-language requirements
and require either readable v2 or checked compact output whose decoded,
checked semantic digest matches the hidden oracle.

- [ ] **Task 3.1.2 Complete**

#### Subtask 3.1.2.1: Freeze Paired Generation Inputs

**Description:** Use one requirement document per semantic case, vary only the
requested output version and its registered legend, and reject condition cues,
surface fragments, oracle ordering, or identifiers that make one form easier.

- [ ] **Subtask 3.1.2.1 Complete**

#### Subtask 3.1.2.2: Parse, Check, and Compare Generated Semantics

**Description:** Extract one bounded representation, run its BEAM parser and
checker, compare the semantic digest and every safety component, and retain
the first response as definitive even when invalid.

- [ ] **Subtask 3.1.2.2 Complete**

## Section 3.2: Diagnostic Repair and Operational Judgment

**Description:** Determine whether compaction increases correction cost or
causes a model to misread the authority and completion state that controls the
next legal step.

- [ ] **Section 3.2 Complete**

### Task 3.2.1: Implement the Diagnostic-Repair Protocol

**Description:** Pair one immutable invalid representation with one canonical,
source-mapped compiler diagnostic and require a corrected representation in a
single response.

- [ ] **Task 3.2.1 Complete**

#### Subtask 3.2.1.1: Generate and Register Matched Mutants

**Description:** Create syntax, name, type, dependency, effect, scope, budget,
child-grant, error, and completion mutants in `R0` and `R3` that represent the
same underlying defect and have equally specific readable diagnostics.

- [ ] **Subtask 3.2.1.1 Complete**

#### Subtask 3.2.1.2: Score Exact Repair Without Iterative Help

**Description:** Parse and check the first repaired output, require the target
semantic digest, classify unchanged and overcorrected fields, and prohibit a
second diagnostic or conversation turn from entering the primary metric.

- [ ] **Subtask 3.2.1.2 Complete**

### Task 3.2.2: Implement Action and Completion Judgment

**Description:** Present a checked task plus bounded execution state and ask
for the one legal next action, clarification, denial, incomplete outcome, or
verifier-backed completion classification.

- [ ] **Task 3.2.2 Complete**

#### Subtask 3.2.2.1: Derive Decisions from the Runtime Oracle

**Description:** Use the existing broker, budget, child, error, and completion
semantics to calculate a closed answer independently of surface form, covering
allowed, denied, exhausted, failed, missing, and complete states.

- [ ] **Subtask 3.2.2.1 Complete**

#### Subtask 3.2.2.2: Score Safety-Critical Disagreement

**Description:** Distinguish conservative refusal from unauthorized action,
scope or budget widening, child-authority widening, skipped dependency, and
false completion; retain every safety event as a nonaverageable observation.

- [ ] **Subtask 3.2.2.2 Complete**

## Section 3.3: Response, Perturbation, and Token Accounting

**Description:** Normalize all four protocols under one bounded observation
algebra and verify the campaign tests the robustness hypotheses that motivated
the compact-projection design.

- [ ] **Section 3.3 Complete**

### Task 3.3.1: Define the Provider-Neutral Observation Record

**Description:** Record immutable request and response digests, opaque cell
identity, exact profile, task, condition, repetition, response class, semantic
score, safety flags, tokens, latency, and replacement lineage without raw
provider metadata.

- [ ] **Task 3.3.1 Complete**

#### Subtask 3.3.1.1: Classify Every Definitive Response

**Description:** Give refusals, truncation, invalid UTF-8, malformed envelopes,
schema failures, parse failures, check failures, semantic misses, and correct
records stable distinct classes; never discard an unfavorable response.

- [ ] **Subtask 3.3.1.1 Complete**

#### Subtask 3.3.1.2: Reconcile Local and Provider Token Usage

**Description:** Retain provider input/output usage as operational truth,
recompute registered local counts from exact bytes, flag unexplained
disagreement, and aggregate legend, request, response, and replacement costs.

- [ ] **Subtask 3.3.1.2 Complete**

### Task 3.3.2: Register Robustness Strata and Worst Cases

**Description:** Attach each case/task cell to constraint density, descriptive
rename, same-prefix identity, negation, one-digit or unit change, irrelevant
context, missing information, injection, and child-attenuation strata.

- [ ] **Task 3.3.2 Complete**

#### Subtask 3.3.2.1: Prove Perturbation Semantics

**Description:** For invariance pairs, require equal semantic digests; for
sensitivity pairs, require exactly the registered changed field and decision,
with no incidental token or difficulty imbalance left unexplained.

- [ ] **Subtask 3.3.2.1 Complete**

#### Subtask 3.3.2.2: Emit Average and Worst-Case Tables

**Description:** Report every model/task/condition stratum and the worst
registered perturbation without hiding failures inside pooled averages or
selecting strata after observations.

- [ ] **Subtask 3.3.2.2 Complete**

## Section 3.4: Phase 3 Integration Tests

**Description:** Exercise all protocols end to end against deterministic
fixtures, seeded semantic and safety failures, transport classes, and token
records before any provider call is possible.

- [ ] **Section 3.4 Complete**

### Task 3.4.1: Run the Complete Offline Protocol Matrix

**Description:** Materialize every confirmatory request, supply exact, invalid,
and adversarial fixture responses, and prove deterministic scoring and evidence
for all task and condition combinations.

- [ ] **Task 3.4.1 Complete**

#### Subtask 3.4.1.1: Detect Oracle and Scorer Mutants

**Description:** Fail when a mutant ignores a field, accepts a wider scope,
swaps a budget unit, overlooks an invented action, treats repaired output as
primary, pools tasks, or lets an LLM judgment override deterministic code.

- [ ] **Subtask 3.4.1.1 Complete**

#### Subtask 3.4.1.2: Prove Request Isolation and Leakage Absence

**Description:** Scan every model-visible byte sequence for answer keys,
digests, filenames, condition roles, expected outcomes, cross-trial messages,
and secrets; require stateless single-turn construction.

- [ ] **Subtask 3.4.1.2 Complete**

### Task 3.4.2: Publish Phase 3 Evidence

**Description:** Index protocol schemas, request digests, oracle coverage,
mutants, response classes, safety scoring, token reconciliation, and clean
offline commands without treating fixtures as efficacy evidence.

- [ ] **Task 3.4.2 Complete**

#### Subtask 3.4.2.1: Reproduce Evidence Across Clean ERTS Processes

**Description:** Rebuild requests, fixture observations, scores, and digests
twice from clean processes and require byte equality independent of filesystem
order or runtime atom state.

- [ ] **Subtask 3.4.2.1 Complete**

#### Subtask 3.4.2.2: Record Protocol Limits

**Description:** State that single-turn, closed-output tasks do not establish
long-session adaptation, human usability, open-ended coding quality, learned-
macro viability, or safe real-world effect execution.

- [ ] **Subtask 3.4.2.2 Complete**

## Phase 3 Completion Evidence

**Description:** Authorize preregistration only when all model behaviors have
closed deterministic oracles and safety failures cannot be normalized away.

- [ ] Comprehension covers all six registered conditions with one output contract
- [ ] Generation, repair, and action/completion compare only readable and checked compact forms
- [ ] Generated and repaired outputs pass the real parser, checker, and semantic-digest oracle
- [ ] Operational judgments derive from broker, budget, child, error, and completion semantics
- [ ] Every definitive response class and safety event has deterministic scoring
- [ ] Condition legends and all request/response scaffolding enter token accounting
- [ ] Perturbation pairs prove registered invariance or exact sensitivity
- [ ] Scorer mutants demonstrate field, task, and safety coverage
- [ ] Model-visible requests contain no answer, digest, role, filename, prior trial, or secret leakage
- [ ] Offline evidence reproduces byte-for-byte and is labeled non-efficacy evidence
