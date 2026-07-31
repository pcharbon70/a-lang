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
  eight-phase roadmap from frozen semantics and a native compiler skeleton to
  an end-to-end BEAM agent demonstration with typed effects, durable brokering,
  UCAN authorization, a bounded LLM loop, and falsifiable evaluation.

### Documents

- None yet.

## Maintaining this index

Assign the next unused two-digit prefix to each new planning stream. Link its
README here with its intended outcome, keep phase status inside that stream's
README current, and move obsolete plans to `90-archive` without reusing their
numbers.
