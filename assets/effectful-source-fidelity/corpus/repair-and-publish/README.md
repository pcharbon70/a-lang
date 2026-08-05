---
title: "Repair-and-Publish Corpus"
kind: map
created: 2026-08-05
tags:
  - dataset
  - directory-index
  - model-repair
  - workspace-effects
aliases: []
---

# Repair-and-Publish Corpus (`corpus/repair-and-publish`)

## Purpose

This directory contains the eight repair-and-publish cases. Each case fixes an
ordered draft, structured repair, publication, and completion interpretation,
or a no-effect clarification terminal where validation input is absent.

## What belongs here

- One candidate, control, and representation-neutral answer key per variant.
- Exactly one bounded repair step between initial generation and publication.
- Explicit constraints, failure handling, hostile context boundaries, and
  perturbations that retain action order.

Provider responses and generated scores do not belong here.

## Index

### Subdirectories

- None yet.

### Files

- [`rap-simple.alang`](rap-simple.alang) — candidate source for the basic draft-repair-publish flow.
- [`rap-simple.json`](rap-simple.json) — typed-JSON control for the basic repair flow.
- [`rap-simple.answer.json`](rap-simple.answer.json) — semantic oracle for the simple case.
- [`rap-constraint-heavy.alang`](rap-constraint-heavy.alang) — candidate source for the constrained security-advisory flow.
- [`rap-constraint-heavy.json`](rap-constraint-heavy.json) — typed-JSON control for the constraint-heavy repair case.
- [`rap-constraint-heavy.answer.json`](rap-constraint-heavy.answer.json) — semantic oracle for the constraint-heavy case.
- [`rap-scope-budget.alang`](rap-scope-budget.alang) — candidate source with one repair and tightly bounded authority.
- [`rap-scope-budget.json`](rap-scope-budget.json) — typed-JSON control for the scope-and-budget repair case.
- [`rap-scope-budget.answer.json`](rap-scope-budget.answer.json) — semantic oracle for the scope-and-budget case.
- [`rap-error-branch.alang`](rap-error-branch.alang) — candidate source with invalid-repair and denied-publication branches.
- [`rap-error-branch.json`](rap-error-branch.json) — typed-JSON control for the error-branch repair case.
- [`rap-error-branch.answer.json`](rap-error-branch.answer.json) — semantic oracle for the error-branch case.
- [`rap-missing-information.alang`](rap-missing-information.alang) — candidate source that blocks draft and repair pending validation criteria.
- [`rap-missing-information.json`](rap-missing-information.json) — typed-JSON control for the missing-information repair case.
- [`rap-missing-information.answer.json`](rap-missing-information.answer.json) — semantic oracle for the missing-information case.
- [`rap-irrelevant-context.alang`](rap-irrelevant-context.alang) — candidate source that excludes superseded review notes.
- [`rap-irrelevant-context.json`](rap-irrelevant-context.json) — typed-JSON control for the irrelevant-context repair case.
- [`rap-irrelevant-context.answer.json`](rap-irrelevant-context.answer.json) — semantic oracle for the irrelevant-context case.
- [`rap-prompt-injection.alang`](rap-prompt-injection.alang) — candidate source that denies embedded validation bypasses.
- [`rap-prompt-injection.json`](rap-prompt-injection.json) — typed-JSON control for the prompt-injection repair case.
- [`rap-prompt-injection.answer.json`](rap-prompt-injection.answer.json) — semantic oracle for the prompt-injection case.
- [`rap-semantic-perturbation.alang`](rap-semantic-perturbation.alang) — declaration-reordered candidate retaining draft, repair, save, and finish order.
- [`rap-semantic-perturbation.json`](rap-semantic-perturbation.json) — key- and set-reordered typed-JSON control for the perturbation case.
- [`rap-semantic-perturbation.answer.json`](rap-semantic-perturbation.answer.json) — normalized semantic oracle for the perturbation case.

## Maintaining this index

Keep the repair budget and action dependency explicit in all non-clarification
cases. Update content hashes and the parent manifest for any pre-freeze edit;
version the corpus instead of mutating it after pre-registration.
