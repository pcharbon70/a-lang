---
title: "Compact Projection Fidelity Tokenizers"
kind: map
created: 2026-08-12
tags:
  - beam
  - directory-index
  - token-efficiency
  - tokenizer
aliases: []
---

# Compact Projection Fidelity Tokenizers (`tokenizers`)

## Purpose

This directory pins the mergeable ranks and Unicode pre-tokenizer definitions
that the trusted Erlang tokenizer reproduces for offline document screening.

## What belongs here

- Canonical vocabulary files with registered SHA-256 digests.
- Exact tokenizer identities, bounds, and pre-tokenizer patterns.
- Small primary-implementation conformance vectors used by BEAM tests.

Provider-reported usage remains authoritative for live provider and full-
request metrics; these assets support exact offline screening counts.

## Index

### Subdirectories

- None yet.

### Files

- [`cl100k_base.tiktoken`](cl100k_base.tiktoken) — the 100,256-entry official
  `cl100k_base` mergeable-rank vocabulary, SHA-256
  `223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7`,
  retrieved 2026-08-12 from the
  [canonical OpenAI asset](https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken).
- [`o200k_base.tiktoken`](o200k_base.tiktoken) — the 199,998-entry official
  `o200k_base` mergeable-rank vocabulary, SHA-256
  `446a9538cb6c348e3516120d7c08b09f57c36495e2acfffe59a5bf8b0cfb1a2d`,
  retrieved 2026-08-12 from the
  [canonical OpenAI asset](https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken).
- [`tokenizer-conformance-v1.json`](tokenizer-conformance-v1.json) — exact
  token-ID vectors for ASCII, A-Lang, Unicode, combining-mark, and emoji text.
- [`tokenizer-runtime-v1.json`](tokenizer-runtime-v1.json) — pins the native
  implementation, vocabulary metadata, pre-tokenizer regexes, and bounds.
- [`tokenizer-runtime-v1.schema.json`](tokenizer-runtime-v1.schema.json) — the
  closed schema for the runtime registration and conformance reference.

## Maintaining this index

Verify vocabulary bytes against their registered digest before use. Never add
an encoding alias: callers must select the complete registered profile ID.
