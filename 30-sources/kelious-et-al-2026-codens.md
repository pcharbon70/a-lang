---
title: "CODENS: Transforming Code Changes into Living, Accessible, and Queryable Documentation"
kind: source
created: 2026-08-06
authors:
  - "Abdelhak Kelious"
  - "Chyrine Tahri"
  - "Eliot Bardet"
published: 2026
citation_key: "kelious-et-al-2026-codens"
container: "Proceedings of the 2026 ACM Symposium on Document Engineering"
edition: null
isbn: "979-8-4007-2786-3"
doi: "10.1145/3820755.3832807"
url: "https://arxiv.org/abs/2607.18356"
accessed: 2026-08-06
tags:
  - code-documentation
  - knowledge-graphs
  - repository-level-code
  - software-evolution
aliases:
  - "CODENS"
---

# CODENS: Transforming Code Changes into Living, Accessible, and Queryable Documentation

## Reference

Abdelhak Kelious, Chyrine Tahri, and Eliot Bardet. “CODENS: Transforming Code
Changes into Living, Accessible, and Queryable Documentation.” *DocEng 2026*.
[DOI](https://doi.org/10.1145/3820755.3832807).

## Method

CODENS scans a Ruby on Rails repository into typed component nodes and replays
pull requests chronologically. For each change, GPT-4 receives the diff, the
node’s prior semantic state, and a component schema; it returns validated JSON
updates for purpose, behavioral flow, business logic, and relationships. Scalar
history and PR provenance are retained. Schema fields and source-code regexes
produce typed graph edges.

The resulting Neo4j graph contains 1,739 nodes and 622 edges across 11 relation
types. It supports vector retrieval, automatic one- or two-hop expansion, and a
ReAct agent with node, neighbor, relation, and Cypher tools.

## Findings

- The paper evaluates only the agent mode on 11 anonymized questions from one
  confidential production repository, with the project’s lead developer as
  reviewer. Mean human scores are 4.09/5 for relevance, 4.45 for completeness,
  and 4.91 for document relevance.
- Per-question token use ranges from 13,609 to 64,419. The reviewer repeatedly
  asks for shorter, less code-centric, more synthesized answers.
- The authors explicitly characterize the evaluation as exploratory and leave
  comparative benchmarking across retrieval modes and projects to future work.

## Relevance

CODENS is the closest evaluated example in this source set to a living semantic
software knowledge graph. It shows how intent-like attributes, evolution
history, typed relations, provenance, and graph tools can coexist. It also
illustrates why semantic claims need a truth status: schema-valid extraction
and faithful answers to the graph do not establish that the graph accurately
describes the code.

## Limits

There is no vector-versus-graph-versus-agent comparison, no audit of extracted
semantic truth, and no counterfactual removal of relationship labels. The study
uses one framework-specific repository, 11 questions, one evaluator, and an
LLM-generated graph. Automatic faithfulness measures grounding in retrieved
graph text, not correspondence between that text and program behavior. The
graph is external rather than embedded in source.

## Derived notes

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
