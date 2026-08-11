---
title: "LLMLingua: Compressing Prompts for Accelerated Inference of Large Language Models"
kind: source
created: 2026-08-11
authors:
  - "Huiqiang Jiang"
  - "Qianhui Wu"
  - "Chin-Yew Lin"
  - "Yuqing Yang"
  - "Lili Qiu"
published: 2023
citation_key: "jiang-et-al-2023-llmlingua"
container: "Proceedings of the 2023 Conference on Empirical Methods in Natural Language Processing"
edition: null
isbn: null
doi: "10.18653/v1/2023.emnlp-main.825"
url: "https://aclanthology.org/2023.emnlp-main.825/"
accessed: 2026-08-11
tags:
  - inference-efficiency
  - prompt-compression
  - tokenization
aliases:
  - "LLMLingua"
---

# LLMLingua: Compressing Prompts for Accelerated Inference of Large Language Models

## Reference

Huiqiang Jiang, Qianhui Wu, Chin-Yew Lin, Yuqing Yang, and Lili Qiu.
“LLMLingua: Compressing Prompts for Accelerated Inference of Large Language
Models.” *EMNLP 2023*, pages 13358–13376.
[ACL Anthology](https://aclanthology.org/2023.emnlp-main.825/). DOI:
[10.18653/v1/2023.emnlp-main.825](https://doi.org/10.18653/v1/2023.emnlp-main.825).

## Method

LLMLingua uses a smaller language model to allocate a compression budget among
instructions, demonstrations, and questions, then iteratively removes
lower-information tokens while accounting for token dependencies. An
instruction-tuning stage aligns the compressor's distribution with the target
black-box model. The authors evaluate GSM8K, Big-Bench Hard, ShareGPT, and an
arXiv corpus.

## Findings

Selective, model-guided compression reaches up to 20× on the reported settings
with a small loss on GSM8K, although losses are larger on some Big-Bench Hard
conditions. Ablations show that uniform removal, random selection, and ignoring
token dependencies perform worse. At roughly 25–30× compression, performance
drops sharply, and the useful limit varies by prompt and task.

## Relevance

The work suggests that semantic importance is not uniform: instructions and
questions need gentler compression than repeated demonstrations. For A-Lang,
this supports compressing compiler-known scaffolding more aggressively than
goal facts, negative constraints, and completion evidence.

## Limits

LLMLingua is lossy and probabilistic. That is inappropriate for the only copy
of an executable capability contract, where omitting one negation, path, or
budget can widen authority. It is adjacent evidence for allocation strategy,
not a replacement for a reversible A-Lang projection.

## Derived notes

- [Token-efficient syntax for A-Lang](../20-notes/token-efficient-syntax-for-a-lang.md)
- [Can a compact projection reduce A-Lang token use without reducing fidelity?](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
- [Token-efficient A-Lang syntax](../10-maps/token-efficient-alang-syntax.md)
