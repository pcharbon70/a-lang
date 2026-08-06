---
title: "Modeling and Discovering Vulnerabilities with Code Property Graphs"
kind: source
created: 2026-08-06
authors:
  - "Fabian Yamaguchi"
  - "Nico Golde"
  - "Daniel Arp"
  - "Konrad Rieck"
published: 2014
citation_key: "yamaguchi-et-al-2014-code-property-graphs"
container: "2014 IEEE Symposium on Security and Privacy"
edition: null
isbn: null
doi: "10.1109/SP.2014.44"
url: "https://ieeexplore.ieee.org/document/6956589"
accessed: 2026-08-06
tags:
  - code-graphs
  - program-analysis
  - software-security
aliases:
  - "Code property graphs"
---

# Modeling and Discovering Vulnerabilities with Code Property Graphs

## Reference

Fabian Yamaguchi, Nico Golde, Daniel Arp, and Konrad Rieck. “Modeling and
Discovering Vulnerabilities with Code Property Graphs.” *2014 IEEE Symposium
on Security and Privacy*, 590–604.
[DOI](https://doi.org/10.1109/SP.2014.44).

## Method

The paper defines a property graph as a directed, edge-labeled, attributed
multigraph and introduces a code property graph that overlays three established
program representations: abstract syntax trees, control-flow graphs, and
program-dependence graphs. Analysts express vulnerability patterns as graph
traversals that can cross syntax, execution order, and data dependencies in one
query.

The prototype parses C and C++, links function graphs by visible caller-callee
relations, and stores the result in Neo4j. The authors model vulnerability
classes found in Linux kernel reports and then search Linux 3.10-rc1 for new
instances.

## Findings

- The combined representation can model 10 of 12 vulnerability classes in the
  authors’ 2012 kernel sample. Race conditions depend on runtime behavior, and
  design errors require intended behavior that the derived graph does not know.
- The kernel graph contains about 52 million nodes and 87 million edges for
  roughly 1.3 million lines of code. Importing and indexing it took 110 minutes
  and 28 GB on the reported laptop configuration.
- The traversals found 18 previously unknown kernel vulnerabilities that the
  paper reports as confirmed and fixed by the vendor.

## Relevance

This is foundational evidence for treating a code graph as a queryable overlay,
not as a textual replacement for source. Its most useful boundary for A-Lang is
the design-error result: syntax, control, and data flow recover many precise
facts, but they do not recover author intent. Authored semantic relations could
fill that narrower gap without duplicating compiler-derived edges.

## Limits

The study evaluates vulnerability discovery rather than LLM understanding. The
analysis is static, the implementation does not perform effective
interprocedural traversals, and the queries identify potentially vulnerable
code rather than deciding vulnerability in the general case. It gives no
evidence that graphs should be embedded in source or serialized into a prompt.

## Derived notes

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
