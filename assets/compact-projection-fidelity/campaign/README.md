---
title: "Compact Projection Fidelity Campaign Inputs"
kind: map
created: 2026-08-12
tags:
  - archive-navigation
  - directory-index
  - evaluation
  - token-efficiency
aliases: []
---

# Compact Projection Fidelity Campaign Inputs (`assets/compact-projection-fidelity/campaign`)

## Purpose

This directory fixes the power assumptions, opaque case design, paired
factorial schedule, profiles, prompts, and operational bounds used to
materialize the compact projection campaign.

## What belongs here

- Pre-observation power scenarios and sample-size rules.
- Opaque semantic-case identities and balanced family/stratum assignments.
- Deterministic schedule, profile, tokenizer, prompt, and resource policies.

Semantic case content belongs in the sibling corpus directory once authored.
Generated schedules and evidence belong under ignored build paths.

## Index

### Subdirectories

- None yet.

### Files

- [`case-design-v1.json`](case-design-v1.json) — assigns 48 opaque
  confirmatory case identities across three runtime families, eight strata,
  and two independent replicates per family/stratum cell.
- [`power-design-v1.json`](power-design-v1.json) — freezes optimistic, central,
  and adverse paired-discordance scenarios, the five-point margin, 80% central
  power requirement, and balanced 24-case expansion rule.
- [`schedule-policy-v1.json`](schedule-policy-v1.json) — freezes condition
  eligibility, models, repetitions, seed, 2,304 primary cells, and the 4,608
  hard request ceiling selected after the power audit.

## Maintaining this index

Do not tune power assumptions or schedule factors from campaign observations.
After preregistration, create a new version for any change to cases, factors,
seed, identities, profiles, prompts, or ceilings.
