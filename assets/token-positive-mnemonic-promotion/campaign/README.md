---
title: "Token-Positive Mnemonic Promotion Campaign Inputs"
kind: map
created: 2026-08-27
tags:
  - directory-index
  - experiment-design
  - token-efficiency
aliases: []
---

# Token-Positive Mnemonic Promotion Campaign Inputs (`assets/token-positive-mnemonic-promotion/campaign`)

## Purpose

This directory freezes the pre-observation power, case design, model and
tokenizer profiles, prompt policy, schedule, and operational bounds for the
exact-R2 P0/P1 campaign.

## What belongs here

- Inputs fixed before any model-visible request.
- Exact model, tokenizer, prompt, seed, schedule, replacement, and retention
  rules.
- Design records that remain distinct from efficacy observations.

## Index

### Subdirectories

- None yet.

### Files

- [Campaign policy](campaign-policy-v1.json) — disables network access by
  default and freezes authorization, availability, request, replacement,
  retention, compute, and invalidation bounds.
- [Case design](case-design-v1.json) — balances 48 fresh cases across three
  runtime families, eight strata, and two semantic replicates.
- [Power design](power-design-v1.json) — registers the paired case-cluster
  simulation, five-point margin, 80% floor, and 24-case expansion blocks.
- [Prompt policy](prompt-policy-v1.json) — freezes common and protocol
  instructions, P0/P1 legends, output contracts, and leakage exclusions.
- [Provider profiles](provider-profiles-v1.json) — retains the exact Ornith and
  Mixtral Ollama IDs, manifest hashes, and request parameters.
- [Schedule policy](schedule-policy-v1.json) — freezes the 1,536-cell paired
  factorial schedule, seed, counterbalance dimensions, and 3,072-request cap.
- [Tokenizer profiles](tokenizer-profiles-v1.json) — retains the exact two
  offline screening identities and authoritative provider-usage rule.

## Maintaining this index

Do not revise a campaign input after the registration digest or any model
observation. Add a new version and keep old evidence segregated.
