---
title: "AgentSPEX: An Agent SPecification and EXecution Language"
kind: source
created: 2026-07-30
authors:
  - "Pengcheng Wang"
  - "Jerry Huang"
  - "Jiarui Yao"
  - "Rui Pan"
  - "Peizhi Niu"
  - "Yaowenqi Liu"
  - "Ruida Wang"
  - "Renhao Lu"
  - "Yuwei Guo"
  - "Tong Zhang"
published: 2026
citation_key: wang2026AgentSPEX
url: "https://arxiv.org/abs/2604.13346"
accessed: 2026-07-30
tags:
  - agent-dsl
  - workflow-language
  - context-management
aliases:
  - "AgentSPEX"
---

# AgentSPEX: An Agent SPecification and EXecution Language

## Reference

Pengcheng Wang et al. “AgentSPEX: An Agent SPecification and EXecution
Language.” arXiv preprint, 2026.
[Paper](https://arxiv.org/abs/2604.13346)

## Contribution

AgentSPEX uses human-readable YAML to describe an executable agent workflow. It
includes typed steps, conditions, loops, parallelism, submodules, variables, and
explicit conversation-context choices. A harness validates and interprets the
workflow, provides sandboxed tools, and records checkpoints and traces.

## Finding

The preprint reports the highest score among its compared approaches on seven
benchmarks. Against the stronger chain-of-thought or ReAct baseline, reported
gains range from 0.7 percentage points on WritingBench to 6.5 points on
ELAIPBench. A useful ablation puts the same workflow into a ReAct prompt but
does not enforce it; that version can underperform plain chain-of-thought,
whereas interpreter-enforced execution performs better.

A 23-participant user study found AgentSPEX more approachable and readable for
starting workflows, while participants often preferred LangGraph’s perceived
rigor and flexibility for complex workflows.

## Relevance

This is the most direct current implementation of the proposed direction:
natural-language instructions embedded in a structured, executable workflow,
with explicit state and context controlled by a runtime.

## Limits

As of this note, the work is a recent preprint. Workflows were manually written
with coding-assistant help, benchmarks used different frontier models, and the
evaluation does not isolate every language feature. It demonstrates system-level
task performance and authoring usability, not a change in the model’s internal
semantic understanding.
