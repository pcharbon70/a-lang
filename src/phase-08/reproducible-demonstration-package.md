---
title: "Phase 8 Reproducible Demonstration Package"
kind: note
created: 2026-08-04
maturity: developing
tags:
  - beam
  - proof-of-concept
  - reproducible-builds
  - release-engineering
aliases: []
---

# Phase 8 Reproducible Demonstration Package

## Outcome

One offline command compiles frozen A-Lang source through the BEAM-resident
frontend and Abstract Format backend, inspects and executes its `.beam`, runs a
more-restricted compiled child against a deterministic mock model, performs one
broker-authorized durable workspace write, verifies the Markdown artifact, and
emits machine- and human-readable evidence.

```bash
make demo
```

The command requires only the pinned OTP installation and repository checkout.
It does not fetch dependencies, contact a model provider, read credentials, or
invoke a foreign compiler. The workspace sidecar is a bounded external runtime
effect and is itself a BEAM program launched through an owned port.

## Frozen inputs and outputs

The [`fixtures`](fixtures/README.md) directory owns the source, input 41,
model profile and response, local authority shape, manifests, normalized causal
stages, exact Markdown result, and expected digests. The demonstration rejects
digest drift rather than silently updating its golden record.

The generated bundle contains:

- `source.alang`, deterministic `canonical-source.etf`, and
  `typed-task-ir.etf`;
- inspected `source.beam`, `child.beam`, and `workspace.beam` artifacts;
- the durable journal and workspace result under owned output directories;
- `evidence.config`, whose digest covers the normalized causal record; and
- `explanation.md`, which describes effects, authority, result, verifier state,
  and uncertainty in A-Lang vocabulary.

Opaque grant references, process identifiers, adapter port identities,
credentials, and private context are excluded from the bundle. The independent
inspector recomputes evidence and artifact digests, decodes the canonical source
and IR, reinspects every BEAM artifact, scans for runtime-local identities, and
requires the human explanation.

## Ownership and failure behavior

Outputs must be descendants of `build/phase-08/`. A run removes only its exact
owned output directory before starting, then leaves partial output in place if
a later stage fails. Tests use unique owned directories and remove them after
inspection. Durable records and the final artifact stay available in the
successful demonstration bundle.

## Limits

This package proves the frozen offline slice on the declared OTP environment.
It does not turn the Phase 2 source syntax into the full effectful language:
the accepted source remains the pure compiled entry artifact, while promoted
typed IR fixtures exercise the already-implemented model and workspace effect
vocabulary. Live providers, additional effects, multi-node execution, and
production packaging remain outside this gate.

See the [Phase 8 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-08-end-to-end-demonstration-and-poc-decision.md)
and [Phase 7 integration evidence](../phase-07/phase-07-integration-evidence.md).
