---
title: "SWE-QA: Can Language Models Answer Repository-level Code Questions?"
kind: source
created: 2026-08-05
authors:
  - "Weihan Peng"
  - "Yuling Shi"
  - "Yuhang Wang"
  - "Xinyun Zhang"
  - "Beijun Shen"
  - "Xiaodong Gu"
published: 2026
citation_key: "peng-et-al-2026-swe-qa"
container: "Findings of the Association for Computational Linguistics: ACL 2026"
edition: null
isbn: "979-8-89176-395-1"
doi: "10.18653/v1/2026.findings-acl.402"
url: "https://aclanthology.org/2026.findings-acl.402/"
accessed: 2026-08-05
tags:
  - code-question-answering
  - code-understanding
  - repository-level-code
aliases:
  - "SWE-QA"
---

# SWE-QA: Can Language Models Answer Repository-level Code Questions?

## Reference

Weihan Peng et al. “SWE-QA: Can Language Models Answer Repository-level Code
Questions?” *Findings of ACL 2026*, pages 8230–8245.
[ACL Anthology](https://aclanthology.org/2026.findings-acl.402/). DOI:
[10.18653/v1/2026.findings-acl.402](https://doi.org/10.18653/v1/2026.findings-acl.402).

## Method

SWE-QA contains 720 human-verified question–answer pairs across 15 Python
repositories. Its taxonomy includes intention, architecture, location,
cross-file, and multi-hop dependency questions. The authors compare direct
prompting, function chunks, sliding windows, SWE-agent, and OpenHands across
six current model families. Claude Sonnet 4.5 judges five answer dimensions,
with a limited human study used as a check.

## Findings

- Every tested model benefits from repository context. GPT-5.1 rises from
  61.41/100 directly to 66.57 with function chunks, 66.79 with sliding-window
  retrieval, and 70.79 with OpenHands.
- Agent frameworks tend to outperform one-shot retrieval for larger models,
  but not uniformly for the smallest tested model. Deep locational and
  dependency questions remain harder than rationale questions whose evidence
  is explicit in natural language.
- The improvement is expensive. Average input per question is 94 tokens for
  direct prompting, 3,042 for function chunks, 6,302 for sliding windows,
  87,045 for OpenHands, and 126,026 for SWE-agent in the paper’s accounting.

## Relevance

SWE-QA supplies an operational target for “understanding” beyond completion:
an agent should answer architectural, dependency, intent, and location
questions with evidence. It also makes efficiency a first-class outcome and
supports a structured-navigation comparison under equal context budgets.

## Limits

The benchmark covers static snapshots of 15 Python projects. Questions are
partly instantiated and answers initially drafted with LLM assistance before
human review. The primary metric is another LLM’s judgment, human validation is
limited, and the experiment bundles each agent’s navigation, memory, and model
behavior. It does not isolate source-embedded references.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
