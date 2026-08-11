---
title: "Getting the Most out of Your Tokenizer for Pre-training and Domain Adaptation"
kind: source
created: 2026-08-11
authors:
  - "Gautier Dagan"
  - "Gabriel Synnaeve"
  - "Baptiste Roziere"
published: 2024
citation_key: "dagan-et-al-2024-tokenizer-domain-adaptation"
container: "Proceedings of the 41st International Conference on Machine Learning"
edition: null
isbn: null
doi: null
url: "https://proceedings.mlr.press/v235/dagan24a.html"
accessed: 2026-08-11
tags:
  - code-generation
  - domain-adaptation
  - tokenization
aliases: []
---

# Getting the Most out of Your Tokenizer for Pre-training and Domain Adaptation

## Reference

Gautier Dagan, Gabriel Synnaeve, and Baptiste Roziere. “Getting the Most out
of Your Tokenizer for Pre-training and Domain Adaptation.” *Proceedings of the
41st International Conference on Machine Learning*, PMLR 235, pages
9784–9805, 2024. [PMLR](https://proceedings.mlr.press/v235/dagan24a.html).

## Method

The authors ablate Byte-Pair Encoding vocabulary size, pre-tokenization regular
expressions, and training data. They train code-specialized tokenizers and
models, then evaluate generation speed, effective context length, memory, and
downstream code generation on HumanEval and MBPP. They also study how to move
a pretrained model to a new tokenizer rather than assuming the original
tokenizer is fixed forever.

## Findings

Tokenizer construction materially changes both the number of tokens needed to
represent code and downstream model behavior. The authors report that
tokenizer specialization can yield large speed and effective-context gains
when the accompanying fine-tuning corpus exceeds roughly 50 billion tokens.
Vocabulary size, the pre-tokenizer, and domain match are therefore part of the
model design, not neutral accounting choices.

## Relevance

An A-Lang spelling cannot be called compact from its character count. It must
be measured with every deployed model's tokenizer. The work also distinguishes
two strategies that have very different costs: designing A-Lang text for
existing tokenizers is immediately testable, while adapting a tokenizer
requires control of model training and a very large adaptation corpus.

## Limits

The paper studies code model training and domain adaptation, not zero-shot
understanding of a new task DSL by hosted models. Its scale threshold makes
tokenizer replacement an implausible first optimization for A-Lang.

## Derived notes

- [Token-efficient syntax for A-Lang](../20-notes/token-efficient-syntax-for-a-lang.md)
- [Can a compact projection reduce A-Lang token use without reducing fidelity?](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
- [Token-efficient A-Lang syntax](../10-maps/token-efficient-alang-syntax.md)
