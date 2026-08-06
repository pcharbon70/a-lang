---
title: "CodeOntology: RDF-ization of Source Code"
kind: source
created: 2026-08-06
authors:
  - "Mattia Atzeni"
  - "Maurizio Atzori"
published: 2017
citation_key: "atzeni-atzori-2017-codeontology"
container: "The Semantic Web – ISWC 2017"
edition: null
isbn: "978-3-319-68203-7"
doi: "10.1007/978-3-319-68204-4_2"
url: "https://iris.unica.it/handle/11584/238969"
accessed: 2026-08-06
tags:
  - code-graphs
  - knowledge-graphs
  - semantic-web
  - source-code-analysis
aliases:
  - "CodeOntology"
---

# CodeOntology: RDF-ization of Source Code

## Reference

Mattia Atzeni and Maurizio Atzori. “CodeOntology: RDF-ization of Source Code.”
In *The Semantic Web – ISWC 2017*, LNCS 10588, 20–28.
[DOI](https://doi.org/10.1007/978-3-319-68204-4_2).

## Method

CodeOntology defines an OWL 2 ontology for object-oriented program elements and
a Java extractor built with Spoon and Jena. The ontology contains 65 classes,
86 object properties, and 11 data properties and was checked with the HermiT
reasoner. Source, bytecode, documentation comments, and selected links to
DBpedia are serialized as RDF and queried with SPARQL.

## Findings

- Processing roughly 1.5 million lines of OpenJDK 8 produced almost two million
  RDF triples.
- Across 20 sampled Java repositories, the parser produced more than 30.5
  million triples. Several source analyses failed when Spoon could not build an
  AST, including cases with missing dependencies.
- Example queries rank referenced classes and retrieve methods associated with
  a domain concept such as cube roots.

## Relevance

CodeOntology demonstrates that a formal code ontology and expressive graph
queries are technically feasible at repository scale. It also provides a clean
contrast with the user’s proposal: the graph is generated outside the source,
and most relations describe program structure rather than authored intent.

## Limits

The evaluation establishes extraction feasibility, scale, and illustrative
queries. It does not measure whether developers or LLMs answer questions more
accurately, whether ontology inference is correct for software behavior, or
whether inline semantic assertions improve maintenance. Dependency failures and
large triple counts also argue for revision checks and selective materialization.

## Derived notes

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
