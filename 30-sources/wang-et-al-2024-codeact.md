---
title: "Executable Code Actions Elicit Better LLM Agents"
kind: source
created: 2026-07-30
authors:
  - "Xingyao Wang"
  - "Yangyi Chen"
  - "Lifan Yuan"
  - "Yizhe Zhang"
  - "Yunzhu Li"
  - "Hao Peng"
  - "Heng Ji"
published: 2024
citation_key: wang2024CodeAct
url: "https://proceedings.mlr.press/v235/wang24h.html"
accessed: 2026-07-30
tags:
  - agent-actions
  - executable-code
  - tool-use
aliases:
  - "CodeAct"
---

# Executable Code Actions Elicit Better LLM Agents

## Reference

Xingyao Wang, Yangyi Chen, Lifan Yuan, Yizhe Zhang, Yunzhu Li, Hao Peng, and
Heng Ji. “Executable Code Actions Elicit Better LLM Agents.” ICML 2024.
[Paper](https://proceedings.mlr.press/v235/wang24h.html)

## Method

CodeAct replaces separate text or JSON tool calls with executable Python as the
agent’s action representation. The interpreter supplies observations, and the
model can compose tools, manipulate intermediate values, revise code, and
self-debug over multiple turns.

## Finding

Across seventeen LLMs on API-Bank and M3ToolEval, CodeAct reported success rates
up to 20% higher than common text and JSON alternatives. The authors also
created a 7,000-trajectory instruction-tuning dataset for code-action agents.

## Relevance

Code is a strong action language because it already provides variables,
composition, control flow, library reuse, and executable feedback. This does not
make it the ideal language of intent: goals and invariants should remain
declarative, while code can be one compiled or model-generated action layer.

## Limits

Executing model-generated general-purpose code increases the security boundary
and requires sandboxing, resource limits, and capability controls. Python syntax
can express unsafe or irrelevant behavior just as easily as useful behavior.
