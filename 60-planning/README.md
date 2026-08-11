---
title: "Implementation Planning"
kind: map
created: 2026-07-31
tags:
  - archive-navigation
  - directory-index
  - implementation-planning
aliases:
  - "Planning index"
---

# Implementation Planning (`60-planning`)

## Purpose

This directory turns the archive's research conclusions into staged,
testable implementation roadmaps. Plans belong here when they define an
ordered delivery path, explicit dependencies, completion gates, and evidence
needed to accept or reject an implementation hypothesis.

## What belongs here

- Numbered planning streams that can be followed in the order they were
  introduced.
- Phase documents with numbered sections, tasks, and subtasks.
- Completion criteria, dependency graphs, traceability, and decision gates.
- Plans that connect implementation work back to research notes and active
  inquiries.

Planning-stream directories use a zero-padded numeric prefix followed by a
descriptive kebab-case name:

```text
01-minimal-proof-of-concept/
02-next-planning-stream/
```

Numbers are historical sequence identifiers. Do not renumber an existing
planning stream when another plan is added, removed, completed, or archived.
Phase numbering restarts inside each planning stream.

## Index

### Subdirectories

- [01 — Minimal proof of concept](01-minimal-proof-of-concept/README.md) — an
  eight-phase BEAM-first roadmap from a directly executing ERTS vertical slice
  through the BEAM-resident compiler frontend, typed effects, local capability brokering,
  durable recovery, a bounded LLM loop, and falsifiable evaluation.
- [02 — Effectful source fidelity](02-effectful-source-fidelity/README.md) — a
  six-phase successor that holds the BEAM runtime constant while comparing
  user-authored effectful A-Lang with semantically matched typed JSON across
  two hosted model families and a frozen promote, replace, or stop rule.
- [03 — Compact projection fidelity](03-compact-projection-fidelity/README.md)
  — a six-phase, separately preregistered campaign comparing readable A-Lang
  with layout, mnemonic, checked-compact, opaque-identifier, and typed-JSON
  conditions across comprehension, generation, repair, and safe operational
  judgment before any model projection can be promoted.

### Documents

- None yet.

## Maintaining this index

Assign the next unused two-digit prefix to each new planning stream. Link its
README here with its intended outcome, keep phase status inside that stream's
README current, and move obsolete plans to `90-archive` without reusing their
numbers.
