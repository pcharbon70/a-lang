---
title: "Functorial Data Migration"
kind: source
created: 2026-07-31
authors:
  - "David I. Spivak"
published: 2012
citation_key: spivak2012FunctorialDataMigration
container: "Information and Computation 217, 31–51"
doi: "10.1016/j.ic.2012.05.001"
url: "https://arxiv.org/abs/1009.1166"
accessed: 2026-07-31
tags:
  - categorical-databases
  - schema-migration
  - functors
aliases: []
---

# Functorial Data Migration

## Reference

David I. Spivak. “Functorial Data Migration.” *Information and Computation*
217 (2012): 31–51.
[Open manuscript](https://arxiv.org/abs/1009.1166)

## Contribution

The paper models a database schema as a small category and a database instance
as a set-valued functor. Morphisms between schemas induce canonical data
migration functors corresponding broadly to projection, union, and join-like
operations over whole schemas.

It also connects categorical schemas to the type category of a functional
programming language.

## Finding

Schema and instance can be separated while retaining principled,
structure-preserving migrations between schemas. Operations over interconnected
tables arise from the mapping as a whole rather than from an unrelated list of
field conversions.

## Relevance

Agents constantly move information between user intent, task state, tool
schemas, evidence records, traces, and final artifacts. A functorial schema
layer could make those migrations explicit, support versioned tools, and
preserve provenance relationships through representation changes.

This also illustrates how a categorical IR can have multiple concrete data
realizations without making its surface syntax the only semantics.

## Limits

Database migrations are substantially more regular than natural-language
meaning. Functoriality can preserve a mapping that was specified incorrectly;
it does not prove that two schemas express the same human concept.

## Derived notes

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Categorical foundations for agent languages](../10-maps/categorical-foundations-for-agent-languages.md)
