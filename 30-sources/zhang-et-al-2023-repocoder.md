---
title: "RepoCoder: Repository-Level Code Completion Through Iterative Retrieval and Generation"
kind: source
created: 2026-08-05
authors:
  - "Fengji Zhang"
  - "Bei Chen"
  - "Yue Zhang"
  - "Jacky Keung"
  - "Jin Liu"
  - "Daoguang Zan"
  - "Yi Mao"
  - "Jian-Guang Lou"
  - "Weizhu Chen"
published: 2023
citation_key: "zhang-et-al-2023-repocoder"
container: "Proceedings of the 2023 Conference on Empirical Methods in Natural Language Processing"
edition: null
isbn: null
doi: "10.18653/v1/2023.emnlp-main.151"
url: "https://aclanthology.org/2023.emnlp-main.151/"
accessed: 2026-08-05
tags:
  - code-completion
  - iterative-retrieval
  - repository-level-code
aliases:
  - "RepoCoder"
---

# RepoCoder: Repository-Level Code Completion Through Iterative Retrieval and Generation

## Reference

Fengji Zhang et al. “RepoCoder: Repository-Level Code Completion Through
Iterative Retrieval and Generation.” *Proceedings of EMNLP 2023*, pages
2471–2484. [ACL Anthology](https://aclanthology.org/2023.emnlp-main.151/).
DOI: [10.18653/v1/2023.emnlp-main.151](https://doi.org/10.18653/v1/2023.emnlp-main.151).

## Method

RepoCoder alternates retrieval and generation. Its first query comes from the
unfinished file; later queries combine that prefix with the model’s previous
completion. A similarity retriever returns fixed sliding-window snippets with
their file paths. RepoEval tests Python line, API-invocation, and function-body
completion with CodeGen and GPT-3.5-family generators.

## Findings

- Repository retrieval improves line and API exact match by more than ten
  absolute points over in-file completion in the reported settings.
- A second retrieve–generate pass usually improves on one-pass RAG, showing
  that a provisional answer can reveal better search terms. Later iterations
  are not consistently beneficial.
- Retrieved examples help when they expose analogous statements, project API
  usage, imports, or naming conventions. They hurt when an apparently similar
  use has different parameters or when a bad generation becomes the next noisy
  query.

## Relevance

The result favors a reference system that can be queried incrementally instead
of dumping every declared target into the first prompt. Paths and repeated API
uses are useful evidence, while iterative selection should remain a runtime
policy rather than a semantic promise of the source language.

## Limits

RepoCoder relies on repository duplication and lexical similarity, fixed code
windows, and a small number of model families. It does not compare
compiler-resolved symbols with embedded references, and iteration adds latency.
The authors identify low-duplication repositories and unstable later iterations
as open problems.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
