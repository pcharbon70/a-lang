---
title: "Semantic Code Graphs for LLM Understanding"
kind: note
created: 2026-08-06
maturity: developing
tags:
  - code-graphs
  - code-understanding
  - knowledge-graphs
  - llm-agents
  - programming-languages
aliases:
  - "Semantic knowledge graphs for agent-readable code"
---

# Semantic Code Graphs for LLM Understanding

## Executive conclusion

A graph can give an LLM agent a better picture of a repository, but the useful
feature is usually **queryable relationships**, not a larger textual picture.
Derived control flow, data flow, calls, uses, containment, types, tests, and
symbol identities can improve learned code models and repository retrieval.
The evidence also shows that oversized neighborhoods and graph-as-text
renderings can erase or reverse those gains.

A semantic knowledge graph is a plausible second layer. It can represent the
intent that program analysis cannot derive: what specifies a component, which
invariant it is meant to preserve, why a design choice exists, which test is
evidence for a contract, and what supersedes an old decision. Direct evidence
that this authored layer improves LLM repository work is still weak. Existing
semantic software graphs establish feasibility and useful queries, not a causal
advantage over a generated code graph under equal information and context
budgets.

The defensible A-Lang direction is therefore:

1. build a deterministic, BEAM-native graph from compiler-owned facts;
2. expose bounded, typed graph queries and compact evidence projections;
3. add authored semantic edges in an experimental manifest, where each edge is
   explicitly a claim with provenance and revision state;
4. measure whether those claims add value beyond the derived graph; and
5. only then consider the smallest source-level relation declaration.

“Embedded in code” should mean that the source owns a small number of
non-inferable claims near the symbol they describe. It should not mean copying
the complete graph into source, serializing every triple into the model prompt,
or allowing semantic inference to change runtime effects or authority.

## Question, scope, and operational standard

This continuation asks three related but separable questions:

1. Does graph topology and traversal improve repository understanding beyond a
   flat symbol map?
2. Do semantic relation types and authored intent improve it beyond a derived
   program graph?
3. Does storing those authored relations in source improve agent reading,
   writing, and maintenance beyond an equivalent sidecar manifest?

For this inquiry, an agent understands a repository when it can, on an unseen
revision:

- locate the exact symbols, paths, and evidence relevant to a question;
- explain control, data, call, dependency, contract, and rationale paths without
  inventing intermediate edges;
- distinguish compiler facts, human claims, model inferences, and observed test
  evidence;
- predict affected consumers, tests, effects, and constraints;
- make a verified edit that preserves the relevant contracts; and
- reject, qualify, or repair stale, ambiguous, contradictory, unauthorized, or
  adversarial graph content.

The first experiment is about static repository knowledge. Runtime object
graphs, graph-mutating application logic, semantic reflection, remote linked
data, and capability delegation are out of scope.

## “Semantic graph” names several different things

The word *semantic* is overloaded in this literature. Data flow is often called
semantic because it approximates value dependence rather than surface syntax.
An ontology is semantic because predicates and classes have declared meanings
and may support inference. A design note is semantic because it records human
intent. These are not interchangeable.

| Layer | Typical contents | Authority | Primary use |
| --- | --- | --- | --- |
| Symbol index | Definitions, occurrences, spans, signatures | Compiler-derived fact within one revision | Exact navigation |
| Program graph | Calls, imports, containment, control flow, data flow, types, effects | Static-analysis result with declared precision | Impact, slicing, and path queries |
| Software knowledge graph | Code nodes plus tests, documents, issues, decisions, concepts, and history | Mixed facts and extracted claims | Cross-artifact discovery and explanation |
| Authored semantic graph | `specified_by`, `implements`, `tested_by`, `invariant_of`, `rationale_for`, `supersedes` | Human- or agent-authored claim | Non-inferable intent |
| Retrieval graph | Relevance scores, query traces, summaries, suspected impact | Ephemeral model or tool output | Context selection for one task |

A code graph becomes a useful *knowledge graph* here when its nodes identify
entities across code and other artifacts, its predicates have declared domain
and range, and its assertions retain provenance and validation state. Optional
inference can follow only explicitly defined relation rules. This operational
definition does not require RDF or OWL, and it does not imply that every edge is
true.

Conflating these layers creates false authority. A call edge resolved by the
compiler is not epistemically equivalent to an LLM-extracted claim that a class
implements a business rule. A test link is evidence of an intended relationship,
not proof that the test is complete or currently passing. A model-selected
`relevant_to` edge should not become repository truth merely because it helped
one answer.

## Five independent variables

“Graph versus no graph” is too coarse to support a language decision. At least
five variables can cause the observed result:

1. **Information content:** a graph condition may simply contain facts the
   baseline never receives.
2. **Topology and query operations:** path, neighborhood, direction, and impact
   queries may select better facts before prompting.
3. **Relation semantics:** labels such as `calls` or `specified_by` may help a
   model interpret otherwise identical endpoints.
4. **Presentation:** a graph may be consumed through trained representations,
   a tool, a compact edge table, prose, or a full textual serialization.
5. **Ownership and placement:** a relation may be compiler-derived, written in
   source, stored in a manifest, or extracted by an LLM.

Several reported graph ablations remove edges entirely. They demonstrate that
the complete system uses those edges; they do not prove that topology beats a
flat representation containing the same facts. Likewise, a graph-aware trained
model does not prove that an unmodified hosted model can interpret a novel
A-Lang relation syntax.

## What the evidence supports

| Claim | Evidence | Boundary on the claim |
| --- | --- | --- |
| Unified program graphs support cross-property queries. | [Code property graphs](../30-sources/yamaguchi-et-al-2014-code-property-graphs.md) combine syntax, control, and dependence information and find real kernel vulnerabilities. | This is static program analysis, not an LLM study; intended design remains missing. |
| Derived graph relations can improve trained code representations. | [GraphCodeBERT](../30-sources/guo-et-al-2021-graphcodebert.md) gains from data flow and relation-aware objectives; [GREAT](../30-sources/hellendoorn-et-al-2020-global-relational-models.md) improves variable-misuse repair with relational hybrids. | The benefit depends on training and architecture, and real-bug results are much lower than synthetic results. |
| A learned bridge can exploit graphs better than plain graph text. | [CGBridge](../30-sources/chen-et-al-2026-cgbridge.md) improves several semantic and functional measures with a learned soft prefix, while its GraphText baseline is often harmful. | It adds training and a substantial module; it is not available to an unmodified hosted model. |
| Program graphs can improve retrieval for black-box LLMs. | [GraphCoder](../30-sources/liu-et-al-2024-graphcoder.md) uses bounded control/data slices for completion; [RepoGraph](../30-sources/ouyang-et-al-2025-repograph.md) improves localization and repair systems; [CodexGraph](../30-sources/liu-et-al-2025-codexgraph.md) lets agents formulate graph queries. | Systems bundle indexing, ranking, query agents, and extra tokens. Edge-removal ablations are not equal-information comparisons. |
| More graph is not automatically more understanding. | RepoGraph’s two-hop rendering falls below its baseline; [Talk Like a Graph](../30-sources/fatemi-et-al-2024-talk-like-a-graph.md) shows large effects from encoding, wording, topology, omissions, and distractors. | The latter uses synthetic non-code graphs, so it is a representation warning rather than code-task evidence. |
| A formal semantic code ontology is feasible at scale. | [CodeOntology](../30-sources/atzeni-atzori-2017-codeontology.md) emits millions of RDF triples and supports expressive source queries. | It evaluates extraction and example queries, not human or LLM understanding. |
| A living semantic software graph can retain intent-like history. | [CODENS](../30-sources/kelious-et-al-2026-codens.md) incrementally stores purpose, behavior, provenance, and typed relations from pull requests and answers repository questions. | Its 11-question, one-repository evaluation has no retrieval-mode control and no semantic-truth audit. |
| Graph hierarchies can support global synthesis. | [GraphRAG](../30-sources/edge-et-al-2024-graphrag.md) outperforms vector RAG on global comprehensiveness and diversity with compact community summaries. | Its second evaluation does not distinguish graph search from a strong graph-free global summary; it is not about code. |
| Embedding a runtime knowledge graph in a language is possible but semantically consequential. | [Semantically Reflected Programs](../30-sources/kamburjan-et-al-2026-semantically-reflected-programs.md) formalizes graph lifting, typed queries, virtualization, and source controls in SMOL. | Runtime reflection affects typing, consistency, performance, and object lifetime and does not test LLMs. |

The cross-paper conclusion is asymmetric. There is meaningful evidence for a
compact derived graph and a query layer. There is suggestive engineering
evidence for semantic software graphs. There is no controlled evidence yet that
authored semantic triples improve an LLM agent over the same derived graph, or
that inline placement is better than a revision-bound manifest.

## The graph should be an index, not the prompt

A graph can improve a model before the model sees any graph syntax. Its query
engine can use topology to select a definition, compute a backward slice, find
all callers of a changed effect, or follow a contract-to-test path. The model
then receives a small typed result with exact evidence.

This distinction explains otherwise conflicting findings:

```text
repository facts
      |
      v
typed graph --------> bounded query and ranking
      |                         |
      |                         v
      |                compact evidence projection
      |                         |
      +-- full serialization --+--> LLM
              risky
```

GraphCoder, RepoGraph, and CodexGraph use topology in selection or navigation.
CGBridge uses a learned representation. Talk Like a Graph and CGBridge show
that translating topology into ordinary tokens is lossy and task-sensitive.
The first A-Lang graph therefore belongs behind read-only tools. A full edge
dump should be an adversarial baseline, not the default interface.

## A layered A-Lang graph

The graph should preserve where each statement of relationship came from. A
single undifferentiated triple store would obscure that distinction.

### Layer 0: identities and occurrences

The compiler owns canonical identities for modules, tasks, nodes, types,
effects, contracts, definitions, and occurrences. Each identity is scoped to a
repository revision and resolves to source spans and content digests. Paths and
line numbers are locators and evidence, not identities.

This extends the direction already present in the [typed task
IR](../src/phase-02/typed-task-ir.md), which provides deterministic identities
and origins.

### Layer 1: derived program facts

The parser, resolver, checker, and IR passes generate facts such as:

- `contains`, `defines`, `references`, `imports`, and `calls`;
- `reads`, `writes`, `flows_to`, `controls`, and `may_reach`;
- `has_type`, `requires_effect`, `handles_effect`, and `produces`;
- `implements_contract` only where the language already makes that fact
  checkable; and
- test discovery and coverage relations only to the precision the tool can
  substantiate.

These facts should carry the analysis that produced them and its declared
precision. A conservative `may_call` edge must not be rendered as a definite
runtime call.

### Layer 2: authored semantic claims

Authors and agents declare only relationships that derivation cannot recover.
An initial closed vocabulary could include:

- `specified_by` and `implements` for a contract or design target;
- `tested_by` and `evidence_for` for supporting artifacts;
- `invariant_of` for an intended constraint;
- `rationale_for` and `explains` for a design decision or document section;
- `example_of` for a canonical usage; and
- `supersedes` for lifecycle history.

`depends_on` should be discouraged when a more precise compiler fact or
relation exists. Every predicate needs allowed subject and object kinds,
direction, cardinality where meaningful, and explicit rules for inverse or
transitive queries. Most semantic predicates are not safely transitive.

### Layer 3: provenance and validation

Every edge needs more than three fields. The following is an abstract record,
not accepted A-Lang syntax:

```text
graph_edge {
  subject:       canonical_symbol_id
  predicate:     closed_relation
  object:        symbol | contract | test | document_section | decision
  origin:        compiler | authored | imported | inferred | observed
  assertion_id:  stable_edge_identity
  asserted_by:   compiler_pass | author_identity | agent_run
  source_span:   optional_source_location
  revision:      repository_revision
  object_digest: resolved_target_digest
  status:        derived | claimed | checked | contradicted | stale
  evidence:      bounded_list<evidence_identity>
  visibility:    repository | task_local | restricted
}
```

`status` is not a probability. A schema-valid authored edge is still a claim.
Tests, proofs, or compiler checks can upgrade a precisely defined property, but
they should not silently turn a broad design statement into truth. Conflicting
claims should remain inspectable and produce diagnostics rather than allowing a
global reasoner to make every conclusion available.

### Layer 4: ephemeral retrieval facts

Edges such as `relevant_to`, `suspected_impact`, `retrieved_for`, or
`summarized_as` belong to a task trace. They can explain why context was chosen,
but they expire with the task and cannot modify repository knowledge without a
separate reviewed action.

## What should actually be embedded in source?

The graph itself should not be embedded. Only locally owned semantic claims
that cannot be reconstructed should be candidates for source syntax.

An abstract declaration might communicate:

```text
relation {
  predicate: specified_by
  target: contract NoDuplicateCharge
  projection: summary
}

relation {
  predicate: tested_by
  target: test RejectDuplicateSubmission
  projection: definition
}
```

This is deliberately not a proposed grammar. The compiler would resolve the
human-readable target, attach the containing subject symbol, validate the
predicate’s domain and range, and emit the complete graph records. Authors
would never write canonical IDs, digests, source spans, revision hashes,
inverse edges, or redundant compiler facts.

The placement rule should be:

- put a claim inline when one local definition owns it and a rename/refactor
  should update it atomically;
- keep repository-wide decisions, cross-repository evidence, issue history,
  and generated relations in a manifest or linked archive document; and
- compile both forms to the same graph so presentation and semantics remain
  independent experimental variables.

This hybrid preserves the advantage of proximity without turning each function
into a miniature ontology. It also makes the generated manifest the stable API
for tools and agents; source spelling remains an authoring interface.

## Query interface for agents

The first useful surface is a small set of deterministic read-only operations:

- `definition(id)` and `references(id)` for exact navigation;
- `neighbors(id, relations, direction, depth, budget)` for bounded local views;
- `path(from, to, relations, max_depth)` for a witnessed relationship path;
- `impact(id, relation_profile, budget)` for potential consumers, effects, and
  tests;
- `evidence(edge_id)` for the source, test, document, or analysis behind a
  relationship;
- `explain_edge(edge_id)` for origin, status, revision, and precision; and
- `conflicts(id)` for stale, contradictory, unresolved, or incompatible claims.

Every result is ordered deterministically and reports omitted counts when a
budget truncates it. Direction and edge types are explicit. Depth defaults to
one, cycles are detected, and cumulative nodes, edges, bytes, and source slices
are bounded.

The tool returns graph structure first and source text only on request. For
example, an agent might receive “`submit` is `specified_by`
`NoDuplicateCharge`; checked target, 620-byte contract projection available.”
That is more economical and auditable than automatically pasting the contract,
all its tests, and all callers.

## Compiler and trust boundary

The implementation must preserve A-Lang’s whole-toolchain BEAM invariant:

```text
A-Lang source + archive documents
             |
             v
BEAM parser / resolver / checker
             |
             +--> compiler-derived edge extractor
             +--> authored-claim resolver
                         |
                         v
              revision-bound graph manifest
                         |
                         v
              BEAM validator and query layer
                         |
                         v
            bounded selector and materializer
                         |
                         v
              Phase 6 data_only context
```

RDF, OWL, property graphs, Cypher, and SPARQL are useful design references and
possible export formats. A-Lang does not need to adopt their complete semantics
or require Neo4j, Jena, a foreign indexer, or another executable in the trusted
compiler path. Any later external graph database would be an optional,
untrusted cache whose results are checked against the BEAM-generated manifest.

The graph cannot grant capabilities, add effects, change completion criteria,
or make retrieved text authoritative. Runtime semantic reflection is a separate
language feature with much larger consequences, as the SMOL work demonstrates;
it should not enter this research path.

## Integrity, security, and maintenance requirements

A semantic graph makes intentional relationships easier to query, but also
makes a false relationship easier to amplify. Minimum invariants are:

- resolve targets exactly within the canonical repository root;
- reject missing, ambiguous, wrong-kind, out-of-root, and digest-mismatched
  targets;
- distinguish open-world claims from the compiler’s closed, revision-scoped
  inventory—absence of an authored claim does not mean the relationship is
  false;
- apply visibility before traversal or source materialization;
- label code, comments, tests, and documents as untrusted `data_only` content;
- keep relation inference on a predicate whitelist with explicit direction and
  depth;
- report fan-out and truncation instead of silently dropping inconvenient
  neighbors;
- preserve old assertion identity and mark it stale when a target changes
  materially;
- surface contradictions between claims, types, tests, and compiler facts;
- prevent task-local relevance edges and model-generated summaries from
  entering durable graph state without review; and
- make graph reconstruction deterministic and incremental from repository
  inputs.

These controls extend the [context slicer](../src/phase-06/task-orchestration-and-context.md),
which already enforces provenance, visibility, trust, and byte bounds. They do
not eliminate indirect prompt injection; they keep retrieved evidence from
acquiring action authority.

## Evaluation: isolate what the graph adds

No hosted evaluation was performed for this note. A later experiment should be
pre-registered and remain separate from the frozen [effectful source fidelity
plan](../60-planning/02-effectful-source-fidelity/README.md).

### Factorial conditions

Hold model, repository revision, task wording, decoding, tools, context window,
retrieved bytes, wall-clock budget, and runtime policy constant. Compare:

1. **Lexical baseline:** tree, text search, and ordinary file views.
2. **Generated flat map:** identities, signatures, and definition locations
   ranked to the same budget.
3. **Derived edge table:** the same revision’s compiler facts exposed as a
   compact, typed but non-traversing lookup.
4. **Derived graph queries:** the same fact set with bounded neighborhood,
   path, impact, and evidence operations.
5. **Derived graph plus authored semantics:** verified non-inferable claims and
   their provenance.
6. **Inline versus sidecar authoring:** identical compiled graph records, with
   only placement and maintenance workflow changed.
7. **Full graph text:** a deliberately equal-budget serialization baseline to
   test whether direct prompting loses the query-layer benefit.

The edge-table and graph-query conditions test whether topology-aware operations
improve selection when underlying facts are equal. The authored condition tests
new semantic information. The placement condition is the only one that can
justify source syntax.

### Required ablations

- replace relation names with stable opaque identifiers;
- shuffle labels while preserving endpoints;
- reverse directional edges;
- remove one derived edge family at a time;
- vary zero-, one-, and two-hop expansion under the same byte budget;
- inject plausible but false authored relations;
- rename or move targets and replay a stale manifest;
- introduce same-named decoy symbols and incompatible target kinds;
- reorder an otherwise identical textual graph;
- remove provenance while holding facts fixed; and
- compare compact query results with a complete graph dump.

Opaque labels test whether natural-language predicate meaning matters. Shuffled,
reversed, stale, and false edges test whether the model follows graph evidence
or merely benefits from more nearby code. Provenance removal tests whether
agents use epistemic distinctions or ignore them.

### Task suite

Stratify held-out tasks across:

- definition, type, contract, and rationale location;
- control- and data-flow explanation;
- call, effect, test, and consumer impact analysis;
- multi-hop architecture and lifecycle questions;
- repository edits with executable verification;
- contradictory, ambiguous, stale, and high-fan-out relationships;
- agent-authored and agent-repaired semantic edges; and
- malicious instructions in comments, documents, tests, edge descriptions, and
  imported metadata.

A-Lang-native cases can use compiler identities and executed tests as precise
oracles. Established repository tasks provide a realism check and prevent an
evaluation from rewarding only the graph schema it was built around.

### Metrics and promotion ladder

Primary measures are verified task or edit success, exact node-and-path evidence
precision and recall, unsupported-edge rate, and safe rejection of unauthorized
or adversarial material. Secondary measures include tokens, bytes, navigation
calls, latency, index-build and incremental-update time, graph size, truncation,
stale diagnostics, and valid agent-authored relations after renames and moves.

Promotion should happen one layer at a time:

1. Promote the derived query layer if it beats the flat map under equal facts
   and budgets.
2. Promote semantic claims if true authored edges add a repeatable gain without
   increasing false-evidence or security failures.
3. Promote source syntax only if inline ownership improves agent authoring,
   review, and maintenance over an equivalent sidecar graph.
4. Treat a win that requires graph-aware model training as a model-integration
   result, not evidence for a language feature.

The previous inquiry’s five-point absolute improvement gate remains a useful
starting threshold, with a positive paired stratified-bootstrap 95% confidence
interval in each declared model family and safety violations as vetoes.

## Falsification criteria

Do not add a semantic graph layer if a flat generated map matches it under
equal information and budgets, graph benefits disappear after token
equalization, or false and stale edges create more unsupported answers than the
graph prevents.

Do not add authored semantics if relation labels are ignored, compiler facts
and tests recover the same value, authors and agents cannot keep claims valid,
or provenance states are not respected.

Do not add inline syntax if an equivalent sidecar is easier to generate,
review, refactor, and validate. Do not add runtime semantic reflection merely
because static graph queries help an LLM.

## Design position

Build the **derived graph and query experiment before the semantic ontology,
and the semantic ontology before source syntax**.

The near-term research artifact should be a BEAM-native, revision-bound graph
manifest with compiler facts, edge provenance, deterministic bounded queries,
and Phase 6 context projections. Seed a separate experimental claim file with a
small closed vocabulary for non-inferable intent. If that layer wins, compile
the same claims from a minimal source declaration and measure agent maintenance.

This sequence preserves the central distinction: the graph can help an agent
see relationships without making source code a database, and source can own
intent without pretending that every authored or LLM-extracted relationship is
a verified program fact.

## Research priorities

1. Specify canonical graph node and edge identities on top of the current typed
   task IR.
2. Generate containment, reference, call, type, effect, and task data-flow edges
   in BEAM without changing source syntax.
3. Implement `neighbors`, `path`, `impact`, `evidence`, and `conflicts` with
   strict relation, depth, count, byte, visibility, and cycle bounds.
4. Build equal-fact flat-map, edge-table, graph-query, and graph-text baselines.
5. Define the smallest authored vocabulary and truth/provenance state machine.
6. Construct false-edge, stale-edge, topology, serialization, and prompt-
   injection ablations.
7. Evaluate whether semantic claims add value; only then test source placement.

## Source route

- Start with [code property graphs](../30-sources/yamaguchi-et-al-2014-code-property-graphs.md),
  [GraphCodeBERT](../30-sources/guo-et-al-2021-graphcodebert.md), and
  [GREAT](../30-sources/hellendoorn-et-al-2020-global-relational-models.md) for
  derived structure and trained representations.
- Continue through [GraphCoder](../30-sources/liu-et-al-2024-graphcoder.md),
  [RepoGraph](../30-sources/ouyang-et-al-2025-repograph.md), and
  [CodexGraph](../30-sources/liu-et-al-2025-codexgraph.md) for repository
  selection and query interfaces.
- Use [CGBridge](../30-sources/chen-et-al-2026-cgbridge.md) and
  [Talk Like a Graph](../30-sources/fatemi-et-al-2024-talk-like-a-graph.md) to
  keep graph serialization and model-integration effects explicit.
- Use [CodeOntology](../30-sources/atzeni-atzori-2017-codeontology.md),
  [CODENS](../30-sources/kelious-et-al-2026-codens.md), and
  [GraphRAG](../30-sources/edge-et-al-2024-graphrag.md) for ontology, living
  documentation, provenance, and multi-scale semantic retrieval.
- Read [Semantically Reflected Programs](../30-sources/kamburjan-et-al-2026-semantically-reflected-programs.md)
  as the boundary between a static agent context index and a graph that changes
  language runtime semantics.

## Connections

- [Typed source references for LLM code understanding](typed-source-references-for-llm-code-understanding.md)
  establishes the preceding symbol, projection, provenance, and generated-map
  baseline.
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
  keeps the graph, semantic-layer, and source-placement decisions open.
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
  is the shortest route through this evidence.
