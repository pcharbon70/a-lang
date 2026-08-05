---
title: "Typed Source References for LLM Code Understanding"
kind: note
created: 2026-08-05
maturity: developing
tags:
  - code-understanding
  - context-engineering
  - llm-agents
  - programming-languages
  - symbol-identities
aliases:
  - "Source references for LLM agents"
---

# Typed Source References for LLM Code Understanding

## Executive conclusion

References can help an LLM agent understand and modify a repository, but the
useful feature is not “more links in the prompt.” The defensible design is a
typed, compiler-resolved relationship whose target can be materialized as a
small, task-specific, provenance-bearing context slice.

The evidence supports four narrower claims:

1. repository tasks often require context outside the active file;
2. symbol and graph structure can improve navigation and task outcomes;
3. relevance, projection, placement, and token budget determine whether added
   context helps or harms; and
4. retrieved source and documentation remain untrusted data, even when the
   repository itself declares the link.

The evidence does **not** yet show that embedding a new reference syntax in
source is better than a compiler-generated symbol index or repository map.
That is the central open question. A-Lang should therefore treat `source_ref`
as a non-normative research design and require a controlled experiment before
promoting it into the language.

## Question, scope, and operational standard

The question is not whether a model can follow a path string. It is whether a
reference facility improves repository-level understanding enough to justify
new language semantics and maintenance cost.

For this inquiry, an agent “understands” code when it can, on an unseen
repository revision:

- locate the definitions and evidence relevant to a question;
- recover API, behavioral, and safety contracts across files;
- explain a dependency or architectural relationship with resolvable evidence;
- predict which tests and consumers a change can affect;
- produce an edit that respects those contracts; and
- abstain or request clarification when a target is stale, ambiguous, absent,
  or outside its authorized scope.

That standard deliberately combines answer correctness, evidence grounding,
edit outcomes, efficiency, and safe failure. Token count alone is not
understanding, and benchmark success without target evidence is not enough.

The scope here is repository-local code symbols, files, tests, contracts, and
Markdown sections. External URLs, package-resolution policy, runtime object
references, and capability delegation are excluded from the first design.

## What the evidence establishes

| Claim | Evidence | Boundary on the claim |
| --- | --- | --- |
| Cross-file context can improve completion. | [CrossCodeEval](../30-sources/ding-et-al-2023-crosscodeeval.md) and [RepoCoder](../30-sources/zhang-et-al-2023-repocoder.md) report substantial aggregate gains from repository retrieval. | Retrieval also turns some correct outputs into failures; neither study tests authored reference syntax. |
| Context should be conditional. | [Repoformer](../30-sources/wu-et-al-2024-repoformer.md) finds that most standard retrievals do not improve output and some are harmful; selective retrieval preserves quality with lower latency. | Its learned labels and primary tasks concern code completion. |
| Bounded structural neighborhoods can guide agents. | [RepoGraph](../30-sources/ouyang-et-al-2025-repograph.md) improves localization and several SWE-bench systems; an oversized two-hop prompt performs worse than the baseline in one key ablation. | The graph is parser-derived and Python-centered; end-to-end gains are often modest. |
| Semantic operations are preferable to undifferentiated file dumps. | [AutoCodeRover](../30-sources/zhang-et-al-2024-autocoderover.md) exposes class signatures, method bodies, and small code windows; [SWE-agent](../30-sources/yang-et-al-2024-swe-agent.md) shows that search summaries and a 100-line viewer outperform exhaustive results and both larger and smaller viewing extremes. | Both systems bundle multiple interface choices and do not isolate symbol IDs. |
| Repository-level understanding needs multi-hop evaluation. | [SWE-QA](../30-sources/peng-et-al-2026-swe-qa.md) shows broad gains from RAG and agent navigation on architecture, intent, location, and dependency questions, at sharply different token costs. | Its main score is LLM-judged and the repositories are static Python snapshots. |
| Signatures and curated docs can connect intent to unfamiliar APIs. | [DocPrompting](../30-sources/zhou-et-al-2023-docprompting.md) improves generation and unseen-function recall by retrieving documentation. | Wrong documentation also supplies wrong arguments; these are short generation tasks. |
| Comments are not a reliable substitute for typed structure. | [RepoQA](../30-sources/liu-et-al-2024-repoqa.md) finds that removing natural comments improves most tested models on its function-search task, with important model-specific exceptions. | The ablation uses synthetic padding and does not establish a general law about comments. |
| Mature protocols separate symbols, occurrences, ranges, definitions, references, and relationships. | [LSP 3.18](../30-sources/microsoft-2026-language-server-protocol.md) provides request-oriented navigation; [SCIP](../30-sources/scip-code-2026-code-intelligence-protocol.md) provides a revision-specific index with symbol roles and relationships. | These are engineering specifications, not evidence that an LLM benefits or that annotations belong in source. |
| A generated compact symbol map is a credible baseline. | [Aider’s repository map](../30-sources/aider-2026-repository-map.md) extracts definitions and references, ranks a file graph, and renders selected definitions to a token budget. | Its documentation and implementation do not provide a controlled map/no-map causal study. |
| Retrieved code can carry hostile instructions. | [Indirect prompt injection](../30-sources/greshake-et-al-2023-indirect-prompt-injection.md) demonstrates that retrieved pages, documents, memory, and source comments can steer LLM applications. | The study is mostly qualitative and its black-box systems have since changed. |

The cross-paper synthesis is therefore asymmetric. There is meaningful support
for symbol-aware selection and concise projections. There is no direct evidence
that the symbol relationship must be authored inline, that more relationship
labels always help, or that a model will interpret a novel A-Lang syntax
reliably without tooling or training.

## A taxonomy of reference mechanisms

Five mechanisms are easy to conflate:

1. **Prose hints** — comments such as “see the validator.” They express intent
   but are ambiguous, unvalidated, and part of the injection surface.
2. **Raw locators** — file paths, line numbers, headings, or URLs. They are
   easy to write but become stale and do not explain the relationship.
3. **Compiler-derived symbol facts** — definitions, uses, imports, call edges,
   type relations, spans, and signatures. These are precise within a revision
   but cannot express every architectural rationale.
4. **Authored semantic relations** — claims such as `tested_by`,
   `specified_by`, or `evidence_for`. These can communicate intent missing from
   syntax, but they require validation and maintenance.
5. **Materialized context** — the actual signature, definition, tests,
   documentation, or local graph supplied to a model. This consumes tokens and
   creates safety exposure; it is a runtime decision, not the reference itself.

The strongest design is a hybrid of the third and fourth mechanisms, with the
fifth kept selective. Compiler facts should not be copied into source as
duplicated assertions. Authors should declare only relations the compiler
cannot infer or a task-specific preference about how a target may be viewed.

## A-Lang already has the right boundary

The current [typed task IR](../src/phase-02/typed-task-ir.md) gives tasks and
nodes deterministic identities and preserves source origins. That is a useful
precedent: identity is compiler-owned and content-addressable views can be
derived without asking authors to maintain line coordinates.

The current [context slicer](../src/phase-06/task-orchestration-and-context.md)
already accepts typed candidates with visibility, provenance, and trust;
enforces fragment and total byte bounds; rejects capability-bearing material;
and labels retrieved text as data rather than instruction authority. A future
reference resolver should produce candidates for that boundary, not bypass it.

This proposal does not modify the accepted language, IR, or runtime. In
particular, it does not change the frozen [effectful source fidelity
experiment](../60-planning/02-effectful-source-fidelity/README.md). That stream
tests whether the existing effectful A-Lang notation preserves task meaning
relative to typed JSON. Source-aware context is a different independent
variable and belongs in a later planning stream.

## Provisional `source_ref` model

The following is an abstract record, **not accepted A-Lang syntax**:

```text
source_ref {
  name:          local stable name
  target:        symbol | file | document_section
  relation:      depends_on | implements | tested_by |
                 specified_by | example_of | evidence_for
  projection:    signature | definition | references | callers |
                 tests | documentation | neighborhood
  visibility:    public | task_local
  max_items:     positive bounded integer
  max_bytes:     positive bounded integer
  max_depth:     zero or one in the initial profile
}
```

The source declaration contains a human-readable locator: a repository-relative
path plus a qualified symbol or heading. The resolver, not the author, produces
the authoritative fields:

- canonical origin and target symbol identities;
- normalized repository-relative target path;
- source and target spans for the current revision;
- target kind and type/signature information;
- repository revision and target content digest;
- resolution diagnostics and candidate alternatives; and
- a manifest digest covering the complete resolved edge.

Line numbers may appear in diagnostics and evidence but are never identities.
An accepted reference resolves to exactly one compatible target. Missing,
ambiguous, out-of-root, type-incompatible, or over-budget references are
compile errors. Stale cached manifests fail digest or revision checks before
materialization.

### Closed relations and projections

The initial relation and projection sets should be closed. Open strings make
spelling variants indistinguishable from extensions and give an agent no stable
contract. Each pair should also be type-checked. For example,
`tested_by` requires a test target and admits `definition` or `tests`, while
`specified_by` can target a contract symbol or Markdown section and admits
`documentation`. `callers` is meaningful for a callable symbol but not for an
arbitrary file.

`depends_on` is intentionally the least informative relation and should not be
generated when the compiler already has an ordinary import or reference edge.
The more specific authored relations are valuable only when they add intent to
derived facts.

### Resolution and materialization

The proposed flow is:

```text
source declaration
        |
        v
BEAM parser and resolver ---> typed diagnostic on failure
        |
        v
revision-bound reference manifest
        |
        v
task-aware selector ---> no retrieval when the edge is irrelevant
        |
        v
bounded projection materializer
        |
        v
Phase 6 data_only context candidate + provenance digest
```

The selector sees the question, declared relation, target kind, projection,
visibility, prior evidence, and remaining budget. It can abstain from retrieval,
choose a smaller projection, or request one additional neighborhood hop. The
materializer returns structured metadata and exact source slices; it does not
return a callable object or permission.

The first implementation, if experimentation warrants one, should derive
A-Lang symbols from the existing BEAM-resident compiler tables. A small
BEAM-native document-section resolver can handle repository Markdown. LSP and
SCIP inform the data model, but requiring their existing foreign indexers would
violate A-Lang’s trusted-toolchain invariant. Precomputed external indexes could
later enter only as untrusted auxiliary evidence and could not satisfy compiler
acceptance.

## Reading and writing references as an agent

An agent should not have to invent canonical IDs. The authoring interface can
support a narrow loop:

1. query symbols or document sections by a human-readable name;
2. select one typed candidate;
3. emit the intended relation, projection, and small bound;
4. compile and receive exact ambiguity or compatibility diagnostics; and
5. use a rename/refactor operation that updates incoming locators atomically.

For reading, the model should first see a compact edge summary, for example
“`submit` is `specified_by` contract `NoDuplicateCharge`; signature and 640
bytes available.” It receives the target only after selection. For writing, the
compiler should reject fabricated targets and show candidates without silently
retargeting. This makes references easier for agents to produce while keeping
semantic authority outside probabilistic text generation.

## Safety and integrity requirements

A reference is a data edge, never an import, call, grant, or instruction.
Minimum invariants are:

- targets remain under the canonical repository root and cannot escape through
  `..` components or symlinks;
- visibility is checked before content is read, not after prompt construction;
- referenced text is always marked `data_only` and cannot modify the action
  set, policy, limits, or completion criteria;
- manifests and materialized slices carry revision and content digests;
- no reference contains a process identifier, port, broker state, credential,
  capability handle, or callable term;
- transitive expansion is opt-in, depth-bounded, cycle-checked, and subject to
  cumulative item and byte limits;
- agent answers cite the evidence identity and distinguish an authored claim
  from a compiler-derived fact; and
- adversarial comments, docstrings, fixtures, and Markdown are included in the
  test corpus.

These constraints do not solve prompt injection. They reduce ambient authority
and make the retrieved material observable and attributable. The runtime still
needs deterministic enforcement around every consequential action.

## Failure modes and design responses

| Failure | Required response |
| --- | --- |
| Renamed or deleted target | Fail resolution; offer candidates; never follow a nearby name silently. |
| Ambiguous overload or same-named symbol | Require a typed signature or explicit candidate choice. |
| Cyclic authored relations | Preserve the graph but reject recursive materialization beyond the declared bound. |
| High-fan-out target | Return a count and ranked summary; require a narrower query before source text. |
| Wrong authored relation | Surface it as an authored claim and compare it with compiler facts and tests; do not promote it to fact. |
| Stale generated index | Reject revision or digest mismatch and rebuild with the BEAM-resident resolver. |
| Prompt injection in target | Render as untrusted evidence, with no authority-bearing data in the same channel. |
| Irrelevant but valid edge | Let the selector abstain; validity does not imply prompt relevance. |
| Agent fabricates a target | Compiler error with bounded symbol candidates; no fuzzy auto-acceptance. |
| Reference burden exceeds benefit | Prefer the generated sidecar map and omit the language feature. |

## Evaluation plan

This requires a new pre-registered experiment, separate from the active
fidelity campaign. No hosted model calls were made for this research note.

### Conditions

Hold task semantics, repository revision, model, decoding, tools, context
window, maximum retrieved bytes, and wall-clock limits constant. Compare:

1. **Lexical baseline:** repository tree plus the existing text-search tools.
2. **Untyped hint:** equivalent paths and prose relations in ordinary comments.
3. **Generated map:** compiler- or parser-derived symbols and definition lines,
   ranked to the same budget in the style of Aider.
4. **Typed references:** resolved authored relations with one bounded
   projection and no graph expansion.
5. **Typed references plus selective graph:** the same references with a
   query-time decision to abstain or expand a one-hop neighborhood.

The generated map is the decisive baseline. Comparing only against no context
would confound a general navigation benefit with the value of source embedding.

### Task suite

Use held-out revisions and stratify at least 200 tasks across:

- definition and contract location;
- cross-file behavioral explanation;
- test and consumer impact analysis;
- multi-hop architecture questions;
- repository edits with executable verification;
- unfamiliar API use from local documentation;
- stale, ambiguous, cyclic, and high-fan-out references; and
- malicious instructions hidden in code comments, docstrings, fixtures, and
  documentation targets.

Include both A-Lang-native repositories, where the compiler supplies exact
gold symbols, and established repository-level benchmark tasks. Mutation-based
cases should rename targets, move definitions, add a same-named decoy, or make
an authored relation false while preserving syntax.

### Metrics and decision rule

Primary metrics are:

- task correctness or verified edit success;
- exact target and relationship evidence precision/recall;
- unsupported-claim and wrong-file rates; and
- safe handling of untrusted or unauthorized targets.

Secondary metrics are input and output tokens, retrieved bytes, number of
navigation calls, latency, cost, ambiguity rate, stale-reference diagnostics,
and agent-authored reference validity after edits.

The provisional promotion gate is intentionally demanding: under an equal
context budget, typed references must improve the pre-registered primary score
by at least five absolute percentage points over both the untyped-hint and
generated-map conditions, with a positive paired stratified-bootstrap 95%
confidence interval in each declared model family. They must not increase
authority violations, private-data exposure, or successful indirect prompt
injection. If only the graph-enabled condition wins, promote the selector or
index—not necessarily source syntax.

### Falsification criteria

Do not add `source_ref` to the language if any of these durable results holds:

- a generated symbol map matches or beats it under the same budget;
- gains disappear when extra tokens are equalized;
- relation labels are ignored or systematically misread across model families;
- stale or ambiguous annotations create more wrong evidence than they prevent;
- agents cannot maintain valid references through ordinary renames and moves;
- source references increase prompt-injection or visibility failures; or
- authoring and review cost outweigh verified task improvement.

## Design position

The near-term recommendation is to build the **index and experiment before the
syntax**. Extend the research model around compiler-owned symbol identity,
typed relations, projections, provenance, and selection. Use it first as a
generated sidecar so the resolver and evaluation can mature without expanding
the language. Add source-level declarations only if authored semantic edges
produce a repeatable advantage that derivation cannot supply.

This preserves a useful distinction: source code can state intentional
relationships, but the compiler decides what they resolve to, and the runtime
decides whether their contents belong in the current model context.

## Research priorities

1. Define a revision-bound symbol manifest for current A-Lang tasks and nodes.
2. Build a BEAM-native query interface for definition, signature, references,
   tests, and Markdown sections without changing accepted source syntax.
3. Construct the equal-budget generated-map baseline and adversarial corpus.
4. Measure whether relation labels add value beyond exact targets and
   projections.
5. Only then prototype the smallest authored declaration and test whether
   agents can create and repair it reliably.

## Source route

- Start with [CrossCodeEval](../30-sources/ding-et-al-2023-crosscodeeval.md),
  [RepoCoder](../30-sources/zhang-et-al-2023-repocoder.md), and
  [Repoformer](../30-sources/wu-et-al-2024-repoformer.md) for the benefit and
  cost of cross-file retrieval.
- Continue through [RepoGraph](../30-sources/ouyang-et-al-2025-repograph.md),
  [AutoCodeRover](../30-sources/zhang-et-al-2024-autocoderover.md), and
  [SWE-agent](../30-sources/yang-et-al-2024-swe-agent.md) for graph and
  interface design.
- Use [RepoQA](../30-sources/liu-et-al-2024-repoqa.md) and
  [SWE-QA](../30-sources/peng-et-al-2026-swe-qa.md) to operationalize code
  understanding and preserve negative evidence about indiscriminate comments.
- Use [DocPrompting](../30-sources/zhou-et-al-2023-docprompting.md) for
  documentation projections, [LSP](../30-sources/microsoft-2026-language-server-protocol.md)
  and [SCIP](../30-sources/scip-code-2026-code-intelligence-protocol.md) for
  navigation data models, and [Aider](../30-sources/aider-2026-repository-map.md)
  for the generated-map baseline.
- Treat [indirect prompt injection](../30-sources/greshake-et-al-2023-indirect-prompt-injection.md)
  as a mandatory boundary condition, not an optional follow-up.

## Connections

- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
  keeps the untested comparison open.
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
  provides the shortest route through the evidence.
- [Task languages for LLM agents: a deep dive](llm-agent-task-languages-deep-dive.md)
  supplies the broader task-language and runtime-enforcement context.
