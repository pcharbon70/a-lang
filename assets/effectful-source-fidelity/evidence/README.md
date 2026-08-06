---
title: "Effectful Source Fidelity Evidence"
kind: map
created: 2026-08-06
tags:
  - directory-index
  - evaluation-evidence
  - hosted-model-evaluation
  - redacted-evidence
aliases: []
---

# Effectful Source Fidelity Evidence (`assets/effectful-source-fidelity/evidence`)

## Purpose

This directory preserves the small, repository-safe records needed to replay
the actual hosted-campaign disposition without network access. The records are
inputs to deterministic BEAM analysis; generated manifests, reports, and
intermediate tables remain under the ignored `build/effectful-source-fidelity/`
tree.

## What belongs here

- Explicit campaign closure records with bounded accounting and no secrets.
- Redacted normalized observations when an authorized hosted campaign exists.
- Canonical decision inputs whose provenance can be reconstructed from frozen
  contracts and corpus assets.

Credentials, headers, raw provider envelopes, hidden reasoning, generated
analysis output, and fixture observations do not belong here.

## Index

### Subdirectories

- None yet.

### Files

- [`hosted-campaign-closure-v1.json`](hosted-campaign-closure-v1.json) — closes
  the unstarted hosted campaign as invalid after live authorization was not
  granted, records zero attempts, calls, tokens, and cost, and declares all
  288 registered primary cells missing without making an efficacy claim.

## Maintaining this index

Keep retained records versioned, redacted, bounded, and content-addressable.
Never overwrite a closure or observation set after analysis; a later hosted
attempt requires a newly authorized and pre-registered planning stream.
