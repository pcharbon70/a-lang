---
title: "Symbol-Aware Code Context for LLM Agents"
kind: map
created: 2026-08-05
tags:
  - code-understanding
  - context-engineering
  - llm-agents
  - repository-level-code
aliases:
  - "Source references and symbols for LLMs"
---

# Symbol-Aware Code Context for LLM Agents

## Scope

This map follows the question of whether repository-local symbols, references,
tests, contracts, and documentation should become typed inputs to an LLM
agent—and whether authored source relations add anything beyond a generated
code-intelligence index.

## Starting points

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
  — the evidence synthesis, provisional A-Lang model, security boundary, and
  falsifiable experiment.
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
  — the open decision and promotion gate.

## Trail 1: Why repository context matters

- [CrossCodeEval](../30-sources/ding-et-al-2023-crosscodeeval.md) establishes a
  multilingual completion benchmark whose tasks require cross-file context and
  shows the gap between ordinary and reference-informed retrieval.
- [RepoCoder](../30-sources/zhang-et-al-2023-repocoder.md) shows that an
  iterative draft can refine the next retrieval query, while noisy iterations
  can also compound mistakes.
- [SWE-QA](../30-sources/peng-et-al-2026-swe-qa.md) broadens the target from
  completion to architecture, location, intent, and multi-hop dependency
  questions, exposing a large cost difference between RAG and agent traversal.

## Trail 2: Selection before inclusion

- [Repoformer](../30-sources/wu-et-al-2024-repoformer.md) supplies the strongest
  warning against unconditional retrieval: most standard retrievals do not
  improve completion and a meaningful fraction are harmful.
- [RepoGraph](../30-sources/ouyang-et-al-2025-repograph.md) supports bounded
  typed neighborhoods and shows a two-hop flattened graph becoming too large
  and less effective.
- [Aider’s repository map](../30-sources/aider-2026-repository-map.md) is the
  practical generated-map baseline: definitions and references feed a
  personalized graph ranker and a token-bounded structural rendering.

## Trail 3: Give agents semantic operations

- [AutoCodeRover](../30-sources/zhang-et-al-2024-autocoderover.md) separates
  class signatures, method implementations, small code windows, and tests as
  distinct search projections.
- [SWE-agent](../30-sources/yang-et-al-2024-swe-agent.md) shows that concise
  search feedback and a deliberately sized file view outperform exhaustive or
  poorly sized alternatives.
- [DocPrompting](../30-sources/zhou-et-al-2023-docprompting.md) supports
  signatures and documentation for unfamiliar APIs while documenting the
  cascade from a wrong retrieved API to a wrong argument.

## Trail 4: Keep negative evidence visible

- [RepoQA](../30-sources/liu-et-al-2024-repoqa.md) finds that natural comments
  hurt most tested models on its long-context function-search task, with
  model-specific counterexamples. More explanation is not automatically better
  context.
- [Indirect prompt injection](../30-sources/greshake-et-al-2023-indirect-prompt-injection.md)
  shows why a referenced comment or document must remain untrusted data and
  must never carry action authority.

## Trail 5: Reuse code-intelligence distinctions

- [Language Server Protocol 3.18](../30-sources/microsoft-2026-language-server-protocol.md)
  separates definitions, references, document symbols, workspace symbols,
  source selections, and target ranges as negotiated queries.
- [SCIP](../30-sources/scip-code-2026-code-intelligence-protocol.md) records
  canonical project-relative documents, symbol occurrences and roles,
  signatures, documentation, and navigation relationships in a deterministic
  revision-specific index.

These standards inform an A-Lang-owned data model. Their existing external
implementations do not enter the trusted compiler path; A-Lang’s parser,
resolver, checker, indexer, and materializer must remain BEAM-resident.

## Local A-Lang trail

- The [typed task IR](../src/phase-02/typed-task-ir.md) already provides
  deterministic task and node identities with origins.
- The [context slicer](../src/phase-06/task-orchestration-and-context.md) already
  enforces visibility, provenance, trust, and byte limits and treats retrieved
  text as data only.
- The [task-language map](llm-agent-task-languages.md) connects this question to
  the broader representation and runtime-enforcement thesis.
- The [effectful source fidelity plan](../60-planning/02-effectful-source-fidelity/README.md)
  remains a separate frozen experiment; it does not test symbol-aware context.

## Open questions

- Do authored relations such as `specified_by` or `tested_by` add value beyond
  compiler-derived definitions, references, imports, and calls?
- Are exact targets enough, or do relation and projection labels improve model
  behavior independently?
- Can agents maintain references through renames and moves more reliably than
  they maintain ordinary comments and paths?
- Which symbol identity remains stable enough across revisions without hiding
  stale or materially changed definitions?
- Can selective materialization resist prompt injection without discarding the
  natural-language contracts that make a reference useful?
- Does a generated sidecar win strongly enough that no source syntax is needed?
