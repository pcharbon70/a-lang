---
title: "Model-facing A-Lang promotion must be token-positive"
kind: note
created: 2026-08-25
maturity: developing
tags:
  - a-lang
  - decision-rules
  - language-design
  - token-efficiency
aliases:
  - "Token-positive promotion gate"
---

# Model-facing A-Lang promotion must be token-positive

## Decision

A representation proposed specifically to reduce model-token cost is not
eligible for promotion when it costs more model-visible tokens than readable
`alang-source-v2`. Better fidelity, smaller byte length, or an attractive
internal structure cannot compensate for failing the representation's stated
efficiency purpose.

Readable A-Lang remains the canonical source in every outcome. A promoted
model-facing form must be a deterministic, reversible, source-mapped view of
the same checked semantics and must pass both a token-positive eligibility
gate and independent fidelity and safety gates.

## Evidence that changed the candidate

The [Phase 2 integration evidence](../src/compact-projection-fidelity/section-02-04-integration-evidence.md)
measured 24 development and 48 confirmatory semantic cases without making a
model call. The original `R3` keyed projection was 8.34% smaller in bytes than
readable `R0`, yet used 8.33% more `cl100k_base` document tokens and 13.10%
more `o200k_base` document tokens. Character reduction therefore did not
satisfy the token-efficiency objective.

The `R2` layout-minified mnemonic form used 8.72% fewer `cl100k_base` document
tokens and 7.96% fewer `o200k_base` document tokens than `R0`. It was strictly
cheaper on every one of the 72 measured cases for both document and full-
request counts. Its smallest per-case saving was 6.85% for `cl100k_base`
documents and 6.15% for `o200k_base` documents.

These are exact offline tokenizer results, not evidence of model fidelity.
They falsify `R3` as a token-efficiency promotion candidate and justify a new
campaign in which the exact R2 surface is re-registered for full promotion
testing.

## Token-positive eligibility invariant

Before any model-facing campaign call, a candidate must satisfy all of the
following against the exact readable baseline under every registered target
tokenizer:

1. Every paired semantic case has strictly fewer candidate document tokens.
2. Every paired full request, including the candidate legend and output
   scaffolding, has strictly fewer candidate input tokens.
3. Aggregate and median document and full-request savings are each at least
   5%.
4. The same result reproduces from clean ERTS processes and shuffled input map
   orders with pinned tokenizer, prompt, corpus, and representation digests.

After authorized model execution, provider-reported prompt tokens become the
operational authority. Promotion additionally requires:

- no paired candidate request with more provider input tokens than its
  readable counterpart;
- at least 5% aggregate provider-input savings in every model family and task
  protocol; and
- no increase in aggregate input-plus-output tokens per scheduled primary cell
  in any model-family and protocol stratum, including failed responses rather
  than conditioning cost on success.

If an exact provider tokenizer or usage record is unavailable, the campaign
cannot establish token-positive promotion. Estimates may explain a blocked
campaign but cannot satisfy the gate.

## Separate fidelity and safety gates

Passing the token gate only makes a candidate eligible for evaluation. It
does not make the candidate acceptable. Promotion still requires exact
round trips, registered non-inferiority, parse and repair reliability, and
zero candidate-only authority widening, unauthorized effects, or false
completion.

The decision is conjunctive rather than weighted:

```text
token-positive
    AND fidelity-noninferior
    AND repair-and-generation-valid
    AND no-new-safety-failure
    AND reproducible
```

A token-negative representation may remain useful as an architectural or
mechanism control. It cannot become the default model-facing representation
under a token-efficiency claim.

## Consequence for the original campaign

The [original compact-projection campaign](../60-planning/03-compact-projection-fidelity/README.md)
must remain unchanged as a provenance record. `R2` was declared a
comprehension-only, nonpromotable ablation and `R3` the sole candidate before
the Phase 2 counts existed. Retrofitting `R2` into that decision would be
outcome-driven selection.

Instead, the [token-positive mnemonic promotion campaign](../60-planning/04-token-positive-mnemonic-promotion/README.md)
gives the exact R2 model-visible bytes a new campaign-local candidate role,
tests them on all four protocols, and freezes the rendering identity and
decision rule before any model outcome is observed. Any rendering change is a
different candidate, not an improvement to P1.

## Connections

- [Token-efficient syntax for A-Lang](token-efficient-syntax-for-a-lang.md) —
  provides the research basis for reversible shorthand and the warning that
  byte density is not token efficiency.
- [Open compact-projection inquiry](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
  — remains unresolved until a token-positive candidate passes model-fidelity
  and safety testing.
- [Token-efficient A-Lang syntax map](../10-maps/token-efficient-alang-syntax.md)
  — places this decision in the broader tokenizer and representation trail.

## Sources

This decision derives from the archive's connected research synthesis and the
reproducible Phase 2 implementation evidence rather than a new external
source.
