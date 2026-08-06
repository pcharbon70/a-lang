---
title: "Can Typed Source References Improve LLM Code Understanding?"
kind: inquiry
created: 2026-08-05
status: open
tags:
  - code-understanding
  - context-engineering
  - llm-agents
  - symbol-identities
aliases:
  - "Do source references help LLMs understand code?"
---

# Can Typed Source References Improve LLM Code Understanding?

## Why this matters

An agent working in a repository must repeatedly answer “what does this depend
on?”, “where is this contract defined?”, and “which evidence should I read
next?” Raw text search and large file dumps can answer these questions, but at
high token cost and with distracting or unsafe content. A language-level
reference could preserve an author’s intent and give a compiler a precise
target to validate.

It could also duplicate facts already available from the compiler, become
stale, or merely add unfamiliar syntax. The language cost is justified only if
typed authored relations outperform a strong generated symbol map under the
same context budget.

## Operational question

On unseen repository revisions, do compiler-resolved, repository-local source
references improve an LLM agent’s grounded answers and verified edits relative
to:

- ordinary comments and paths;
- lexical search;
- a generated symbol-and-definition map; and
- the same navigation tools without authored semantic relations;

while holding model, task, tools, token and byte budgets, decoding, and runtime
enforcement constant?

## Provisional answer

Probably for a narrow class of relationships the compiler cannot infer, such as
`specified_by`, `tested_by`, or `evidence_for`, provided targets resolve
exactly and context is materialized selectively. The current evidence already
supports symbol-aware retrieval, structured navigation, and strict budgets. It
does not establish that the relation must be embedded in source.

The default engineering choice should therefore remain a compiler-generated
index. Source syntax should be promoted only after an equal-budget experiment
shows an additional, repeatable benefit from authored semantic edges.

## Working hypotheses

1. Exact symbol resolution will reduce wrong-file and unsupported-evidence
   answers compared with prose paths.
2. Projection types such as `signature`, `definition`, and `tests` will account
   for more improvement than the surface spelling of a reference.
3. A selective one-hop graph will outperform unconditional recursive expansion.
4. Authored relations will add measurable value mainly for intent that cannot
   be recovered from syntax, types, imports, or calls.
5. Generated maps will match source references on definition-location tasks and
   may win on maintenance cost.
6. Novel relation syntax will initially be harder for an untrained model to
   write than for it to read through a tool-generated summary.
7. Treating all referenced text as untrusted data will preserve the navigation
   benefit without granting instruction or effect authority.

## Paths to explore

- Define a BEAM-resident, revision-bound symbol manifest for current A-Lang
  tasks, nodes, origins, definitions, and occurrences.
- Expose read-only queries for signatures, definitions, references, tests, and
  Markdown sections before changing the source grammar.
- Build an Aider-like generated-map baseline with an identical byte and token
  budget.
- Create held-out questions and edits covering location, contracts,
  architecture, test impact, and multi-hop dependencies.
- Mutate targets through renames, moves, same-named decoys, cycles, and stale
  digests.
- Seed comments and documents with indirect prompt injections and verify that
  referenced content cannot alter actions, limits, visibility, or completion.
- Measure agent authoring and repair of references, not only model consumption.
- Pre-register the corpus, current model families, decoding, repetitions,
  metrics, confidence intervals, and safety veto before hosted evaluation.

This work must be a later experiment. It must not alter the frozen
[effectful source fidelity plan](../60-planning/02-effectful-source-fidelity/README.md)
or interpret that campaign as evidence about repository context.

## Findings

- [Can semantic code graphs improve LLM understanding?](can-semantic-code-graphs-improve-llm-understanding.md)
  continues the inquiry by separating derived topology, semantic relation
  labels, authored claims, graph presentation, and inline source ownership.
- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
  synthesizes the primary research, proposes a non-normative `source_ref`
  model, and defines the controlled comparison.
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
  organizes the benchmarks, retrieval systems, standards, implementation
  precedent, and security evidence.
- Cross-file retrieval improves aggregate completion and repository QA, but
  [Repoformer](../30-sources/wu-et-al-2024-repoformer.md) and
  [RepoGraph](../30-sources/ouyang-et-al-2025-repograph.md) show that irrelevant
  or oversized context can reverse the gain.
- [RepoQA](../30-sources/liu-et-al-2024-repoqa.md) cautions that ordinary
  comments are not consistently helpful, while [indirect prompt
  injection](../30-sources/greshake-et-al-2023-indirect-prompt-injection.md)
  establishes that retrieved comments and documents are an attack surface.
- [LSP](../30-sources/microsoft-2026-language-server-protocol.md),
  [SCIP](../30-sources/scip-code-2026-code-intelligence-protocol.md), and the
  [Aider repository map](../30-sources/aider-2026-repository-map.md) show that
  exact navigation and compact maps can exist without authored inline edges.

## Decision criteria

The provisional promotion gate requires at least a five-point absolute gain on
the pre-registered primary score over both untyped hints and the generated map,
under equal context budgets, with a positive paired stratified-bootstrap 95%
confidence interval in every declared model family. Authority violations,
private-data exposure, or successful indirect prompt injection are vetoes.

If the generated map ties or wins, retain references as tooling metadata. If
only selective graph expansion wins, promote the selector or index rather than
source syntax. If typed authored edges win without a safety regression, plan
the smallest compatible language addition.

## Outcome

The inquiry remains open. Existing work supports typed symbol navigation and
bounded context selection, not source embedding itself. The follow-on semantic
graph inquiry asks whether relationship paths or authored claims add a further
benefit. No A-Lang grammar, schema, compiler, runtime, or API change has been
made, and no hosted model evaluation has been run.
