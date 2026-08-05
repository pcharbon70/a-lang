---
title: "SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering"
kind: source
created: 2026-08-05
authors:
  - "John Yang"
  - "Carlos E. Jimenez"
  - "Alexander Wettig"
  - "Kilian Lieret"
  - "Shunyu Yao"
  - "Karthik Narasimhan"
  - "Ofir Press"
published: 2024
citation_key: "yang-et-al-2024-swe-agent"
container: "Advances in Neural Information Processing Systems 37"
edition: null
isbn: null
doi: "10.52202/079017-1601"
url: "https://proceedings.neurips.cc/paper_files/paper/2024/hash/5a7c947568c1b1328ccc5230172e1e7c-Abstract-Conference.html"
accessed: 2026-08-05
tags:
  - agent-computer-interface
  - repository-level-code
  - software-engineering-agents
aliases:
  - "SWE-agent"
---

# SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering

## Reference

John Yang et al. “SWE-agent: Agent-Computer Interfaces Enable Automated
Software Engineering.” *Advances in Neural Information Processing Systems 37*,
2024. [Proceedings record](https://proceedings.neurips.cc/paper_files/paper/2024/hash/5a7c947568c1b1328ccc5230172e1e7c-Abstract-Conference.html).
DOI: [10.52202/079017-1601](https://doi.org/10.52202/079017-1601).

## Contribution

The paper treats the agent-computer interface (ACI)—actions, observations,
history, and guardrails—as an experimental variable. SWE-agent supplies small
navigation, search, viewing, editing, and execution commands with compact
feedback. Search results are summarized and capped, the viewer exposes a
100-line window, edits show their local result, and lint failures can roll back.

## Findings

- SWE-agent resolves 12.47% of the full original SWE-bench and 18% of
  SWE-bench Lite in the reported GPT-4 Turbo evaluation, a large improvement
  over a shell-only interface.
- On SWE-bench Lite, exhaustive search-result iteration scores 12% versus 18%
  for summarized search; full-file viewing scores 12.7% versus 18% for a
  100-line window; a 30-line window also falls to 14.3%.
- Keeping the complete interaction history scores below retaining the latest
  five observations, and lint feedback improves over edits without linting.

## Relevance

These ablations show that tool semantics and feedback shape can matter as much
as raw access. A useful source-reference facility should expose simple,
purpose-specific operations and concise evidence, with guardrails and a way to
request more, rather than forcing an agent to interpret a large navigation
dump.

## Limits

The interface bundles many design changes, and SWE-bench resolution is not a
direct measure of code understanding. The study does not use semantic symbol
identities or embedded source annotations, and its exact results depend on the
models and benchmark version tested.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
