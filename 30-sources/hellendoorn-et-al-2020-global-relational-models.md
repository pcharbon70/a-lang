---
title: "Global Relational Models of Source Code"
kind: source
created: 2026-08-06
authors:
  - "Vincent J. Hellendoorn"
  - "Petros Maniatis"
  - "Rishabh Singh"
  - "Charles Sutton"
  - "David Bieber"
published: 2020
citation_key: "hellendoorn-et-al-2020-global-relational-models"
container: "The Eighth International Conference on Learning Representations"
edition: null
isbn: null
doi: null
url: "https://openreview.net/forum?id=B1lnbRNtwr"
accessed: 2026-08-06
tags:
  - code-graphs
  - code-understanding
  - program-repair
  - representation-learning
aliases:
  - "GREAT"
---

# Global Relational Models of Source Code

## Reference

Vincent J. Hellendoorn, Petros Maniatis, Rishabh Singh, Charles Sutton, and
David Bieber. “Global Relational Models of Source Code.” *ICLR 2020*.
[OpenReview](https://openreview.net/forum?id=B1lnbRNtwr).

## Method

The paper compares sequence, graph, and hybrid models on Python variable-misuse
localization and repair. Its graphs include typed syntactic, token-adjacency,
data-flow, control-flow, and call relations. Graph Sandwich models combine
local graph message passing with global sequence layers; GREAT injects typed
relations into Transformer attention.

The authors also introduce a leaves-only projection that moves semantic edges
to source tokens and omits internal AST nodes. It retains most edges while
using two to three times fewer nodes than the full AST graph.

## Findings

- On synthetic functions up to 1,000 tokens, localization-and-repair accuracy
  is 42.5% for the RNN, 63.0% for the Transformer, 60.9% for the GGNN, 73.8%
  for the RNN Sandwich, 71.4% for the Transformer Sandwich, and 73.1% for
  GREAT.
- On 161 mined real bugs, absolute results fall sharply. RNN Sandwich reaches
  28.6% precision and 43.5% recall; GREAT reaches 23.7% precision and 36.7%
  recall. The hybrids still generally improve on the older baselines, but the
  synthetic-to-real gap is substantial.

## Relevance

The work supports typed relations as an inductive bias and compact projections
as a design goal. It also shows why an A-Lang experiment must use realistic
repository revisions and verified edits rather than only synthetic graph
questions.

## Limits

This is a trained-model study of one bug family, not a prompt-time or
repository-navigation experiment. The graph edge set is derived by analysis;
the paper does not test ontological labels, developer-authored intent, or
source-embedded triples.

## Derived notes

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
