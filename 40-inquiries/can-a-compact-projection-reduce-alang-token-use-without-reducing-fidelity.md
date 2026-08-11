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

Relative to readable `alang-source-v2` and the current typed-JSON control, can
a versioned projection of the checked task IR achieve at least 20% median token
savings per target tokenizer while preserving:

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

## Outcome

The inquiry remains open. The current evidence justifies a BEAM-native
prototype and controlled experiment, now designed as the separately numbered
[compact projection campaign](../60-planning/03-compact-projection-fidelity/README.md),
not a user-facing grammar change. Its initial confirmatory design has 24 new
semantic cases, six comprehension conditions, two core bidirectional
conditions, four model-task protocols, two exact model families, two
repetitions, and 1,152 primary cells. Until that campaign passes its
preregistered token, non-inferiority, repair, robustness, and safety gates,
`alang-source-v2` remains the readable source of truth, the frozen fidelity
campaign remains unchanged, and compact notation has no authority to satisfy
an execution gate.
