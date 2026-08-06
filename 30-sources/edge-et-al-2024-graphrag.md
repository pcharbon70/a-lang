---
title: "From Local to Global: A Graph RAG Approach to Query-Focused Summarization"
kind: source
created: 2026-08-06
authors:
  - "Darren Edge"
  - "Ha Trinh"
  - "Newman Cheng"
  - "Joshua Bradley"
  - "Alex Chao"
  - "Apurva Mody"
  - "Steven Truitt"
  - "Dasha Metropolitansky"
  - "Robert Osazuwa Ness"
  - "Jonathan Larson"
published: 2024
citation_key: "edge-et-al-2024-graphrag"
container: "arXiv:2404.16130"
edition: null
isbn: null
doi: null
url: "https://arxiv.org/abs/2404.16130"
accessed: 2026-08-06
tags:
  - graph-retrieval
  - knowledge-graphs
  - large-language-models
  - retrieval-augmented-generation
aliases:
  - "GraphRAG"
---

# From Local to Global: A Graph RAG Approach to Query-Focused Summarization

## Reference

Darren Edge et al. “From Local to Global: A Graph RAG Approach to
Query-Focused Summarization.” *arXiv:2404.16130*, revised 2025.
[arXiv](https://arxiv.org/abs/2404.16130).

## Method

GraphRAG uses an LLM to extract entities, relationships, and claims from a text
corpus, applies community detection to the resulting graph, and pre-generates
summaries at multiple levels. A global question is answered by mapping over
community summaries and reducing the partial answers. The study compares these
conditions with vector retrieval and graph-free global source-text
summarization on two corpora of roughly one million tokens each.

## Findings

- Against vector RAG, global methods achieve 72–83% comprehensiveness win rates
  and 62–82% diversity win rates across the two corpora. Vector RAG produces
  more direct answers.
- Root-community summaries use more than 97% fewer context tokens than global
  source-text summarization and remain stronger than vector RAG on the reported
  comprehensiveness and diversity comparisons.
- A second claim- and cluster-based evaluation finds no statistically
  significant differences among the global graph conditions or between graph
  search and graph-free global text summarization for comprehensiveness or
  diversity.

## Relevance

GraphRAG supports graph structure as a multi-scale retrieval and summarization
index for global questions. The second experiment is equally important: it
does not isolate a unique benefit from graph topology over a strong hierarchical
text summary. An A-Lang test must therefore compare graph queries with the same
facts organized as compact flat or hierarchical context.

## Limits

This is not a code study. Entities and relationships are LLM-extracted and may
be implicit or abstractive; entity merging uses exact-string matching. The two
corpora, generated questions, and LLM judging limit generality, and the paper
does not measure fabrication rates. Precomputation is substantial and is not
included in per-query context savings.

## Derived notes

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
