---
title: "Compact Projection Fidelity Section 2.4 Integration Evidence"
kind: note
created: 2026-08-12
maturity: developing
tags:
  - beam
  - implementation-evidence
  - source-maps
  - token-efficiency
aliases: []
---

# Compact Projection Fidelity Section 2.4 Integration Evidence

## Result

Section 2.4 closes the offline implementation phase. All six registered
surfaces render canonically, source-map completely, and recover the same
checked semantic digest across the 24-case development corpus and 48-case
confirmatory corpus.

Two clean ERTS processes independently produced byte-identical evidence with
digest `2b93c9a187038985eba76d0f3209572e5d8b11735601909c70c15d3134175fd0`.
The evidence contains 432 surface-case cells and 864 exact token reports. The
section command runs 66 EUnit tests across Phases 1 and 2; no model or provider
call is made.

## Corpus and property evidence

- The 72 corpus oracles produce 432 canonical surface renderings. Every
  rendering is unchanged when all input-map insertion orders are recursively
  reversed.
- Every rendering decodes to its oracle semantic digest. R4 uses only its
  matching bounded, non-model-visible reverse context.
- Independently rebuilt source maps are byte-identical after map-order
  shuffling and cover every representation byte and security-relevant field.
- Sixteen generated valid tasks exercise changing identifiers, facts, output
  bounds, and matching completion evidence across every surface, adding 96
  semantic round trips.
- Eight invalid checked tasks exercise effects, requirements, scopes, budgets,
  errors, child authority, completion, and operations. All six renderers reject
  each invalid task before projection, for 48 negative renderer checks.
- Every surface rejects a changed registered version and a 32,769-byte input;
  R3 and R4 also reject local and opaque alias maps one entry beyond their
  respective 64-entry and 128-entry limits.
- R2 applies `~` only to predicates in the frozen alias vocabulary. Unregistered
  development predicates remain readable and round-trip without creating a
  new alias.

## Exact token accounting

Counts below are the sums over all 72 corpus cases. They come from the pinned
BEAM BPE implementations; provider usage is unavailable and no proxy count is
substituted.

| Surface | Bytes | `cl100k_base` document tokens | `o200k_base` document tokens |
| --- | ---: | ---: | ---: |
| R0 readable | 66,071 | 17,204 | 17,118 |
| R1 minified | 61,423 | 16,108 | 16,348 |
| R2 mnemonic aliases | 46,317 | 15,703 | 15,755 |
| R3 keyed model form | 60,562 | 18,639 | 19,362 |
| R4 opaque control | 56,853 | 18,546 | 19,263 |
| R5 typed JSON | 91,710 | 22,013 | 22,830 |

R3 is 5,509 bytes, or 8.34%, smaller than R0. It nevertheless uses 1,435
more `cl100k_base` tokens and 2,244 more `o200k_base` tokens: increases of
8.33% and 13.10%, respectively. This is an offline screening result, not model
efficacy. It demonstrates why byte length cannot stand in for the campaign's
registered token and task-fidelity measurements. R2 has the lowest document
token total in both screening profiles but remains a nonpromotable ablation
under the frozen campaign contract.

## Mutation adequacy

The seeded campaign detects all seven named defects, for a mutation score of
10,000 basis points:

- an unknown decoder field;
- removal of an exact derivation witness;
- removal of a reverse-alias entry;
- removal of a required token-attribution category;
- a shifted source-map range;
- a representation-version change; and
- a widened authority budget.

Each defect must either fail its closed validator or produce a semantic digest
different from the oracle. A merely parseable mutant cannot pass as equivalent.

## Trusted BEAM closure

The residency audit loads 17 lexer, parser, AST, checker, representation,
corpus, normalizer, tokenizer, audit, projector, decoder, source-map,
mutation, and evidence modules from deterministic `.beam` artifacts. It
inspects their BEAM import tables and source inputs.

The audit finds no foreign build input, provider SDK, interpreted form, port,
shell command, forbidden runtime import, or project-loaded NIF. Vocabulary
files remain bounded data read by the BEAM tokenizer. Generated evidence
records zero network, provider, and model calls and explicitly sets
`model_fidelity_claimed` to false.

## Reproduction

From the repository root:

```bash
make test-compact-phase-2
```

The target compiles with `erlc +deterministic`, writes two independent
canonical JSON records under the ignored
`build/compact-projection-fidelity/phase-02/evidence/` directory, requires an
exact byte comparison, and then runs the complete inherited and Phase 2 test
chain.

## Connections

- [Phase 2 plan](../../60-planning/03-compact-projection-fidelity/phase-02-compact-projection-and-token-accounting.md)
  defines the integration and phase-completion gates satisfied here.
- [Section 2.3 evidence](section-02-03-integration-evidence.md) establishes the
  opaque control and source-map contracts reused by the all-surface suite.
- [Token-efficient syntax for A-Lang](../../20-notes/token-efficient-syntax-for-a-lang.md)
  explains why token screening and model-task fidelity remain separate
  questions.
