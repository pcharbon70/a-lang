---
title: "Effectful Source Fidelity Campaign"
kind: map
created: 2026-08-05
tags:
  - directory-index
  - evaluation
  - llm-agents
  - provider-contract
aliases: []
---

# Effectful Source Fidelity Campaign (`assets/effectful-source-fidelity/campaign`)

## Purpose

This directory freezes the model profiles, operational ceilings, evidence
retention policy, and representation-neutral prompt used by the fidelity
experiment. These files configure a future opt-in hosted campaign; they do not
authorize network access in the default build or test suite.

## What belongs here

- Exact provider API and model identifiers with one-turn request bounds.
- Explicit live-call consent, credential, retry, cost, and call ceilings.
- Redacted evidence retention and uncertain-outcome classification.
- One prompt template shared by both source conditions without examples or
  condition labels.

Credentials, provider responses, and generated trial schedules do not belong
here.

## Index

### Subdirectories

- None yet.

### Files

- [`campaign-policy-v1.json`](campaign-policy-v1.json) — disables networking
  by default and freezes consent, credential names, 288/576 call ceilings, the
  USD 200 ceiling, repair/retry/replacement rules, uncertainty classes, and
  redacted evidence retention.
- [`prompt-template-v1.txt`](prompt-template-v1.txt) — the shared, example-free
  comprehension prompt with one task-specification insertion boundary.
- [`provider-profiles-v1.json`](provider-profiles-v1.json) — pins the OpenAI
  Responses and Anthropic Messages profiles, exact model IDs, medium effort,
  one turn, no tools or schema constraint, and 8,192-token/byte bounds.

## Maintaining this index

Treat every file as pre-registration input. Change a profile, threshold,
prompt, or retention rule only through a new version and a newly reviewed
pre-registration digest; never place credentials in this directory.
