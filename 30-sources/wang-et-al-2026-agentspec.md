---
title: "AgentSpec: Customizable Runtime Enforcement for Safe and Reliable LLM Agents"
kind: source
created: 2026-07-30
authors:
  - "Haoyu Wang"
  - "Christopher M. Poskitt"
  - "Jun Sun"
published: 2026
citation_key: wang2026AgentSpec
url: "https://arxiv.org/abs/2503.18666"
accessed: 2026-07-30
tags:
  - agent-dsl
  - runtime-enforcement
  - safety
aliases:
  - "AgentSpec"
---

# AgentSpec: Customizable Runtime Enforcement for Safe and Reliable LLM Agents

## Reference

Haoyu Wang, Christopher M. Poskitt, and Jun Sun.
“AgentSpec: Customizable Runtime Enforcement for Safe and Reliable LLM Agents.”
ICSE 2026.
[Paper](https://arxiv.org/abs/2503.18666)

## Contribution

AgentSpec is a small DSL for runtime rules consisting of triggers, predicates,
and enforcement actions. Rules are parsed independently of the LLM and checked
around observed agent events, allowing the runtime to block, modify, or require
review of unsafe actions.

## Finding

The evaluation reports prevention of unsafe execution in more than 90% of code
agent cases, elimination of hazardous actions in the embodied-agent tasks, and
complete compliance in the tested autonomous-driving scenarios, with
millisecond-scale overhead. The paper also evaluates LLM-generated rules, which
are helpful but less complete than manual rules.

## Relevance

Hard constraints should be enforced by a reference monitor, not placed only in
the prompt. A task language needs an explicit boundary between advisory
preferences, verifier-backed obligations, and permissions that the agent cannot
override.

## Limits

Guarantees depend on complete event interception and correct predicates. The
reported benchmarks cover selected risk categories, and manually authored rules
still encode important domain knowledge.
