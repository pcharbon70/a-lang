---
title: "Compact Projection Fidelity Contracts"
kind: map
created: 2026-08-12
tags:
  - archive-navigation
  - directory-index
  - evaluation
  - token-efficiency
aliases: []
---

# Compact Projection Fidelity Contracts (`assets/compact-projection-fidelity/contracts`)

## Purpose

This directory fixes the compact campaign's scientific and machine-validation
contracts before confirmatory observations can exist.

## What belongs here

- Closed JSON schemas for campaign inputs and evidence.
- Registered conditions, task protocols, estimands, thresholds, vetoes, and
  ordered decisions.
- Versioned contracts consumed by BEAM validators and offline replay.

## Index

### Subdirectories

- None yet.

### Files

- [`campaign-contract-v1.json`](campaign-contract-v1.json) — freezes the six
  representation roles, four model tasks, primary and secondary metrics,
  paired inference, promotion thresholds, safety vetoes, and four ordered
  dispositions.
- [`campaign-contract-v1.schema.json`](campaign-contract-v1.schema.json) — the
  closed JSON Schema for the campaign contract.
- [`campaign-policy-v1.schema.json`](campaign-policy-v1.schema.json) — the
  closed schema for offline default, opt-in, availability, request, compute,
  replacement, retention, and invalidation policy.
- [`case-design-v1.schema.json`](case-design-v1.schema.json) — the closed
  schema for the 48 opaque family/stratum/replicate assignments.
- [`confirmatory-corpus-v1.schema.json`](confirmatory-corpus-v1.schema.json) —
  the closed schema for the held-out requirements, context, semantic-oracle
  descriptors, and blinded audit log.
- [`power-design-v1.schema.json`](power-design-v1.schema.json) — the closed
  schema for simulation assumptions and balanced sample-size selection.
- [`provider-profiles-v1.schema.json`](provider-profiles-v1.schema.json) — the
  closed schema for exact Ollama artifact identities and request parameters.
- [`schedule-policy-v1.schema.json`](schedule-policy-v1.schema.json) — the
  closed schema for factor eligibility, counts, seed, and request bounds.
- [`tokenizer-profiles-v1.schema.json`](tokenizer-profiles-v1.schema.json) —
  the closed schema for reproducible screening encodings and authoritative
  provider accounting.

## Maintaining this index

Keep every object closed, update the schema before changing a contract shape,
and create a new version rather than mutating a preregistered contract after a
model-visible request has been authorized.
