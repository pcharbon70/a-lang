---
title: "A-Lang Effectful Source Fidelity Plan"
kind: map
created: 2026-08-05
tags:
  - beam
  - evaluation
  - implementation-planning
  - llm-agents
  - task-language
aliases:
  - "Effectful source fidelity roadmap"
---

# A-Lang Effectful Source Fidelity Plan (`02-effectful-source-fidelity`)

## Purpose

This directory defines the one bounded successor prototype authorized by the
[Phase 8 architecture decision](../../src/phase-08/proof-of-concept-architecture-decision.md).
It answers one question and does not broaden the language elsewhere:

> Can user-authored effectful A-Lang source improve task-specification fidelity
> over a conventional typed notation while both conditions compile through the
> same BEAM runtime-enforcement path?

The comparison is comprehension-first. A model receives either a hand-authored
A-Lang task or its semantically matched typed-JSON control and must return the
same closed task-comprehension record. Deterministic code scores that record,
and accepted records proceed through the existing broker, durability, child,
workspace, and completion machinery. This tests the source notation without
confounding it with a different runtime.

## What belongs here

- The frozen experiment, corpus, notation, scoring, and decision contracts.
- The effectful A-Lang source frontend and independent typed-JSON control path.
- Static type, effect, requirement, budget, child-attenuation, and completion
  analysis that lowers both representations into the same A-Lang-owned IR.
- Offline and opt-in hosted-model evaluation plans with reproducible evidence.
- A final promote, replace, or stop decision for the user-facing source.

Implementation belongs under a stream-owned directory in [`src`](../../src/README.md),
and retained trial datasets belong under a descriptive directory in
[`assets`](../../assets/README.md). Each new implementation or asset directory
must receive its own README when it is created.

The implementation now lives in the [stream-owned source directory](../../src/effectful-source-fidelity/README.md),
and the frozen contracts, corpus, and campaign inputs live in the
[stream-owned asset directory](../../assets/effectful-source-fidelity/README.md).
Generated and secret-bearing intermediates stay below ignored
`build/effectful-source-fidelity/` paths.

## Fixed experiment contract

### Conditions

The experiment has exactly two representation conditions:

1. hand-authored A-Lang `alang-source-v2`; and
2. a closed `alang-task-json-v1` document decoded by OTP's JSON module.

The JSON control is the strongest conventional baseline in this stream. It is
schema-validated, statically checked, and lowered by a separate BEAM frontend
into the same normalized `alang_typed_task_ir_v2` semantics. It is not a JSON
interpreter and cannot bypass the backend, broker, or completion verifier.

Each paired source and JSON document must normalize to the same semantic digest
after representation-specific origins are removed. Acceptance tasks may not
start from hand-constructed IR. The model sees the original surface text, not
the normalized IR or the answer key.

Trial order is frozen with schedule seed `2026080501`. The representation is
necessarily visible because it is the treatment; opaque trial identities,
common instructions, and counterbalanced within-family order prevent extra
labels or ordering cues from revealing the condition name, semantic pair,
answer key, or expected outcome.

### Corpus and repetitions

The frozen corpus contains 24 semantic cases: eight cases in each of three
runtime families.

1. **Single-model artifact:** one bounded model judgment, one workspace write,
   and verifier-backed completion.
2. **Repair and publish:** one initial model judgment, at most one
   diagnostic-only repair, one workspace write, and verifier-backed completion.
3. **Attenuated delegation:** one parent model judgment, one more-restricted
   child task, one workspace write, and verifier-backed completion.

The eight cases in each family cover a simple goal, multiple hard constraints,
resource and budget limits, an explicit error branch, missing information that
must remain incomplete, irrelevant context, untrusted prompt-injection text,
and a semantics-preserving paraphrase/identifier perturbation. The corpus and
answer keys are frozen before any hosted call.

Each of the 24 cases runs three times in both notation conditions against both
model families: 288 primary calls. A single syntax-or-schema repair is allowed
only where the [first roadmap's Phase 6 repair contract](../01-minimal-proof-of-concept/phase-06-bounded-llm-task-and-subagent-execution.md)
already permits it. Repairs, definitive pre-submission retries, and recorded
replacement slots share a total campaign ceiling of 576 calls.

### Hosted model profiles

The two declared families are:

- OpenAI `gpt-5.6-terra` through the Responses API; and
- Anthropic `claude-sonnet-5` through the Messages API.

Both use medium effort, text input and output only, no provider tools, no
provider-side structured-output constraint, a single turn, an 8,192-token
provider output ceiling, an 8,192-byte accepted-output ceiling, and the same
model-visible instruction and JSON result schema. These identifiers and
capabilities were checked on 2026-08-05 against the official
[OpenAI model documentation](https://developers.openai.com/api/docs/models/gpt-5.6-terra),
[OpenAI model guidance](https://developers.openai.com/api/docs/guides/latest-model),
[Anthropic model documentation](https://platform.claude.com/docs/en/about-claude/models/overview),
and [Anthropic effort documentation](https://platform.claude.com/docs/en/build-with-claude/effort).
A campaign preflight must confirm the exact identifiers; it may not silently
substitute an alias or newer model.

Live calls are opt-in and never run under the default test target. They require
`ALANG_ALLOW_LIVE_MODEL_CALLS=1`, `ALANG_OPENAI_API_KEY`, and
`ALANG_ANTHROPIC_API_KEY`. The runner must fail closed above 576 calls or a
USD 200 declared maximum, and it must display the projected request count and
current price estimate before the operator confirms execution. Credentials,
authorization headers, raw HTTP envelopes, and provider-internal identifiers
must never enter repository evidence.

### Output and scoring contract

Every trial requests one `alang_task_comprehension_v1` JSON value containing
the case identity, goal facts, inputs, ordered action/dependency graph, effects,
requirements, resource scopes, budgets, error branches, child attenuation,
completion predicates, clarification needs, and expected terminal class.

Every definitive provider response is a primary observation. Refusal,
truncation, invalid UTF-8, malformed JSON, and schema failure score zero exact
fidelity and cannot be replaced. A repaired record is secondary only. A
replacement may fill a cell only when no definitive model response exists
because submission was proved absent or its transport outcome remains
uncertain; the failed attempt and replacement stay linked and count toward all
ceilings.

The primary metric is exact normalized semantic fidelity. Secondary metrics
report schema validity and exact component recovery, omitted constraints,
invented actions, authority widening, false completion, repair success, input
and output tokens, latency, and cost. Scoring is deterministic against the
frozen answer key; no LLM judge may determine the architecture outcome.

For each model family separately, A-Lang may advance only if its exact-fidelity
rate exceeds JSON by at least five percentage points and the lower bound of a
paired, task-family-stratified 95% bootstrap interval is above zero. The
bootstrap resamples the eight semantic cases within each task family, retains
all three paired condition repetitions for each selected case, uses the
percentile interval, runs 10,000 resamples, and fixes seed `20260805`.
Promotion also requires zero additional unauthorized effects or false
completions and no regression in the inherited compiler, broker, durability,
fault, adversarial, or completion gates.

If A-Lang does not meet that rule and JSON reaches at least 80% exact fidelity
in both model families, replace the novel user-facing surface with the typed
JSON control while retaining independently valuable runtime enforcement. If
either condition cannot reach 80% in both families, or any safety veto remains,
stop language-surface expansion and retain only the evidence-supported runtime
components.

An incomplete or invalid hosted campaign also stops language-surface expansion
without an efficacy conclusion. It cannot promote A-Lang, select JSON as the
better representation, or justify a post-hoc smaller experiment; a later retry
would require a newly authorized and pre-registered planning stream.

### Evidence retention

Commit the corpus, answer keys, canonical prompts, normalized model responses,
deterministic scores, bounded provider metadata, and content digests. Exclude
credentials, headers, raw transport envelopes, hidden reasoning, and unrelated
provider metadata. Offline replay of the redacted records must reproduce every
score and decision without network access.

## Architectural invariants

- Lexer, parser, JSON control decoder, resolver, checker, lowering, backend,
  campaign scheduler, scorer, and validators compile to `.beam` and run on
  ERTS.
- Accepted A-Lang is never translated to Erlang source or interpreted as
  Erlang AST/IR. Both representations reach the existing inspected Abstract
  Format backend and generated BEAM execution path.
- Hosted-provider access is a bounded runtime effect, not part of the compiler.
  Provider adapters use fixed BEAM sidecar modules and OTP HTTPS; no Python,
  Node, provider SDK, `curl`, NIF, or foreign compiler enters the trusted path.
- The current local broker, durable journal, child attenuation, workspace
  adapter, completion witness, and negative gates remain authoritative.
- The deterministic offline mock and replay suites remain mandatory. Live
  evidence supplements them and cannot make default tests network-dependent.
- General recursion, polymorphism, parallel composition, distribution,
  portable delegation, additional effect families, package management,
  self-hosting, and user-visible categorical notation remain frozen.
- No human authoring or review advantage may be claimed because this stream
  includes no human-subject study.

## Dependencies

- The first [minimal proof-of-concept roadmap](../01-minimal-proof-of-concept/README.md)
  is closed with a `revise` decision and provides the compiler, runtime, broker,
  durability, model, child, validation, and release evidence reused here.
- The [implementation status and risk record](../../src/phase-08/implementation-status-and-risk-record.md)
  identifies effectful source as the highest-priority gap.
- The [task-language inquiry](../../40-inquiries/can-a-task-language-improve-llm-agents.md)
  defines fidelity as faithful recovery of goals, constraints, authority, and
  completion rather than mere parse success.
- The [task-language synthesis](../../20-notes/llm-agent-task-languages-deep-dive.md)
  supplies the comparison and falsification rationale.

## Status and commit rules

- Every phase, section, task, and subtask begins unchecked.
- Implement and commit one numbered section at a time.
- Complete a section only when its implementation and negative tests provide
  the evidence named by that section.
- Complete a phase only when its final numbered integration-test section and
  phase completion-evidence checklist pass from a clean checkout.
- Do not mark the live campaign complete from mocks or replay alone.
- A model outage, missing credential, unavailable exact model identifier, or
  exhausted operator budget blocks live evidence; it does not authorize a
  substitution or a smaller unreported campaign.

## Phase order

```text
Phase 1: freeze experiment, semantics, corpus, and decisions
    -> Phase 2: parse the effectful A-Lang source surface
        -> Phase 3: check and lower A-Lang and typed JSON to matched IR
            -> Phase 4: compile and execute both paths through BEAM enforcement
                -> Phase 5: run and replay the bounded two-family evaluation
                    -> Phase 6: apply the frozen rule and publish the decision
```

## Roadmap completion gate

The stream is complete only when a clean checkout can reproduce all of the
following, with live-only items backed by a recorded opt-in campaign:

- [x] Twenty-four hand-authored A-Lang/JSON pairs validate against frozen
      semantic answer keys — see the [Phase 1 evidence](../../src/effectful-source-fidelity/phase-01-integration-evidence.md)
- [x] Every pair produces the same normalized semantic digest without manual IR
      — see the [Phase 3 evidence](../../src/effectful-source-fidelity/phase-03-integration-evidence.md)
- [x] Effectful source covers model, workspace, repair, child, and completion
      vocabulary with source-local diagnostics
- [ ] Both frontend paths produce inspected BEAM artifacts and execute through
      the same broker, durability, workspace, and completion boundaries
- [ ] All inherited Phase 1–8 offline, law, adversarial, fault, and mutation
      gates remain green
- [ ] Exactly 288 primary hosted trials, or an explicitly recorded invalid
      campaign, are accounted for under the call and cost ceilings
- [ ] Offline replay reproduces normalized trials, scores, bootstrap intervals,
      and the final decision byte-for-byte
- [ ] OpenAI and Anthropic results are reported separately as well as pooled
- [ ] No credentials, raw HTTP envelopes, hidden reasoning, or secret-bearing
      diagnostics appear in retained artifacts
- [ ] The promote, replace, or stop rule is applied without post-hoc threshold
      changes
- [ ] Research inquiries, maps, implementation status, and deferred work are
      reconciled with the result

## Index

### Subdirectories

- None yet.

### Documents

- [Phase 1 — Experiment contract and frozen corpus](phase-01-experiment-contract-and-frozen-corpus.md)
  — **complete**; fixes the semantic oracle, paired representations, campaign
  cells, scoring, safety vetoes, and decision rule before parsing or live use.
- [Phase 2 — Effectful source syntax and AST](phase-02-effectful-source-syntax-and-ast.md)
  — **complete**; extends the BEAM-resident lexer and parser with the minimal
  model, workspace, repair, child, limit, and completion surface and records
  the reproducible [frontend evidence](../../src/effectful-source-fidelity/phase-02-integration-evidence.md).
- [Phase 3 — Static semantics, manifests, and matched lowering](phase-03-static-semantics-manifests-and-matched-lowering.md)
  — **complete**; checks both A-Lang and typed JSON, derives authority, and
  proves matched lowering through the reproducible [Phase 3 evidence](../../src/effectful-source-fidelity/phase-03-integration-evidence.md).
- [Phase 4 — Source-to-BEAM enforcement integration](phase-04-source-to-beam-enforcement-integration.md)
  — compiles and executes every corpus family through the inspected BEAM
  backend and inherited runtime enforcement path.
- [Phase 5 — Hosted multi-model fidelity evaluation](phase-05-hosted-multi-model-fidelity-evaluation.md)
  — adds bounded BEAM provider sidecars, the opt-in campaign, deterministic
  scoring, redacted evidence, and offline replay.
- [Phase 6 — Fidelity decision and roadmap handoff](phase-06-fidelity-decision-and-roadmap-handoff.md)
  — applies the frozen threshold, records promote/replace/stop, and reconciles
  the archive without implying production readiness.

## Maintaining this index

Keep phase filenames and numbering stable once implementation evidence links
to them. Update status and evidence in place, inventory every new direct child,
and do not add a seventh phase to absorb deferred features. A materially new
question requires a later numbered planning stream.
