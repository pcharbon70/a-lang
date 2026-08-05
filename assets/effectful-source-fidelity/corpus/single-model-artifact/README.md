---
title: "Single-Model Artifact Corpus"
kind: map
created: 2026-08-05
tags:
  - dataset
  - directory-index
  - model-generation
  - workspace-effects
aliases: []
---

# Single-Model Artifact Corpus (`corpus/single-model-artifact`)

## Purpose

This directory contains the eight single-model artifact cases. Each case has
one hand-authored A-Lang candidate, one typed-JSON control, and one independent
answer key bound together by the parent corpus manifest.

## What belongs here

- One candidate, control, and oracle for each required variant.
- Tasks with at most one model generation followed by bounded parent workspace
  publication, or a no-effect clarification terminal where input is missing.
- Equivalent semantics with intentionally varied presentation order where the
  perturbation design calls for it.

Pair manifests and generated trial material do not belong here.

## Index

### Subdirectories

- None yet.

### Files

- [`sma-simple.alang`](sma-simple.alang) — candidate source for the basic release-note artifact.
- [`sma-simple.json`](sma-simple.json) — typed-JSON control for the basic release-note artifact.
- [`sma-simple.answer.json`](sma-simple.answer.json) — semantic oracle for the simple case.
- [`sma-constraint-heavy.alang`](sma-constraint-heavy.alang) — candidate source with title, encoding, size, and factual constraints.
- [`sma-constraint-heavy.json`](sma-constraint-heavy.json) — typed-JSON control for the constraint-heavy case.
- [`sma-constraint-heavy.answer.json`](sma-constraint-heavy.answer.json) — semantic oracle for the constraint-heavy case.
- [`sma-scope-budget.alang`](sma-scope-budget.alang) — candidate source with tight model, workspace, path, time, and output bounds.
- [`sma-scope-budget.json`](sma-scope-budget.json) — typed-JSON control for the scope-and-budget case.
- [`sma-scope-budget.answer.json`](sma-scope-budget.answer.json) — semantic oracle for the scope-and-budget case.
- [`sma-error-branch.alang`](sma-error-branch.alang) — candidate source with timeout and denied-write terminal branches.
- [`sma-error-branch.json`](sma-error-branch.json) — typed-JSON control for the error-branch case.
- [`sma-error-branch.answer.json`](sma-error-branch.answer.json) — semantic oracle for the error-branch case.
- [`sma-missing-information.alang`](sma-missing-information.alang) — candidate source that requires clarification without effects.
- [`sma-missing-information.json`](sma-missing-information.json) — typed-JSON control for the missing-information case.
- [`sma-missing-information.answer.json`](sma-missing-information.answer.json) — semantic oracle for the missing-information case.
- [`sma-irrelevant-context.alang`](sma-irrelevant-context.alang) — candidate source that excludes an optional historical memo.
- [`sma-irrelevant-context.json`](sma-irrelevant-context.json) — typed-JSON control for the irrelevant-context case.
- [`sma-irrelevant-context.answer.json`](sma-irrelevant-context.answer.json) — semantic oracle for the irrelevant-context case.
- [`sma-prompt-injection.alang`](sma-prompt-injection.alang) — candidate source that treats embedded instructions as untrusted data.
- [`sma-prompt-injection.json`](sma-prompt-injection.json) — typed-JSON control for the prompt-injection case.
- [`sma-prompt-injection.answer.json`](sma-prompt-injection.answer.json) — semantic oracle for the prompt-injection case.
- [`sma-semantic-perturbation.alang`](sma-semantic-perturbation.alang) — candidate with reordered set-like declarations and unchanged ordered actions.
- [`sma-semantic-perturbation.json`](sma-semantic-perturbation.json) — key- and set-reordered typed-JSON control for the perturbation case.
- [`sma-semantic-perturbation.answer.json`](sma-semantic-perturbation.answer.json) — normalized semantic oracle for the perturbation case.

## Maintaining this index

Keep exactly one candidate, control, and answer key per variant. Update the
parent manifest and rerun the BEAM corpus validator after any pre-freeze edit;
after pre-registration, introduce a new corpus version instead.
