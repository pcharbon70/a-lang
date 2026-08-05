---
title: "Effectful Source Fidelity Contracts"
kind: map
created: 2026-08-05
tags:
  - directory-index
  - evaluation-contract
  - json-schema
  - task-language
aliases: []
---

# Effectful Source Fidelity Contracts (`assets/effectful-source-fidelity/contracts`)

## Purpose

This directory contains the versioned, machine-readable contracts that define
the experiment before any hosted model is observed. The matching BEAM
validators are indexed in the
[implementation directory](../../../src/effectful-source-fidelity/README.md).

## What belongs here

- Closed JSON Schemas for model responses, semantic oracles, controls, and
  campaign records.
- Exact constants for metrics, bootstrap resampling, promotion, replacement,
  stop outcomes, and safety vetoes.
- Future contract versions added without mutating a frozen predecessor.

Corpus cases, provider profiles, prompts, and generated evidence belong in
their corresponding sibling directories.

## Index

### Subdirectories

- None yet.

### Files

- [`alang-answer-key-v1.schema.json`](alang-answer-key-v1.schema.json) — binds
  one case identity and canonical semantic digest to a closed expected
  comprehension record without representation-specific origins.
- [`alang-task-comprehension-v1.schema.json`](alang-task-comprehension-v1.schema.json)
  — defines the closed, bounded semantic record recovered from either source
  representation.
- [`metrics-and-decision-v1.json`](metrics-and-decision-v1.json) — freezes the
  primary and secondary metrics, invalid-response scoring, paired bootstrap,
  promotion and replacement thresholds, safety vetoes, and outcomes.

## Maintaining this index

Index each direct contract file with its version and purpose. Changes to
frozen semantics require a new version, validator tests, updated references,
and a new pre-registration digest rather than an in-place threshold edit.
