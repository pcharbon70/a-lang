---
title: "LLM+P: Empowering Large Language Models with Optimal Planning Proficiency"
kind: source
created: 2026-07-30
authors:
  - "Bo Liu"
  - "Yuqian Jiang"
  - "Xiaohan Zhang"
  - "Qiang Liu"
  - "Shiqi Zhang"
  - "Joydeep Biswas"
  - "Peter Stone"
published: 2023
citation_key: liu2023LLMPlusP
url: "https://arxiv.org/abs/2304.11477"
accessed: 2026-07-30
tags:
  - planning
  - pddl
  - task-specification
aliases:
  - "LLM+P"
---

# LLM+P: Empowering Large Language Models with Optimal Planning Proficiency

## Reference

Bo Liu, Yuqian Jiang, Xiaohan Zhang, Qiang Liu, Shiqi Zhang, Joydeep Biswas,
and Peter Stone. “LLM+P: Empowering Large Language Models with Optimal Planning
Proficiency.” 2023.
[Paper](https://arxiv.org/abs/2304.11477)

## Method

LLM+P translates a natural-language planning problem into PDDL, invokes a
classical planner, and translates the resulting plan back into natural language.
The LLM performs semantic translation while the planner performs combinatorial
search and checks action preconditions and effects.

## Finding

Across the authors’ benchmark planning problems, LLM+P produced optimal
solutions for most cases, whereas direct LLM planning failed to produce even
feasible plans for most cases.

## Relevance

Task languages should not ask the LLM to simulate a planner when an actual
planner is available. Explicit initial state, goal state, action preconditions,
and effects make feasibility and optimality mechanically testable.

## Limits

PDDL requires a closed-world domain model and crisp predicates. Translating
underspecified real-world instructions into a correct initial state and domain
is difficult, and optimal symbolic plans can still fail when the environment
model is incomplete.
