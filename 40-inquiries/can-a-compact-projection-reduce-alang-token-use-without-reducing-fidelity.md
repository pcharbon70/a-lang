---
title: "Can a compact projection reduce A-Lang token use without reducing fidelity?"
kind: inquiry
created: 2026-08-11
status: open
tags:
  - a-lang
  - language-design
  - llm-agents
  - token-efficiency
aliases:
  - "Can A-Lang become more token-efficient?"
---

# Can a compact projection reduce A-Lang token use without reducing fidelity?

## Why this matters

A-Lang repeats closed vocabulary, paths, declarations, and keyed budgets so a
human and compiler can inspect an effectful task contract. Those repetitions
consume model context and generation steps. Shortening them could lower cost
and allow more task evidence inside a bounded context, but an unfamiliar or
opaque notation could make models omit a prohibition, confuse a budget, widen
authority, or require enough repairs to erase the saving.

The question is not whether a shorter serialization exists. It is whether a
reversible, BEAM-produced compact form retains the language's semantic and
safety advantages across the actual model families A-Lang uses.

## Operational question

Relative to readable `alang-source-v2`, can a versioned model-facing view be
strictly token-positive on every frozen document and full request, achieve at
least 5% aggregate and median savings per target tokenizer and model protocol,
and preserve:

- exact goal, input, action, dependency, effect, requirement, scope, budget,
  error, child, completion, clarification, and terminal fields;
- syntax and repair reliability in both reading and generation directions;
- zero additional authority widening, unauthorized effects, and false
  completion;
- usable source-mapped diagnostics and human review?

## Working hypotheses

1. Layout minification will save a modest number of tokens without a material
   fidelity loss because A-Lang has explicit delimiters.
2. Compressing closed keywords and repeated schema will provide more savings
   than shortening user identifiers.
3. A checked projection may safely omit fields that the decoder restores from
   the typed IR, while the same omission in authored source would remove a
   useful cross-check.
4. Opaque identifiers will provide a small incremental saving and a larger
   robustness penalty, particularly for resource roles and evidence targets.
5. Mnemonic aliases composed from common tokenizer vocabulary will transfer
   better than arbitrary punctuation, Unicode density, or novel macro tokens.
6. A projection that wins on one tokenizer will not necessarily win by the
   same amount on another model family.
7. Learned semantic macros will require model adaptation and will perform
   poorly as a zero-shot universal surface.

## Paths to explore

- Build a section- and lexeme-level token audit for every current A-Lang and
  JSON corpus document under the declared model tokenizers.
- Define layout, keyword, schema, identifier, and macro conditions separately;
  do not bundle them into one “compact” treatment.
- Require deterministic `decode(encode(IR)) = IR` and stable semantic digests
  before any model trial.
- Compare reading, generation, diagnostic repair, next-action selection, and
  completion judgment under the same task semantics.
- Add adversarial cases for same-prefix identifiers, one-digit budgets,
  negation, repeated paths, missing facts, prompt injection, and child-scope
  attenuation.
- Report exact fidelity, worst-case safety, repairs, latency, cost, human
  diagnostic quality, and actual provider token usage together.
- Keep this study separate from the frozen
  [effectful source fidelity plan](../60-planning/02-effectful-source-fidelity/README.md);
  implement and preregister it through the separate
  [compact projection fidelity plan](../60-planning/03-compact-projection-fidelity/README.md).

## Findings

- [Token-efficient syntax for A-Lang](../20-notes/token-efficient-syntax-for-a-lang.md)
  finds support for a reversible checked projection, not for globally opaque
  authored identifiers.
- A screening count over the 24 current model-visible A-Lang documents finds
  about 7–9% savings from layout minification and about 28% from a combined
  checked compact projection under two tiktoken proxies. Making user
  identifiers opaque adds only about 5.4 percentage points. These counts do
  not measure model fidelity.
- [Formatting-removal research](../30-sources/pan-et-al-2025-hidden-cost-readability.md)
  supports AST-preserving bidirectional layout transforms, with task and
  language qualifications.
- [Agent minification research](../30-sources/hrubec-cito-2026-minification.md)
  reports a 42% input reduction paired with a 12-point resolution loss, and
  its identifier-only ablations show small savings with uneven performance.
- [Token Sugar](../30-sources/sun-et-al-2025-token-sugar.md) demonstrates
  reversible learned macros after continual pretraining, but its zero-shot
  GPT-4.1 result falls from 94.5% to 51.2% Pass@1.
- [Compact constraint encoding](../30-sources/tang-2026-compact-constraint-encoding.md)
  provides preliminary evidence that mnemonic structured headers can save
  tokens without a detected compliance loss, while also showing that
  character-dense text can tokenize poorly.
- [CodeT5](../30-sources/wang-et-al-2021-codet5.md) and
  [ReCode](../30-sources/wang-et-al-2023-recode.md) support treating names and
  syntax as model-visible semantic signals whose perturbation must be tested.
- [Compact projection Phase 2 evidence](../src/compact-projection-fidelity/section-02-04-integration-evidence.md)
  falsifies byte length as a proxy for the first promotion candidate. Across
  72 cases, keyed R3 was 8.34% smaller in bytes but used 8.33% more
  `cl100k_base` and 13.10% more `o200k_base` document tokens than readable R0.
  Mnemonic R2 instead used 8.72% and 7.96% fewer document tokens and was
  strictly cheaper on every measured document and full request. These remain
  offline counts, not model-fidelity evidence.

## Outcome

The inquiry remains open. The original separately numbered
[compact projection campaign](../60-planning/03-compact-projection-fidelity/README.md)
successfully implemented its offline representations and validators, but its
sole candidate R3 cannot satisfy a token-positive promotion purpose. That
campaign remains unchanged as a provenance record and does not authorize a
live R3 campaign.

The prospective
[token-positive mnemonic campaign](../60-planning/04-token-positive-mnemonic-promotion/README.md)
gives the exact measured R2 bytes a new campaign-local candidate role without
retrofitting the old campaign. It requires byte-for-byte R2 conformance, fresh
confirmatory cases, all four task protocols, two exact model families,
pairwise token nonregression, at least 5% aggregate and median savings,
registered fidelity non-inferiority, and zero candidate-only safety failures.
Until that new registration is frozen and its model campaign passes every
gate, `alang-source-v2` remains the readable source of truth and mnemonic
notation has no authority to satisfy an execution gate.
