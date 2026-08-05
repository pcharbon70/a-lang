---
title: "AutoCodeRover: Autonomous Program Improvement"
kind: source
created: 2026-08-05
authors:
  - "Yuntong Zhang"
  - "Haifeng Ruan"
  - "Zhiyu Fan"
  - "Abhik Roychoudhury"
published: 2024
citation_key: "zhang-et-al-2024-autocoderover"
container: "Proceedings of the 33rd ACM SIGSOFT International Symposium on Software Testing and Analysis"
edition: null
isbn: "979-8-4007-0612-7"
doi: "10.1145/3650212.3680384"
url: "https://doi.org/10.1145/3650212.3680384"
accessed: 2026-08-05
tags:
  - program-analysis
  - repository-level-code
  - software-engineering-agents
aliases:
  - "AutoCodeRover"
---

# AutoCodeRover: Autonomous Program Improvement

## Reference

Yuntong Zhang, Haifeng Ruan, Zhiyu Fan, and Abhik Roychoudhury.
“AutoCodeRover: Autonomous Program Improvement.” *Proceedings of ISSTA 2024*,
pages 1592–1604. DOI:
[10.1145/3650212.3680384](https://doi.org/10.1145/3650212.3680384).

## Method

AutoCodeRover gives an LLM a set of iterative, AST-aware search operations
rather than treating a repository only as flat text. Class search returns a
compact signature, method search can return an implementation, and code search
returns a small surrounding window. Optional spectrum-based fault localization
adds test evidence before a separate patch-generation stage.

## Findings

- The original system resolves 57 of 300 SWE-bench Lite issues at pass@1
  (19%), at a reported average of about four minutes and US$0.43 per issue.
- Three independent runs reach 26% pass@3. Manual analysis judges 51 of those
  78 test-plausible patches correct (65.4%), illustrating that test passage
  alone can overstate correctness.
- Returning a class signature instead of an entire class is an intentional
  defense against long, distracting context. Issue text, search results, and
  even correct localization can still lead to a wrong patch.

## Relevance

The system is evidence for semantically scoped projections such as
`signature`, `definition`, and `tests`, and for iterative expansion under agent
control. It motivates making the projection part of a reference request rather
than equating a target with its entire file.

## Limits

The evaluation is primarily Python and SWE-bench Lite, the model is stochastic,
and test validation can accept overfitted patches. The authors identify call
graphs, data dependence, and language-server navigation as future additions;
the paper does not compare source-embedded references with generated indexes.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
