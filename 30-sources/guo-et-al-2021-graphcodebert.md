---
title: "GraphCodeBERT: Pre-training Code Representations with Data Flow"
kind: source
created: 2026-08-06
authors:
  - "Daya Guo"
  - "Shuo Ren"
  - "Shuai Lu"
  - "Zhangyin Feng"
  - "Duyu Tang"
  - "Shujie Liu"
  - "Long Zhou"
  - "Nan Duan"
  - "Alexey Svyatkovskiy"
  - "Shengyu Fu"
  - "Michele Tufano"
  - "Shao Kun Deng"
  - "Colin Clement"
  - "Dawn Drain"
  - "Neel Sundaresan"
  - "Jian Yin"
  - "Daxin Jiang"
  - "Ming Zhou"
published: 2021
citation_key: "guo-et-al-2021-graphcodebert"
container: "The Ninth International Conference on Learning Representations"
edition: null
isbn: null
doi: null
url: "https://arxiv.org/abs/2009.08366"
accessed: 2026-08-06
tags:
  - code-graphs
  - code-understanding
  - data-flow
  - representation-learning
aliases:
  - "GraphCodeBERT"
---

# GraphCodeBERT: Pre-training Code Representations with Data Flow

## Reference

Daya Guo et al. “GraphCodeBERT: Pre-training Code Representations with Data
Flow.” *ICLR 2021*. [arXiv](https://arxiv.org/abs/2009.08366).

## Method

GraphCodeBERT augments token sequences with a data-flow graph whose nodes are
variables and whose edges describe where values come from. A graph-guided
attention mask, edge-prediction objective, and token-node alignment objective
teach a Transformer to use that structure during pre-training. The model is
then fine-tuned on code search, clone detection, translation, and repair.

The authors choose data flow instead of a complete AST because it is a smaller
semantic projection: graph nodes account for roughly 5–20% of the combined
inputs in their code-search analysis.

## Findings

- Overall code-search MRR is 0.713 for GraphCodeBERT versus 0.693 for CodeBERT.
  Removing edge prediction yields 0.707, removing node alignment 0.703, and
  removing data flow entirely 0.693.
- Exact accuracy on the code-refinement task is 17.3 versus CodeBERT’s 16.4 on
  the small split, and 9.1 versus 5.2 on the medium split.
- The model allocates disproportionately high attention to data-flow nodes
  relative to their share of input elements.

## Relevance

The ablation supplies direct evidence that a compact derived relation graph can
improve learned code representations. It also supports using task-relevant
semantic projections rather than preserving every AST node.

## Limits

The benefit is produced by pre-training, architecture, and fine-tuning together.
It does not show that a hosted black-box LLM can use a graph supplied as text,
that repository-scale graph retrieval helps, or that authored semantic claims
belong inline in a language. The improvements also vary by downstream task; on
translation, exact accuracy changes only slightly in one direction.

## Derived notes

- [Semantic code graphs for LLM understanding](../20-notes/semantic-code-graphs-for-llm-understanding.md)
- [Can semantic code graphs improve LLM understanding?](../40-inquiries/can-semantic-code-graphs-improve-llm-understanding.md)
- [Semantic code graphs for LLM agents](../10-maps/semantic-code-graphs-for-llm-agents.md)
