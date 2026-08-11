---
title: "Token-efficient A-Lang syntax"
kind: map
created: 2026-08-11
tags:
  - a-lang
  - language-design
  - llm-agents
  - token-efficiency
aliases:
  - "Compact A-Lang syntax map"
---

# Token-efficient A-Lang syntax

## Scope

This map connects tokenizer behavior, source minification, identifier
semantics, prompt compression, compact constraint encodings, and learned code
shorthand to the narrower A-Lang question: what can be shortened without
weakening an executable agent contract?

## Starting points

- [Token-efficient syntax for A-Lang](../20-notes/token-efficient-syntax-for-a-lang.md)
  — the synthesis, local corpus accounting, dual-representation proposal, and
  experimental gate.
- [Open compact-projection inquiry](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
  — the operational question and hypotheses that remain untested.
- [A-Lang v2 language reference](../20-notes/alang-v2-language-reference.md) —
  the explicit task grammar and security-relevant declarations a projection
  must preserve.
- [Effectful source fidelity plan](../60-planning/02-effectful-source-fidelity/README.md)
  — the frozen A-Lang-versus-JSON campaign that must not be altered to add a
  compact-syntax condition.
- [Compact projection fidelity plan](../60-planning/03-compact-projection-fidelity/README.md)
  — the separate six-phase campaign that tests six reading conditions and a
  readable-versus-compact bidirectional core under token, non-inferiority,
  repair, perturbation, and safety gates.

## Tokenizers define the unit of cost

- [Tokenizer pre-training and domain adaptation](../30-sources/dagan-et-al-2024-tokenizer-domain-adaptation.md)
  — vocabulary, pre-tokenization, and domain data change code efficiency and
  downstream performance; tokenizer replacement is a large model-training
  intervention.
- [A token-efficient language for LLMs](../30-sources/rickard-2023-token-efficient-language.md)
  — a practitioner exercise showing that pretty JSON, YAML, and minified JSON
  change order with representation details and tokenizer choice.
- [Compact constraint encoding](../30-sources/tang-2026-compact-constraint-encoding.md)
  — compact familiar tags save tokens in one code-generation study, while a
  character-dense Classical Chinese condition tokenizes poorly.

## Layout and structural compaction

- [The hidden cost of readability](../30-sources/pan-et-al-2025-hidden-cost-readability.md)
  — AST-preserving format removal across four languages and ten models, with a
  bidirectional human/model representation.
- [State-in-context agent minification](../30-sources/hrubec-cito-2026-minification.md)
  — substantial end-to-end savings paired with a resolution loss, plus direct
  identifier-shortening ablations.
- [LLMLingua](../30-sources/jiang-et-al-2023-llmlingua.md) — evidence that
  compression should protect high-information instructions and token
  dependencies rather than remove all text uniformly.

## Identifier semantics and robustness

- [CodeT5](../30-sources/wang-et-al-2021-codet5.md) — identifier-aware
  pretraining treats developer names as a learnable semantic channel.
- [ReCode](../30-sources/wang-et-al-2023-recode.md) — meaning-preserving name,
  syntax, and format perturbations expose worst-case brittleness in code
  generation models.

Together these works make descriptive identifiers a separate experimental
factor. They do not forbid local aliases, but they rule out assuming that
runtime-equivalent renaming is model-equivalent.

## Learned shorthand

- [Token Sugar](../30-sources/sun-et-al-2025-token-sugar.md) — frequent
  token-heavy AST patterns can be represented by reversible special tokens
  after continual pretraining, while the same notation severely harms an
  unadapted model.

This trail supports mining real A-Lang usage later. It does not support opaque
macros in the current universal surface.

## Design trail

The synthesis recommends this order:

1. measure the current corpus with each target tokenizer;
2. test AST-preserving layout minification;
3. test a BEAM-produced, source-mapped projection of checked IR;
4. compress closed keywords, repeated paths, and reconstructible schema before
   user identifiers;
5. retain keyed budgets, explicit authority, and exact round trips;
6. consider learned macros only for declared, adapted model families.

## Open questions

- [Can a compact projection reduce A-Lang token use without reducing fidelity?](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
- Which current model tokenizer should define each deployment profile?
- Is a readable-to-compact projection useful in both model-reading and
  model-generation directions?
- Can compiler-generated local aliases retain the value of descriptive names
  while compressing repeated references?
- How much explicit redundancy should remain as an error-detecting code in the
  model-visible representation?
- What non-inferiority and safety margins should a future preregistered trial
  require before a compact form becomes default? The new campaign registers a
  five-point semantic margin and zero compact-only safety failures as its
  initial answer, subject to its pre-observation power audit.
