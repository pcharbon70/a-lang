---
title: "Agent Programming with Declarative Goals"
kind: source
created: 2026-07-30
authors:
  - "Frank S. de Boer"
  - "Koen V. Hindriks"
  - "Wiebe van der Hoek"
  - "John-Jules Ch. Meyer"
published: 2002
citation_key: deBoer2002GOAL
url: "https://arxiv.org/abs/cs/0207008"
accessed: 2026-07-30
tags:
  - agent-programming
  - declarative-goals
  - formal-semantics
aliases:
  - "GOAL"
---

# Agent Programming with Declarative Goals

## Reference

F. S. de Boer, K. V. Hindriks, W. van der Hoek, and J.-J. Ch. Meyer.
“Agent Programming with Declarative Goals.” 2002.
[Paper](https://arxiv.org/abs/cs/0207008)

## Research question

How can an agent programming language represent goals as states to achieve,
rather than reducing them to procedures the agent must execute?

## Contribution

The paper introduces GOAL, a language built around beliefs, declarative goals,
actions, and commitment strategies. A goal describes what should become true;
the agent may select actions based on its beliefs without confusing the goal
with a fixed plan. The work also supplies computational semantics and a proof
theory for reasoning about program correctness.

## Relevance

This distinction is central to an LLM task language. User intent should normally
be represented as a goal-to-be, with constraints and success predicates, while
plans remain replaceable hypotheses. Otherwise the task language risks freezing
one guessed implementation and making recovery unnecessarily difficult.

## Limits

GOAL predates LLM agents and assumes symbolic beliefs and actions. It does not
solve natural-language grounding, uncertain perception, or probabilistic model
behavior. Its value here is architectural and semantic rather than a direct
empirical result about LLMs.
