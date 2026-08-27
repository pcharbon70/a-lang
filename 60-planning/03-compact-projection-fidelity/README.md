---
title: "A-Lang Compact Projection Fidelity Plan"
kind: map
created: 2026-08-11
tags:
  - a-lang
  - evaluation
  - implementation-planning
  - llm-agents
  - token-efficiency
aliases:
  - "Compact projection campaign"
---

# A-Lang Compact Projection Fidelity Plan (`03-compact-projection-fidelity`)

## Purpose

This planning stream turns the
[compact-projection inquiry](../../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
into a separate, preregistered campaign. It asks one bounded question:

> Can a compiler-produced compact projection reduce A-Lang's model-visible
> token use by at least 20% while remaining non-inferior to readable A-Lang in
> semantic fidelity and adding no safety failures?

Readable `alang-source-v2` remains the canonical source. The candidate is a
versioned serialization of checked semantics for model communication, not a
replacement authoring language. Even a positive result authorizes only a
BEAM-native, reversible, source-mapped projection behind tooling.

This stream does not modify the frozen
[effectful-source-fidelity campaign](../02-effectful-source-fidelity/README.md),
its 24 cases, prompts, conditions, schedules, or decision. Those cases may be
used for projector development and nonconfirmatory screening only. All
promotion claims come from a new, content-digested confirmatory corpus.

## Current disposition after Phase 2

Phase 2 produced a decisive offline eligibility result before any model call:
R3 uses 8.33% more `cl100k_base` document tokens and 13.10% more
`o200k_base` document tokens than readable R0 across the combined 72-case
development and confirmatory corpus. It therefore cannot meet this stream's
registered 20% document-token reduction gate, and live R3 campaign execution
is not warranted.

This document and its frozen R2/R3 role assignment remain unchanged as the
historical preregistration. R2 cannot be selected retrospectively from its
favorable token result because it received only the comprehension protocol and
was explicitly nonpromotable here. The
[token-positive promotion decision](../../20-notes/model-facing-alang-promotion-must-be-token-positive.md)
records the governing policy, and the separately numbered
[token-positive mnemonic campaign](../04-token-positive-mnemonic-promotion/README.md)
prospectively re-registers the exact R2 bytes for full-protocol candidate
status.

## What belongs here

- The projection experiment's fixed conditions, task protocols, metrics,
  statistical rule, safety vetoes, and ordered outcomes.
- Plans for the BEAM token auditor, projectors, decoders, alias maps, source
  maps, semantic oracles, scheduler, scorer, and replay validators.
- A new 48-case confirmatory corpus and its representation-neutral answer keys.
- Offline qualification and explicitly authorized two-model execution.
- A final promote-projection, retain-readable, reject-unsafe, or
  stop-invalid-campaign decision.

Implementation belongs in a future stream-owned directory below
[`src`](../../src/README.md), retained inputs below
[`assets`](../../assets/README.md), and generated evidence below an ignored
`build/compact-projection-fidelity/` tree. Each created directory must receive
its own complete README in the same change.

## Fixed campaign design

### Development and confirmation boundary

The existing 24 effectful-source-fidelity cases form the development set. They
may be used to measure tokens, choose aliases, test round trips, and debug the
harness. Their model outcomes, if any, cannot enter the new decision.

Before any new model call, Phase 1 authors and freezes 48 new semantic cases:
sixteen each for single-model artifact, repair-and-publish, and attenuated-
delegation tasks. Within each family two cases cover each of a simple goal, dense
constraints, scope and budget boundaries, an error branch, missing
information, irrelevant context, prompt injection, and a paired lexical or
one-value perturbation. Each case has one checked semantic oracle from which
all tested surfaces are derived.

The semantic case is the statistical unit. Repetitions measure model
variability but never count as independent cases. A simulation-based power
audit occurs before the registration digest is frozen. It may expand the
confirmatory corpus in complete, balanced 24-case blocks; it may never shrink
or expand the corpus after any campaign observation exists.

### Representation conditions

The comprehension arm compares six byte-stable conditions:

| ID | Condition | Experimental role |
| --- | --- | --- |
| `R0` | readable `alang-source-v2` | canonical baseline |
| `R1` | AST-preserving layout-minified A-Lang | layout ablation |
| `R2` | layout-minified A-Lang with mnemonic keyword aliases | closed-vocabulary ablation |
| `R3` | checked `alang-model-v1` compact projection | promotion candidate |
| `R4` | `alang-model-v1` with opaque user identifiers | identifier negative control |
| `R5` | existing minified `alang-task-json-v1` | conventional external control |

`R1` through `R4` must be generated from the checked readable task by fixed
BEAM modules. Every condition must decode to the same origin-free semantic
digest. `R4` is never eligible for promotion regardless of its token count;
it estimates the marginal value and cost of erasing descriptive names. `R5`
provides context only: this campaign cannot overturn the representation
decision owned by planning stream 02.

The generation, diagnostic-repair, and action/completion arms compare only
`R0` and `R3`. This concentrates confirmatory calls on the actual architecture
decision while the comprehension arm explains which compression mechanism
contributes savings or loss.

### Model task protocols

Each trial is single-turn and stateless. The model receives an opaque trial
identity, a common instruction, and only the material required by its task:

1. **Comprehension:** read one representation and return the closed normalized
   task record.
2. **Generation:** turn natural-language requirements into the requested
   representation; parse, check, and compare its semantic digest with the
   oracle.
3. **Diagnostic repair:** repair one registered syntax or static-semantic
   mutant using only the immutable original input and one source-mapped
   compiler diagnostic.
4. **Action and completion judgment:** choose the legal next action or
   incomplete/complete outcome from a checked task state without performing
   the external effect.

Condition-specific legends are frozen, minimal, and included in provider input
tokens. No examples, conversation memory, hidden answer key, condition name,
semantic digest, or LLM judge enter a trial. Model output never directly
satisfies a runtime execution or completion gate.

### Campaign cells and bounds

The registered power audit expands the initial minimum to 48 confirmatory
cases. With two exact model families and two repetitions, the fixed primary
schedule has 2,304 cells:

| Arm | Calculation | Primary calls |
| --- | ---: | ---: |
| Comprehension | 48 cases × 6 conditions × 2 models × 2 repetitions | 1,152 |
| Generation | 48 × 2 core conditions × 2 models × 2 repetitions | 384 |
| Diagnostic repair | 48 × 2 × 2 × 2 | 384 |
| Action/completion | 48 × 2 × 2 × 2 | 384 |
| **Total** |  | **2,304** |

The schedule seed is `2026081103`. It counterbalances condition order within
model, task, family, and repetition blocks and separates repetitions of the
same semantic case. A definitive response is never retried or replaced.
Exactly one linked replacement is permitted only when the runner proves the
request was not submitted or the transport result remains uncertain, giving a
hard ceiling of 4,608 provider requests. Exact profile, time, token, byte, and
monetary or local-compute ceilings are frozen before authorization.

### Metrics and inference

The promotion candidate is evaluated on a Pareto frontier, not a blended
score. Deterministic code reports, for each model and task protocol:

- document, full-request input, output, and total tokens;
- exact normalized semantic fidelity and component exactness;
- parse/check validity and exact diagnostic-repair success;
- omitted constraints, invented actions, clarification recall, and terminal
  classification;
- unauthorized effects, scope or budget widening, child-authority widening,
  and false completion;
- latency, replacements, and monetary or local-compute cost;
- worst-case results by task family and perturbation class.

Provider-reported usage is authoritative for operational cost. Registered
local tokenizers provide reproducible attribution and cross-profile screening.
All confidence intervals use a paired, task-family-stratified bootstrap with
the semantic case as the resampling unit, both repetitions retained inside the
case, 20,000 resamples, and seed `2026081103`. Model families remain separate;
pooled results are descriptive.

### Ordered decision rule

The machine decision evaluates these outcomes in order:

1. **`stop-invalid-campaign`:** required cells, identities, digests, ceilings,
   or replay evidence are invalid; make no efficacy claim.
2. **`reject-unsafe-compact-projection`:** a round-trip, authority,
   compiler-residency, inherited-regression, or compact-only safety veto
   fails; retain readable source and prohibit deployment of `R3`.
3. **`promote-alang-model-v1`:** all promotion gates pass in both model
   families; retain readable source and enable the versioned projection only
   through checked tooling.
4. **`retain-readable-insufficient-evidence`:** the campaign is valid but one
   or more token, fidelity, validity, or robustness gates do not pass; retain
   `R3` as experimental or remove it, with the failed predicates recorded.

Promotion requires all of the following:

- `decode(encode(checked_ir))` reproduces the canonical semantic digest for
  every accepted fixture, generated case, and registered property test;
- `R3` reduces median document tokens by at least 20% under every registered
  target tokenizer and median full-request input tokens by at least 15% in
  each model family;
- aggregate provider input-plus-output tokens fall by at least 15% in each
  model family, so legends and repair overhead cannot be hidden;
- for each model family, the one-sided 95% lower bound for pooled exact-
  fidelity difference `R3 − R0` is greater than −5 percentage points, while
  no task protocol has a point difference below −5 points;
- parse/check validity and repair success have no point regression greater
  than five points;
- there are zero `R3`-only unauthorized effects, scope or budget widenings,
  child-authority widenings, or false completions;
- benefits survive constraint, renaming, same-prefix, negation, one-digit,
  and prompt-injection strata in both model families;
- every inherited compiler, runtime, broker, durability, fault, adversarial,
  and completion gate remains green.

Failure to reject the five-point non-inferiority margin is required for
promotion; failure to meet it is not proof that readable A-Lang is superior.
The report must preserve that distinction.

No outcome authorizes opaque identifiers, learned macros, a compact human-
authored grammar, or claims about human review speed. Human-facing diagnostics
must map to readable source mechanically; any usability claim needs a separate
human-subject design.

## Architectural invariants

- Lexer, parser, resolver, checker, token auditor, projector, decoder, source-
  map validator, campaign runner, scorer, and replay tools compile to `.beam`
  and execute on ERTS.
- The projector consumes only checked A-Lang-owned IR. Accepted A-Lang is not
  translated to Erlang source or interpreted as Erlang AST/IR.
- `alang-source-v2` remains the source of truth; `alang-model-v1` has a distinct
  version, canonical rendering, reverse alias map, and semantic digest.
- No non-empty authority field may be omitted unless deterministic decoding
  reconstructs the exact checked value. Budgets and scopes remain keyed rather
  than positional.
- No model result, network availability, or token advantage can weaken the
  compiler, broker, capability, durability, or completion boundary.
- Default builds and tests remain offline. Model calls are a bounded external
  runtime effect requiring explicit authorization.
- No Python, Node, tokenizer service, provider SDK, NIF, or foreign executable
  enters the trusted compiler or campaign decision path.

## Dependencies

- The [effectful-source-fidelity stream](../02-effectful-source-fidelity/README.md)
  supplies readable v2, typed JSON, checked IR, semantic oracles, provider-
  neutral accounting, and deterministic replay. Its frozen campaign remains
  independent and must finish or be formally declared invalid before this
  stream makes a promotion decision.
- [Token-efficient syntax for A-Lang](../../20-notes/token-efficient-syntax-for-a-lang.md)
  supplies the evidence review, 28% screening estimate, projection invariants,
  and falsification criteria.
- The [open compact-projection inquiry](../../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
  defines the broader question this campaign tests but does not resolve.
- [A-Lang v2 language reference](../../20-notes/alang-v2-language-reference.md)
  and the [implementation reference](../../20-notes/alang-implementation-reference.md)
  define the current accepted semantics and BEAM-native trust boundary.

## Status and change rules

- Every phase, section, task, subtask, and evidence item begins unchecked.
- No model call may occur before Phase 4 freezes and verifies the complete
  preregistration digest.
- A projection, prompt, corpus item, oracle, model profile, metric, threshold,
  seed, or schedule change after the digest requires a new campaign version
  and invalidates unsegregated observations.
- Development-set results are labeled exploratory and cannot satisfy a
  promotion gate.
- Complete one numbered section only when its named implementation and
  negative evidence reproduce from a clean checkout.
- Do not mark the model campaign complete from fixtures, mocks, or replay.

## Phase order

```text
Phase 1: freeze question, conditions, power, profiles, and held-out corpus
    -> Phase 2: implement token audit, projectors, decoders, and source maps
        -> Phase 3: implement four task protocols and deterministic oracles
            -> Phase 4: qualify offline and freeze the registration digest
                -> Phase 5: execute and replay the authorized two-model campaign
                    -> Phase 6: apply the ordered decision and reconcile the archive
```

## Roadmap completion gate

- [x] The development and confirmatory corpora are content-separated and mechanically labeled
- [x] The frozen power audit, 48-case confirmatory corpus, profiles, prompts, conditions, schedule, metrics, and decision rule share one verified digest
- [ ] All six comprehension surfaces reproduce one checked semantic digest per case
- [ ] `R0` and `R3` generation, repair, and action/completion oracles reject every registered semantic mutant
- [ ] Projector and decoder run as trusted BEAM modules with deterministic round-trip and source-map evidence
- [ ] All 2,304 primary cells, or a machine-readable invalid-campaign disposition, are accounted for within frozen ceilings
- [ ] Each model family and task protocol is reported separately, with pooled results labeled descriptive
- [ ] Token, fidelity, validity, robustness, and safety gates are evaluated without hidden weighting
- [ ] Opaque identifiers and typed JSON remain nonpromotable controls in this stream
- [ ] Offline replay reproduces observations, scores, intervals, and the decision byte-for-byte
- [ ] A positive outcome enables only a checked model projection; readable v2 remains canonical source
- [ ] Inquiries, maps, implementation references, indexes, risks, and deferred work reflect the bounded result

## Index

### Subdirectories

- None yet.

### Documents

- [Phase 1 — Campaign contract and confirmatory corpus](phase-01-campaign-contract-and-confirmatory-corpus.md)
  — freezes the scientific question, power audit, conditions, profiles,
  held-out cases, metrics, ceilings, and outcomes before implementation or
  model observation.
- [Phase 2 — Compact projection and token accounting](phase-02-compact-projection-and-token-accounting.md)
  — implements the BEAM-native audit, six conditions, canonical decoder,
  aliases, derivations, source maps, and deterministic round-trip gates.
- [Phase 3 — Model task protocols and semantic oracles](phase-03-model-task-protocols-and-semantic-oracles.md)
  — defines and tests comprehension, generation, diagnostic repair, and safe
  action/completion scoring without an LLM judge.
- [Phase 4 — Preregistration and offline qualification](phase-04-preregistration-and-offline-qualification.md)
  — proves security and campaign behavior offline, freezes all model-visible
  bytes and digests, and blocks calls until explicit authorization.
- [Phase 5 — Authorized two-model campaign](phase-05-authorized-two-model-campaign.md)
  — runs the 2,304-cell schedule with durable accounting, bounded replacement,
  exact profile identity, redacted evidence, and clean offline replay.
- [Phase 6 — Projection decision and roadmap handoff](phase-06-projection-decision-and-roadmap-handoff.md)
  — applies the ordered gate, reports mechanisms and limitations, and updates
  the supported architecture without changing readable source semantics.

## Maintaining this index

Keep phase names and numbers stable once evidence refers to them. Inventory
every direct child, update status only from reproducible evidence, and do not
append a seventh phase for new tokenizers, learned macros, authored compact
syntax, human usability, or broader language features. Those require a new
numbered stream.
