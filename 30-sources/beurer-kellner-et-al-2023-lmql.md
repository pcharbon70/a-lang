---
title: "Prompting Is Programming: A Query Language for Large Language Models"
kind: source
created: 2026-07-30
authors:
  - "Luca Beurer-Kellner"
  - "Marc Fischer"
  - "Martin Vechev"
published: 2023
citation_key: beurerKellner2023LMQL
url: "https://arxiv.org/abs/2212.06094"
accessed: 2026-07-30
tags:
  - prompt-programming
  - constrained-generation
  - language-model-programs
aliases:
  - "LMQL"
---

# Prompting Is Programming: A Query Language for Large Language Models

## Reference

Luca Beurer-Kellner, Marc Fischer, and Martin Vechev.
“Prompting Is Programming: A Query Language for Large Language Models.”
PLDI 2023.
[Paper](https://arxiv.org/abs/2212.06094)

## Contribution

LMQL combines natural-language prompts with scripting, control flow, and
constraints over generated values. Its compiler turns a language-model program
into an inference procedure that can stop or restrict generation as soon as
constraints determine that continuations are invalid.

## Finding

The evaluation reports retained or improved accuracy across several downstream
tasks while reducing computation or paid-API cost by 26–85%.

## Relevance

LMQL demonstrates that prompt construction and output constraints deserve
programming-language semantics. It is especially relevant to typed result
channels and constrained values in an agent task language.

## Limits

LMQL primarily structures prompts and generation. It does not by itself define
user intent, model world state, tool effects, safety policies, or success
criteria for a long-lived agent. Much of its evidence concerns efficiency and
output control rather than improved task interpretation.
