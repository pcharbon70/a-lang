---
title: "Effectful Source Fidelity Corpus"
kind: map
created: 2026-08-05
tags:
  - dataset
  - directory-index
  - evaluation
  - task-language
aliases: []
---

# Effectful Source Fidelity Corpus (`assets/effectful-source-fidelity/corpus`)

## Purpose

This directory freezes the 24 hand-authored semantic cases used to compare
`alang-source-v2` with `alang-task-json-v1`. Each family contains eight
variants, two source representations per case, and one representation-neutral
answer key. The manifest binds those files to content and semantic digests.

The semantic digest in an A-Lang file is corpus metadata before the
`model-visible-begin` marker. Phase 1 records the human-reviewed pairing;
Phase 2 must parse the visible source and independently reproduce the same
digest before any hosted trial can run.

## What belongs here

- Hand-authored candidate and control documents with equivalent detail.
- Closed answer keys independent of source origins and presentation order.
- One reviewed family×variant cell for every pre-registered case.
- A content-addressed manifest that rejects silent fixture edits.

Generated schedules, prompts, responses, and scores do not belong here.

## Index

### Subdirectories

- [Attenuated delegation](attenuated-delegation/README.md) — eight cases that
  test mechanically bounded child authority and parent-only publication.
- [Repair and publish](repair-and-publish/README.md) — eight cases that test an
  ordered generate, repair, validate, and publish workflow.
- [Single-model artifact](single-model-artifact/README.md) — eight cases that
  test one model generation followed by a bounded artifact write.

### Files

- [`corpus-manifest-v1.json`](corpus-manifest-v1.json) — inventories all 24
  reviewed pair cells and binds 48 representation documents plus 24 answer
  keys to their content and semantic SHA-256 digests.

## Maintaining this index

Do not alter a frozen case after the pre-registration digest is published.
Before that gate, update the manifest, family README, validators, and review
evidence together. A replacement corpus requires a new version and digest.
