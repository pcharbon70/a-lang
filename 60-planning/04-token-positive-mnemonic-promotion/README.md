---
title: "Token-Positive Mnemonic Promotion Plan"
kind: map
created: 2026-08-25
tags:
  - a-lang
  - evaluation
  - implementation-planning
  - llm-agents
  - token-efficiency
aliases:
  - "Mnemonic promotion campaign"
---

# Token-Positive Mnemonic Promotion Plan (`04-token-positive-mnemonic-promotion`)

## Purpose

This planning stream tests whether the exact mnemonic, layout-minified
model-facing surface already implemented as compact-projection condition `R2`
can retain its measured token advantage while remaining non-inferior to
readable A-Lang across comprehension, generation, diagnostic repair, and safe
action/completion judgment.

It implements the policy in
[Model-facing A-Lang promotion must be token-positive](../../20-notes/model-facing-alang-promotion-must-be-token-positive.md):
a representation introduced to reduce token cost cannot be promoted if it
uses more tokens than the readable baseline.

This is a prospective re-registration of the exact R2 surface for a new
scientific role, not a revision of planning stream 03. Stream 03 remains the
immutable record in which `R2` was a comprehension-only ablation and `R3` the
sole promotion candidate. No model outcome has been observed for the
re-registered candidate. The Phase 2 offline token counts are declared design
inputs, not confirmatory efficacy evidence.

## What belongs here

- The campaign-local readable baseline and mnemonic promotion candidate.
- Hard document, full-request, provider-input, and total-token eligibility
  rules that execute before fidelity promotion rules.
- A fresh representation-neutral confirmatory corpus and power-qualified
  paired schedule.
- BEAM-native candidate rendering, decoding, source maps, task protocols,
  scoring, replay, and ordered decision logic.
- An explicitly authorized, bounded two-model execution and final retain,
  reject, promote, or invalid-campaign disposition.

Implementation will belong under a stream-owned directory below
[`src`](../../src/README.md), frozen campaign inputs below
[`assets`](../../assets/README.md), and generated evidence below an ignored
`build/token-positive-mnemonic-promotion/` tree. Each directory created during
implementation must include its own complete README.

## Scope

Readable `alang-source-v2` remains the human-authored source of truth. A
positive result may enable only a compiler-produced, reversible model-facing
view. It does not authorize mnemonic human-authored source, opaque
identifiers, learned tokens, a new runtime semantics, or weaker compiler and
capability gates.

The primary contrast has two campaign-local conditions:

| ID | Representation | Role |
| --- | --- | --- |
| `P0` | exact readable `alang-source-v2` | canonical baseline; nonpromotable |
| `P1` | exact re-registration of mnemonic `R2` | sole promotion candidate |

`P1` is not a new surface or an opportunity to improve R2. It is the exact
model-visible byte sequence produced for the same checked semantics by the
existing `R2` renderer, representation `alang-source-v2-mnemonic-aliases`, and
version `alang-source-v2-alias-v1`, using the frozen
[projection vocabulary](../../assets/compact-projection-fidelity/campaign/projection-vocabulary-v1.json)
and [BEAM renderer](../../src/compact-projection-fidelity/alang_compact_surface.erl).
The new campaign-local ID changes only the scientific role. Phase 1 records
the reference implementation and registry digests; Phase 2 must prove
byte-for-byte equality on every design case, fresh confirmatory case, and
generated conformance case. P1 must also preserve R2's accepted-language and
decode behavior: the same input must be accepted or rejected and every
accepted input must recover the same checked semantics. Source maps,
diagnostics, and campaign tooling may be added around the implementation
without changing those behaviors. Any header, whitespace, ordering,
punctuation, alias, vocabulary, accepted-language, decoding, or other
model-visible change creates a different candidate and requires a new
representation version and preregistration; any such change after the digest
invalidates this campaign.

## Preregistered design

### Evidence boundary

The 24 development and 48 confirmatory cases measured in Phase 2 are now
development evidence for this re-registration. Their offline token counts may
set the candidate and the 5% meaningful-savings floor, but they cannot supply
the new model-fidelity result.

Phase 1 must freeze at least 48 new semantic cases before any model call:
sixteen each for single-model artifact, repair-and-publish, and attenuated-
delegation tasks. Within each family, two cases cover each of simple,
constraint-heavy, scope-budget, error-branch, missing-information,
irrelevant-context, prompt-injection, and lexical-value-perturbation strata.
All surfaces derive from one checked, representation-neutral oracle per case.

The semantic case is the statistical unit. Two paired repetitions measure
model variability but never count as independent cases. A preregistered power
audit may expand the minimum in balanced 24-case blocks before the canonical
registration digest. It cannot shrink or expand the corpus after any model
observation.

### Full-protocol primary schedule

Both `P0` and `P1` receive the same four single-turn protocols:

1. comprehension into the closed normalized task record;
2. generation from natural-language requirements;
3. diagnostic repair from one immutable mutant and readable-source diagnostic;
4. legal next-action and completion judgment without performing an effect.

At the 48-case minimum, two exact model families and two paired repetitions
produce 1,536 primary cells:

```text
48 cases × 2 conditions × 4 protocols × 2 models × 2 repetitions = 1,536
```

The schedule seed is `2026082504`. Condition order is counterbalanced within
model, protocol, runtime family, stratum, and repetition. A definitive response
is never retried. One linked replacement is allowed only when durable evidence
shows that no definitive response exists, making 3,072 the maximum request
count at the 48-case minimum.

### Token-positive eligibility gate

No model call is authorized unless exact BEAM-native screening proves, under
every registered target tokenizer, that:

- every `P1` document is strictly cheaper than its paired `P0` document;
- every complete `P1` request is strictly cheaper than its paired `P0`
  request;
- aggregate and median document savings are at least 5%;
- aggregate and median full-request savings are at least 5%; and
- counts and attribution reproduce byte-for-byte from two clean ERTS
  processes.

Provider usage is authoritative after execution. Promotion additionally
requires no `P1` request with more provider-reported input tokens than its
paired `P0` request, at least 5% aggregate provider-input savings in every
model-family and protocol stratum, and no aggregate increase in input-plus-
output tokens per scheduled primary cell in any such stratum. Failed responses
remain in this cost denominator; missing or estimated provider usage blocks
promotion.

### Fidelity and safety gates

Token eligibility is necessary but insufficient. Promotion also requires:

- canonical round trips and semantic digests for every accepted fixture,
  generated property, and confirmatory case;
- for each model family and protocol, a one-sided 95% lower confidence bound
  for exact-fidelity difference `P1 − P0` above −5 percentage points;
- no parse/check-validity or diagnostic-repair point regression greater than
  five percentage points in any model-family and protocol stratum;
- zero `P1`-only unauthorized effects, scope or budget widening, child-
  authority widening, or false completion;
- no registered perturbation stratum with a `P1 − P0` exact-fidelity point
  difference below −5 percentage points; and
- every inherited compiler, runtime, broker, durability, adversarial, and
  completion gate remaining green.

Confidence intervals use a paired, runtime-family-stratified bootstrap with
the semantic case as the resampling unit, both repetitions retained within
case, 20,000 resamples, and seed `2026082504`. Model families and protocols
remain separate; pooled results are descriptive only. The power audit must
confirm the selected case count before the registration digest is frozen.

### Ordered outcomes

The machine decision applies these outcomes in order without a weighted score
or manual override:

1. `stop-invalid-token-positive-campaign` — identity, completeness, digest,
   ceiling, replay, or provider-usage evidence is invalid.
2. `ineligible-token-negative-candidate` — any offline or operational token-
   positive predicate fails; retain readable source and make no promotion
   claim.
3. `reject-unsafe-mnemonic-candidate` — a round-trip, authority, inherited,
   or candidate-only safety veto fails.
4. `retain-readable-insufficient-fidelity` — token and safety gates pass but
   fidelity, generation, repair, or robustness evidence is insufficient.
5. `promote-token-positive-mnemonic-view` — every token, fidelity, validity,
   robustness, safety, and reproducibility predicate passes in both model
   families and all four protocols.

## Architectural invariants

- Lexer, parser, checker, candidate renderer, inverse decoder, tokenizer,
  source-map validator, campaign runner, scorer, bootstrap, and replay tools
  compile to `.beam` and execute on ERTS.
- The candidate consumes checked A-Lang-owned semantics and never translates
  accepted A-Lang into Erlang source or interprets it as Erlang AST/IR.
- Budgets, scopes, effects, child grants, errors, and completion remain keyed
  and exact; aliases are closed, group-sensitive, and reversible.
- Diagnostics and edit targets use readable source terms, never only mnemonic
  compact text.
- No model observation, fidelity advantage, or safety result can compensate
  for a token-negative candidate.
- Default builds remain offline. Model calls require the exact Phase 2
  qualification digest plus explicit live authorization.
- No foreign tokenizer, provider SDK, port, NIF, shell command, or non-BEAM
  executable enters the trusted compiler or decision path.

## Dependencies

- [Compact projection Phase 2 evidence](../../src/compact-projection-fidelity/section-02-04-integration-evidence.md)
  supplies the observed R2/R3 token results and exact tokenizer harness.
- [Original compact-projection campaign](../03-compact-projection-fidelity/README.md)
  remains an immutable provenance record and supplies reusable validation
  machinery, not a mutable scientific role assignment.
- [Token-efficient syntax for A-Lang](../../20-notes/token-efficient-syntax-for-a-lang.md)
  supplies the evidence review and reversible-projection constraints.
- [Open compact-projection inquiry](../../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
  owns the broader empirical question.

## Status and change rules

- **Preregistration status:** Phase 1 design frozen under a reproducible 21-file
  digest; Phase 2 qualification and live authorization remain incomplete.
- **Implementation status:** Phase 1 complete; Phase 2 is next.
- Every implementation and evidence checkbox begins unchecked.
- No model call may occur until Phase 2 publishes and verifies one canonical
  preregistration and qualification digest containing every candidate byte,
  corpus item, prompt, oracle, profile, schedule, metric, threshold, and seed.
- The known Phase 2 token measurements must be labeled design evidence in all
  reports.
- Any frozen input change after the digest requires a new campaign version and
  invalidates unsegregated observations.
- Fixtures, mocks, offline token counts, or replay cannot complete the hosted
  campaign phase.

## Phase order

```text
Phase 1: freeze token-positive contract, power, profiles, and fresh corpus
    -> Phase 2: qualify the mnemonic candidate and freeze the registration digest
        -> Phase 3: execute and replay the authorized two-model campaign
            -> Phase 4: apply the ordered decision and reconcile the roadmap
```

## Roadmap completion gate

- [x] A fresh content-digested confirmatory corpus is separated from all 72 design cases
- [x] `P1` model-visible bytes exactly match the registered R2 renderer on all frozen and generated cases
- [x] `P1` acceptance and decoding exactly match registered R2 on valid and invalid conformance cases
- [x] `P0` and `P1` render canonically and reproduce one checked semantic digest
- [ ] Every document and full request is token-positive under every registered tokenizer
- [ ] Median and aggregate offline savings are at least 5% on the frozen corpus
- [ ] All four protocol oracles reject every registered semantic and authority mutant
- [ ] The complete preregistration has one verified digest before any model call
- [ ] Every scheduled primary cell or invalid-campaign disposition is accounted for
- [ ] Provider input usage is pairwise nonworse and at least 5% lower per family and protocol
- [ ] Operational total tokens do not increase in any model-family and protocol stratum
- [ ] Exact fidelity, validity, repair, robustness, and safety gates are reported separately
- [ ] Offline replay reproduces observations, intervals, token gates, and decision byte-for-byte
- [ ] A positive outcome enables only a checked model-facing view; readable source remains canonical

## Index

### Subdirectories

- None yet.

### Documents

- [Phase 1 — Token-positive contract and fresh corpus](phase-01-token-positive-contract-and-fresh-corpus.md)
  — freezes the new scientific role, meaningful token floor, full-protocol
  contrast, power design, exact profiles, fresh cases, schedule, and ceilings.
- [Phase 2 — Mnemonic candidate and offline qualification](phase-02-mnemonic-candidate-and-offline-qualification.md)
  — binds the exact R2 rendering and decoding behavior to P1, proves source
  mapping, runs the hard token gate, and publishes the no-call registration
  digest.
- [Phase 3 — Authorized two-model campaign](phase-03-authorized-two-model-campaign.md)
  — executes the bounded paired schedule, retains authoritative provider usage
  and responses, scores deterministically, and reproduces observations offline.
- [Phase 4 — Token-positive decision and roadmap handoff](phase-04-token-positive-decision-and-roadmap-handoff.md)
  — applies validity, efficiency, safety, and fidelity predicates in order and
  records the bounded architecture consequence.

## Maintaining this index

Keep the original scientific roles, threshold direction, seed, and phase
numbers stable after the registration digest. Preserve byte-for-byte P1/R2
conformance; a rendering change belongs to a new candidate and registration.
Inventory every direct child, update status only from reproducible evidence,
and start a new numbered stream rather than appending a new candidate or
relaxing a failed token gate.
