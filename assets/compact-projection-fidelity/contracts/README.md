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

## Maintaining this index

Keep every object closed, update the schema before changing a contract shape,
and create a new version rather than mutating a preregistered contract after a
model-visible request has been authorized.
