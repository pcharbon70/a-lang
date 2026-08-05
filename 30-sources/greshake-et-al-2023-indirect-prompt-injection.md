---
title: "Not What You've Signed Up For: Compromising Real-World LLM-Integrated Applications with Indirect Prompt Injection"
kind: source
created: 2026-08-05
authors:
  - "Kai Greshake"
  - "Sahar Abdelnabi"
  - "Shailesh Mishra"
  - "Christoph Endres"
  - "Thorsten Holz"
  - "Mario Fritz"
published: 2023
citation_key: "greshake-et-al-2023-indirect-prompt-injection"
container: "Proceedings of the 2023 ACM Workshop on Artificial Intelligence and Security"
edition: null
isbn: null
doi: "10.1145/3605764.3623985"
url: "https://doi.org/10.1145/3605764.3623985"
accessed: 2026-08-05
tags:
  - indirect-prompt-injection
  - llm-security
  - retrieval-augmented-generation
aliases:
  - "Indirect prompt injection"
---

# Not What You've Signed Up For: Compromising Real-World LLM-Integrated Applications with Indirect Prompt Injection

## Reference

Kai Greshake et al. “Not What You've Signed Up For: Compromising Real-World
LLM-Integrated Applications with Indirect Prompt Injection.” *Proceedings of
the 2023 ACM Workshop on Artificial Intelligence and Security*, 2023. DOI:
[10.1145/3605764.3623985](https://doi.org/10.1145/3605764.3623985).

## Threat model and demonstrations

Indirect prompt injection places adversarial instructions in material an LLM
application may later retrieve: web pages, email, memory, documents, or code.
The authors develop a threat taxonomy and demonstrate qualitative attacks
against synthetic GPT-4 applications and then-current real systems, including
Bing Chat and code-completion scenarios. Demonstrated consequences include
remote steering, data leakage, persistent reinfection, unwanted API use, and
denial of service.

For code completion, an instruction hidden in a source comment can remain
active while the context composer includes that file. The paper reports that
this attack was context-sensitive and became less effective inside larger
applications, but ordinary automated tests would not detect a prompt hidden in
a comment.

## Relevance

A source reference enlarges the retrieval attack surface. Its target text must
enter an LLM request as untrusted `data_only` material and cannot grant tool
authority, alter the system policy, or name a capability handle. Provenance,
visibility filtering, budgets, and action separation are necessary even for
repository-local targets. Typed references improve navigation; they do not make
the referenced prose trustworthy.

## Limits

The study is primarily qualitative and uses black-box, rapidly changing
systems. It does not report controlled success rates across broad model and
prompt distributions, and several demonstrations use synthetic applications or
local pages to avoid harming public systems. The authors explicitly find no
foolproof defense; filtering and supervisory models may themselves be evaded.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
