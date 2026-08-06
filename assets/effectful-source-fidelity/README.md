---
title: "Effectful Source Fidelity Assets"
kind: map
created: 2026-08-05
tags:
  - dataset
  - directory-index
  - evaluation
  - task-language
aliases: []
---

# Effectful Source Fidelity Assets (`assets/effectful-source-fidelity`)

## Purpose

This directory preserves the immutable inputs and repository-safe retained
records for the effectful source-fidelity experiment: closed contracts,
hand-authored paired source documents, answer keys, provider profiles, prompts,
campaign ceilings, and the actual hosted-campaign closure.

Generated schedules, manifests, reports, and intermediate evidence bundles
belong under the ignored `build/effectful-source-fidelity/` directory instead.

## What belongs here

- Versioned JSON Schemas and exact machine-readable decision rules.
- Hand-authored A-Lang and typed-JSON corpus representations.
- Representation-neutral semantic oracles and reviewed pair manifests.
- Frozen prompt, provider, schedule, call, cost, and retention configuration.
- Redacted, immutable records needed to reproduce the actual campaign outcome.

Secrets, raw hosted responses, caches, and derived evidence do not belong here.

## Index

### Subdirectories

- [Campaign](campaign/README.md) — exact hosted model profiles, offline
  consent boundary, call and cost ceilings, evidence policy, and shared prompt.
- [Contracts](contracts/README.md) — closed comprehension and answer-key
  schemas plus the frozen metrics, bootstrap, safety, and decision rule.
- [Corpus](corpus/README.md) — 24 balanced semantic cases, 48 paired source
  documents, representation-neutral answer keys, and content-addressed review
  metadata.
- [Evidence](evidence/README.md) — repository-safe closure or normalized
  observation records used to reproduce the actual validity and decision path.

### Files

- None yet.

## Maintaining this index

Index every direct asset and nested directory when it is introduced. Keep
source fixtures immutable after the pre-registration digest is published and
describe any successor contract as a new version instead of silently changing
the frozen one.
