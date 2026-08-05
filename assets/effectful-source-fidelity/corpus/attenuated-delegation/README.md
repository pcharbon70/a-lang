---
title: "Attenuated-Delegation Corpus"
kind: map
created: 2026-08-05
tags:
  - capability-attenuation
  - dataset
  - directory-index
  - subagents
aliases: []
---

# Attenuated-Delegation Corpus (`corpus/attenuated-delegation`)

## Purpose

This directory contains the eight attenuated-delegation cases. In every
effectful case the parent owns publication authority while one child receives
only the bounded model requirement, scope, and budget needed to draft content.

## What belongs here

- One candidate, control, and semantic oracle per required variant.
- Parent/child authority and budget records that mechanically prohibit
  widening and recursive delegation.
- Missing-input, hostile-context, error, and presentation-perturbation cases.

Live child processes and generated campaign evidence do not belong here.

## Index

### Subdirectories

- None yet.

### Files

- [`ad-simple.alang`](ad-simple.alang) — candidate source for one attenuated child and parent publication.
- [`ad-simple.json`](ad-simple.json) — typed-JSON control for the basic delegation case.
- [`ad-simple.answer.json`](ad-simple.answer.json) — semantic oracle for the simple case.
- [`ad-constraint-heavy.alang`](ad-constraint-heavy.alang) — candidate source with title, encoding, size, and authority constraints.
- [`ad-constraint-heavy.json`](ad-constraint-heavy.json) — typed-JSON control for the constraint-heavy delegation case.
- [`ad-constraint-heavy.answer.json`](ad-constraint-heavy.answer.json) — semantic oracle for the constraint-heavy case.
- [`ad-scope-budget.alang`](ad-scope-budget.alang) — candidate source with tight parent and child budgets and scopes.
- [`ad-scope-budget.json`](ad-scope-budget.json) — typed-JSON control for the scope-and-budget delegation case.
- [`ad-scope-budget.answer.json`](ad-scope-budget.answer.json) — semantic oracle for the scope-and-budget case.
- [`ad-error-branch.alang`](ad-error-branch.alang) — candidate source with child denial, timeout, and publication denial branches.
- [`ad-error-branch.json`](ad-error-branch.json) — typed-JSON control for the error-branch delegation case.
- [`ad-error-branch.answer.json`](ad-error-branch.answer.json) — semantic oracle for the error-branch case.
- [`ad-missing-information.alang`](ad-missing-information.alang) — candidate source that creates no child before clarification.
- [`ad-missing-information.json`](ad-missing-information.json) — typed-JSON control for the missing-information delegation case.
- [`ad-missing-information.answer.json`](ad-missing-information.answer.json) — semantic oracle for the missing-information case.
- [`ad-irrelevant-context.alang`](ad-irrelevant-context.alang) — candidate source that excludes obsolete notes from child context.
- [`ad-irrelevant-context.json`](ad-irrelevant-context.json) — typed-JSON control for the irrelevant-context delegation case.
- [`ad-irrelevant-context.answer.json`](ad-irrelevant-context.answer.json) — semantic oracle for the irrelevant-context case.
- [`ad-prompt-injection.alang`](ad-prompt-injection.alang) — candidate source that denies embedded requests for wider child authority.
- [`ad-prompt-injection.json`](ad-prompt-injection.json) — typed-JSON control for the prompt-injection delegation case.
- [`ad-prompt-injection.answer.json`](ad-prompt-injection.answer.json) — semantic oracle for the prompt-injection case.
- [`ad-semantic-perturbation.alang`](ad-semantic-perturbation.alang) — declaration-reordered candidate retaining delegation and publication order.
- [`ad-semantic-perturbation.json`](ad-semantic-perturbation.json) — key- and set-reordered typed-JSON control for the perturbation case.
- [`ad-semantic-perturbation.answer.json`](ad-semantic-perturbation.answer.json) — normalized semantic oracle for the perturbation case.

## Maintaining this index

Keep child effects, requirements, scopes, and every budget no greater than the
parent values. Update the parent manifest with any pre-freeze edit and create a
new version after the pre-registration digest is published.
