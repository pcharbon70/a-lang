---
title: "Token-Positive Mnemonic Promotion Section 3.2 Readiness Evidence"
kind: note
created: 2026-08-28
maturity: developing
tags:
  - campaign-replay
  - implementation-evidence
  - safety
  - token-efficiency
aliases: []
---

# Token-Positive Mnemonic Promotion Section 3.2 Readiness Evidence

## Deterministic observation records

The observation normalizer accepts only a definitive result bound to the exact
operation, trial, and model. It requires nonestimated nonnegative prompt,
output, and total token counts, verifies exact arithmetic and response bytes,
and retains the first response and digest. Comprehension, generation,
diagnostic-repair, and action/completion outputs feed the frozen deterministic
scorer without a model judge or corrective prompt.

Safety classification compares effects, scopes, budgets, child attenuation,
error behavior, completion predicates, and terminal class with the semantic
oracle. Paired records bind P0 and P1 by case, model family, protocol, and
repetition, retain provider input and total tokens, and make P1-only safety
failures explicit.

## Offline replay

The replay module rejects gaps, duplicates, unscheduled identities, invalid
observation digests, and unpaired conditions. It sorts by registered cell
index and reproduces separate response, usage, score, safety, pair, and final
replay digests using retained records alone. Four Section 3.2 tests cover
exact scoring, invalid usage forms, candidate-only budget widening, paired
token records, deterministic ordering, gaps, and duplicates.

## Evidence boundary

These tests use deterministic response fixtures. They prove the scorer and
offline replay implementation are ready, but they are not efficacy
observations and cannot complete Section 3.2. The live-model prerequisite from
[Section 3.1 readiness evidence](section-03-01-readiness-evidence.md) remains
closed, so all hosted-observation completion boxes remain unchecked.

## Connections

- [Phase 3 plan](../../60-planning/04-token-positive-mnemonic-promotion/phase-03-authorized-two-model-campaign.md)
  defines the authoritative provider-usage and safety evidence requirements.
- [Campaign roadmap](../../60-planning/04-token-positive-mnemonic-promotion/README.md)
  reserves the ordered promotion decision for Phase 4.
