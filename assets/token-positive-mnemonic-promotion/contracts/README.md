---
title: "Token-Positive Mnemonic Promotion Contracts"
kind: map
created: 2026-08-27
tags:
  - directory-index
  - experiment-design
  - token-efficiency
aliases: []
---

# Token-Positive Mnemonic Promotion Contracts (`assets/token-positive-mnemonic-promotion/contracts`)

## Purpose

This directory contains closed machine-readable contracts for the P0/P1
campaign. They preserve the historical R2 role while giving its exact bytes
and decoder behavior a new prospective promotion-candidate identity.

## What belongs here

- The exact two-condition scientific contract and its JSON Schema.
- Later closed schemas for corpus, schedule, profiles, and evidence records.
- Immutable token, safety, fidelity, validity, and outcome ordering rules.

## Index

### Subdirectories

- None yet.

### Files

- [Campaign contract](campaign-contract-v1.json) — registers P0 and P1, the
  exact R2 references, all four protocols, inference boundaries, hard gates,
  excluded claims, and ordered outcomes.
- [Campaign contract schema](campaign-contract-v1.schema.json) — closes the
  top-level contract and every nested object against unregistered fields.

## Maintaining this index

Keep schemas closed, version changes explicitly, and never relax a gate or
change P1 rendering or decoding under an existing campaign version.
