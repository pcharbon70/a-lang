---
title: "Compact Projection Fidelity Section 2.3 Integration Evidence"
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

# Compact Projection Fidelity Section 2.3 Integration Evidence

## Result

Section 2.3 implements the `R4` opaque-identifier negative control, an exact
non-model-visible reverse decode context, contiguous compact source maps, and
diagnostics expressed in canonical readable-source terms.

The section command completed with 11 new opaque-control and source-map tests,
the 18 Phase 2 predecessor tests, and every inherited Phase 1 test passing. No
model or provider call was made.

## Opaque control evidence

- All 48 held-out cases render deterministically and recover their original
  semantic digest when decoded with the matching reverse context.
- Task, input, action, model-resource, and workspace-resource identities are
  replaced by deterministic `oK` values before `alang-model-v1` serialization.
- Literal facts, authority paths, enum tags, effect vocabulary, scope and
  budget keys, provider model profiles, and completion predicate vocabulary
  remain byte-exact.
- The reverse map is bounded to 128 entries, excluded from model-visible bytes,
  namespace typed, and required for decode. Missing, noncontiguous, colliding,
  duplicate, wrong-kind, unknown, or unused entries fail closed.
- Both the implementation and frozen campaign contract mark R4
  nonpromotable. The only campaign candidate remains R3, so an R4 metric win
  cannot select the negative control as the default representation.

## Source-map evidence

For every R3 and R4 rendering of all 48 cases, the source map partitions the
complete representation byte range into contiguous, nonoverlapping lexical
tokens. Every token has either a generated-schema origin or one or more
semantic paths.

Every leaf below effects, requirements, scopes, budgets, errors, child
attenuation, completion, and terminal class has:

- one or more compact ranges;
- an exact derivation witness; or
- a versioned empty-elision witness.

Each security field also carries canonical readable-source byte, line, and
column spans. Local and opaque aliases carry their original descriptive value
and all compact occurrences. Coverage gaps, dropped security fields, invalid
ranges, unknown origins, and missing readable spans are rejected.

## Diagnostic evidence

Diagnostics accept a semantic path and emit the original readable value,
readable-source spans, an explicit `readable-source` edit target, and optional
compact spans. The opaque action test reports `draft`, never its generated
`oK` identity, so users are not directed to edit generated compact text.

## Trusted path

Opaque transformation, reverse restoration, lexical mapping, validation, and
diagnostic rendering compile deterministically to `.beam` and execute on ERTS.
The reverse context is ordinary bounded data; no port, NIF, shell, foreign
interpreter, or provider SDK participates.

## Reproduction

From the repository root:

```bash
make test-compact-section-2-3
```

## Connections

- [Phase 2 plan](../../60-planning/03-compact-projection-fidelity/phase-02-compact-projection-and-token-accounting.md)
  defines the opaque-control, map, and readable-diagnostic gates satisfied
  here.
- [Section 2.2 evidence](section-02-02-integration-evidence.md) records the
  checked R3 projection on which the negative control operates.
