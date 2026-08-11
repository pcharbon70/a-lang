---
title: "A Token Efficient Language for LLMs"
kind: source
created: 2026-08-11
authors:
  - "Matt Rickard"
published: 2023
citation_key: "rickard-2023-token-efficient-language"
container: "Matt Rickard blog"
edition: null
isbn: null
doi: null
url: "https://blog.matt-rickard.com/p/a-token-efficient-language-for-llms"
accessed: 2026-08-11
tags:
  - practitioner-report
  - serialization
  - token-efficiency
aliases: []
---

# A Token Efficient Language for LLMs

## Reference

Matt Rickard. “A Token Efficient Language for LLMs.” June 15, 2023.
[Blog post](https://blog.matt-rickard.com/p/a-token-efficient-language-for-llms).

## Exercise

Rickard serializes one nested object in JSON, YAML, TOML, XML, HCL, INI, and a
sketched notation, then counts tokens with OpenAI and LLaMA tokenizers. In the
OpenAI example, pretty JSON uses 162 tokens, YAML 85, and minified JSON 64. The
post observes that common punctuation groups and words can already be single
tokens, and that the ordering changes under a different tokenizer.

## Relevance

The post is a useful practitioner counterexample to format folklore: YAML is
not automatically smaller than JSON when pretty-printing is controlled. It
also poses the right unresolved question for A-Lang—whether a model will
generate familiar JSON more reliably than an invented notation even when the
invented notation is shorter.

## Limits

This is an exploratory blog post with one hand-built object, not a controlled
task-performance study. The author explicitly treats the generalization as an
assumption and leaves comprehension and cross-tokenizer effects open. Its
numbers illustrate why to measure; they do not rank formats universally.

## Derived notes

- [Token-efficient syntax for A-Lang](../20-notes/token-efficient-syntax-for-a-lang.md)
- [Can a compact projection reduce A-Lang token use without reducing fidelity?](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
- [Token-efficient A-Lang syntax](../10-maps/token-efficient-alang-syntax.md)
