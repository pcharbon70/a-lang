---
title: "Do Prompt-Based Models Really Understand the Meaning of Their Prompts?"
kind: source
created: 2026-07-30
authors:
  - "Albert Webson"
  - "Ellie Pavlick"
published: 2022
citation_key: webson2022promptMeaning
doi: "10.18653/v1/2022.naacl-main.167"
url: "https://aclanthology.org/2022.naacl-main.167/"
accessed: 2026-07-30
tags:
  - prompt-understanding
  - instruction-following
  - evaluation
aliases: []
---

# Do Prompt-Based Models Really Understand the Meaning of Their Prompts?

## Reference

Albert Webson and Ellie Pavlick. “Do Prompt-Based Models Really Understand the
Meaning of Their Prompts?” NAACL 2022.
[Paper](https://aclanthology.org/2022.naacl-main.167/)

## Method

The authors tested more than thirty manually written prompts for natural
language inference, including relevant, irrelevant, and deliberately misleading
instructions. Their experiments covered prompt-based and instruction-tuned
models, including models up to 175 billion parameters.

## Finding

Many irrelevant or misleading prompts learned as quickly as instructive prompts,
and instruction-tuned models could produce good zero-shot predictions from
instructions that did not communicate the task correctly to a human. Performance
therefore cannot, by itself, establish human-like semantic understanding of an
instruction.

## Relevance

Claims that a programming language makes an LLM “understand” tasks need stronger
tests than benchmark accuracy. Evaluation should include paraphrases,
counterfactual constraint changes, missing-information cases, and explicit
reconstruction of the intended task model.

## Limits

The experiments focus on natural-language inference and model generations that
precede many modern reasoning and agent systems. They establish a conceptual and
evaluation warning, not that current models never interpret instructions
semantically.
