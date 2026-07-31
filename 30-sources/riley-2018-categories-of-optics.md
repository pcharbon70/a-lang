---
title: "Categories of Optics"
kind: source
created: 2026-07-31
authors:
  - "Mitchell Riley"
published: 2018
citation_key: riley2018Optics
container: "arXiv preprint"
doi: "10.48550/arXiv.1809.00738"
url: "https://arxiv.org/abs/1809.00738"
accessed: 2026-07-31
tags:
  - optics
  - bidirectional-programming
  - compositionality
aliases: []
---

# Categories of Optics

## Reference

Mitchell Riley. “Categories of Optics.” arXiv preprint, 2018.
[Paper](https://arxiv.org/abs/1809.00738)

## Contribution

The paper gives a categorical account of optics, a family that includes lenses,
prisms, and traversals used for bidirectional data access. It constructs optic
categories from symmetric monoidal categories, proves a universal property,
and gives a general notion of lawfulness.

## Finding

Multiple forms of bidirectional access and update can share one compositional
construction. Laws state when a bidirectional interface behaves coherently
rather than merely providing a pair of unrelated forward and backward
functions.

## Relevance

Agent systems repeatedly focus on a view of larger state and then propagate a
repair, clarification, or result back into that state. Optic-like interfaces
could support lawful context projection, local repair, subtask updates, and
feedback routing without granting every component unrestricted access to the
whole state.

## Limits

The paper concerns abstract bidirectional accessors, not conversational repair
or autonomous agents. Human feedback and environment changes often violate
the round-trip laws expected of ordinary lenses, so optics should be used only
where a clear lawful view-update relation exists.

## Derived notes

- [Set and category principles for an agent programming language](../20-notes/set-and-category-principles-for-agent-programming-language.md)
- [Can categorical semantics materially improve an agent language?](../40-inquiries/can-categorical-semantics-improve-agent-language.md)
