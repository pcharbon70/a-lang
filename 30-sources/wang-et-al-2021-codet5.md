---
title: "CodeT5: Identifier-aware Unified Pre-trained Encoder-Decoder Models for Code Understanding and Generation"
kind: source
created: 2026-08-11
authors:
  - "Yue Wang"
  - "Weishi Wang"
  - "Shafiq Joty"
  - "Steven C. H. Hoi"
published: 2021
citation_key: "wang-et-al-2021-codet5"
container: "Proceedings of the 2021 Conference on Empirical Methods in Natural Language Processing"
edition: null
isbn: null
doi: "10.18653/v1/2021.emnlp-main.685"
url: "https://aclanthology.org/2021.emnlp-main.685/"
accessed: 2026-08-11
tags:
  - code-generation
  - code-models
  - identifiers
aliases:
  - "CodeT5"
---

# CodeT5: Identifier-aware Unified Pre-trained Encoder-Decoder Models for Code Understanding and Generation

## Reference

Yue Wang, Weishi Wang, Shafiq Joty, and Steven C. H. Hoi. “CodeT5:
Identifier-aware Unified Pre-trained Encoder-Decoder Models for Code
Understanding and Generation.” *EMNLP 2021*, pages 8696–8708.
[ACL Anthology](https://aclanthology.org/2021.emnlp-main.685/). DOI:
[10.18653/v1/2021.emnlp-main.685](https://doi.org/10.18653/v1/2021.emnlp-main.685).

## Method

CodeT5 augments T5-style denoising with identifier tagging and masked
identifier prediction. It parses code to identify developer-assigned names,
masks all occurrences of each identifier consistently, and trains the model to
recover those names. The model is pretrained on about 8.35 million examples
from eight languages and evaluated across CodeXGLUE understanding and
generation tasks.

## Finding

The paper treats developer-assigned identifiers as a distinct semantic channel
rather than interchangeable syntax. Its identifier-aware objectives contribute
to a model that outperforms the reported baselines across defect detection,
clone detection, summarization, generation, translation, and refinement. The
paper also finds that identifiers constitute roughly 19–32% of code tokens in
its language corpora.

## Relevance

The work is evidence against assuming that shortening `release-workspace` to
`w` is semantically free for a model. Even when runtime name resolution remains
correct, an informative name may help the model recover the role of a resource
or step. A-Lang should test identifier opacity separately from keyword and
format compression.

## Limits

CodeT5 does not directly compare short and descriptive identifiers, and its
gains bundle several pretraining objectives. It supports the claim that names
carry learnable information, not a specific naming-length optimum for A-Lang.

## Derived notes

- [Token-efficient syntax for A-Lang](../20-notes/token-efficient-syntax-for-a-lang.md)
- [Can a compact projection reduce A-Lang token use without reducing fidelity?](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
- [Token-efficient A-Lang syntax](../10-maps/token-efficient-alang-syntax.md)
