---
title: "Compact Projection Fidelity Section 2.2 Integration Evidence"
kind: note
created: 2026-08-12
maturity: developing
tags:
  - beam
  - implementation-evidence
  - language-design
  - token-efficiency
aliases: []
---

# Compact Projection Fidelity Section 2.2 Integration Evidence

## Result

Section 2.2 implements `alang-model-v1` as a canonical keyed projection of a
validated task comprehension. Its decoder restores aliases and derived fields,
revalidates the reconstructed comprehension, and computes the same canonical
semantic digest before returning it.

The section command completed with seven new model-format tests, the 11
Section 2.1 tests, and the inherited Phase 1 suites passing. No model or
provider call was made.

## Projection and derivation evidence

- All 48 held-out cases and 32 deterministically generated valid tasks complete
  `decode(encode(checked_semantics))` with their original semantic digest.
- Rendering is byte-identical when the input map insertion order is reversed.
- Effects are omitted only when they equal the exact closed derivation from
  checked actions. Requirements are omitted only when they equal the exact
  keyed derivation from model and workspace scopes.
- Non-derived effects and requirements remain explicitly keyed, including
  empty declarations. Missing witnesses, fields absent without a witness, and
  fields present alongside a witness are rejected.
- Budgets, scopes, errors, child attenuation, completion predicates, and the
  terminal class are always represented by named fields rather than security-
  sensitive positions.

## Alias evidence

Repeated input, action, model-resource, and workspace-resource references use
deterministic `@nK` aliases only after their descriptive value appears once in
the bounded reverse map. Keys are contiguous, at most 64 aliases are accepted,
and each alias must be used at least twice in one namespace.

The encoder and decoder reject literal alias collisions, noncontiguous maps,
unknown aliases, unused or singly used aliases, duplicate reverse values, and
cross-namespace shadowing. Map swaps must either fail reconstruction or yield a
different semantic digest.

## Mutation evidence

Seeded changes cover removed derivation witnesses, contradictory explicit
fields, transposed budget values, wider model scope, weaker completion,
negated facts, wider child effects, alias deletion and swaps, and unknown
fields. Every mutant either fails closed or returns a semantic digest different
from the registered origin; no meaning-changing mutant retains the origin
digest.

## Trusted path

`alang_compact_model` and its surface dispatch compile deterministically to
`.beam` and run on ERTS. Canonical JSON is an A-Lang-owned wire format decoded
with duplicate-key rejection; it is not Erlang source, Erlang AST, or a foreign
interpreter path.

## Reproduction

From the repository root:

```bash
make test-compact-section-2-2
```

## Connections

- [Phase 2 plan](../../60-planning/03-compact-projection-fidelity/phase-02-compact-projection-and-token-accounting.md)
  defines the checked projection, inverse, and mutation gates satisfied here.
- [Section 2.1 evidence](section-02-01-integration-evidence.md) records the
  registry and exact token-accounting foundation used by this implementation.
