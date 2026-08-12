---
title: "Compact Projection Fidelity Assets"
kind: map
created: 2026-08-12
tags:
  - archive-navigation
  - directory-index
  - evaluation
  - token-efficiency
aliases: []
---

# Compact Projection Fidelity Assets (`assets/compact-projection-fidelity`)

## Purpose

This directory owns immutable schemas, experiment contracts, confirmatory
cases, model profiles, prompts, schedules, and preregistration inputs for the
[compact projection fidelity plan](../../60-planning/03-compact-projection-fidelity/README.md).
It is separate from the frozen effectful-source-fidelity assets.

## What belongs here

- Closed JSON schemas and machine-readable decision rules.
- Development/confirmation boundary records and held-out semantic cases.
- Exact model, tokenizer, prompt, schedule, and resource registrations.
- Inputs whose content digests must be frozen before any campaign call.

Generated observations and evidence do not belong here. They remain under the
ignored `build/compact-projection-fidelity/` tree until the plan explicitly
requires a safe retained artifact.

## Index

### Subdirectories

- [Campaign inputs](campaign/README.md) — the power assumptions, balanced
  opaque case design, deterministic factor schedule, and operational bounds.
- [Confirmatory corpus](corpus/README.md) — 48 independently authored,
  representation-neutral semantic cases and their blinded audit record.
- [Contracts](contracts/README.md) — closed schemas and registered scientific
  contrasts, metrics, safety vetoes, and ordered outcomes.

### Files

- None yet.

## Maintaining this index

Add every immutable campaign input to the nearest local index, preserve the
development/confirmation boundary, and never revise a frozen input in place
after model observation. A post-freeze change requires a new version.
