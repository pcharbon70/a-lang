---
title: "Compact Projection Fidelity Confirmatory Corpus"
kind: map
created: 2026-08-12
tags:
  - archive-navigation
  - confirmatory-corpus
  - directory-index
  - evaluation
aliases: []
---

# Compact Projection Fidelity Confirmatory Corpus (`assets/compact-projection-fidelity/corpus`)

## Purpose

This directory holds the held-out semantic cases used by the compact
projection campaign. The cases describe representation-neutral requirements
and oracles; no readable, compact, minified, opaque, or JSON representation is
materialized here.

## What belongs here

- Independently authored semantic requirements and structured oracles.
- Blinded independence, balance, and leakage-audit declarations.
- Versioned corpus inputs that are frozen before representation generation.

Generated projections, answer keys, schedules, and observations belong under
ignored build paths.

## Index

### Subdirectories

- None yet.

### Files

- [`confirmatory-corpus-v1.json`](confirmatory-corpus-v1.json) — defines 48
  held-out cases, two independent replicates in every runtime-family/stratum
  cell, with representation-neutral semantic oracles.

## Maintaining this index

Do not expose condition names or representation examples in corpus content.
After preregistration, replace the corpus only through a new version and keep
the exclusion and replacement record with that version.
