---
title: "Phase 7 Adversarial Boundary Testing"
kind: note
created: 2026-08-04
maturity: developing
tags:
  - adversarial-testing
  - capability-security
  - fuzz-testing
  - runtime-validation
aliases: []
---

# Phase 7 Adversarial Boundary Testing

## Implemented boundary inventory

The campaign attacks the A-Lang lexer and parser, canonical ETF decoder,
typed-IR validator, Abstract Format validator, BEAM inspector, runtime ABI,
closed effect registry, opaque grant store, workspace path and adapter seal,
model request validator, and context slicer. The current PoC has no JSON
parser, so the roadmap's generic JSON item is not applicable; adding one later
must also add it to this inventory.

Random inputs are bounded and every boundary is called behind an exception
classifier. A rejection must be typed and must not crash the test VM. Targeted
cases separately cover the one-mebibyte limits, modified BEAM headers and
containers, deep or over-count context, unknown binary operations, and
dynamic-dispatch-shaped terms.

## Security attacks

- Guessed and altered grant references, wrong sessions, scope and budget
  widening, revocation, and generation replacement fail closed.
- Absolute, parent, empty-segment, backslash, dot, and normalization-sensitive
  workspace paths are rejected before adapter execution.
- Calls with the wrong adapter seal leave the workspace event log empty.
- Retrieved prompt-injection text remains `data_only`; private material is
  excluded; runtime identities are rejected from model requests.
- Model output that names grant-management operations remains inert output
  data and cannot invoke the broker.

The atom-table gate warms the closed registry, submits one thousand distinct
unknown binary operations, and requires an unchanged atom count. The leak gate
scans model-visible context snapshots and request surfaces for PIDs,
references, ports, and the private fixture marker.

## Reproduce

```bash
make test-section-7-3
```

This campaign extends the [Phase 7 plan](../../60-planning/01-minimal-proof-of-concept/phase-07-law-security-fault-and-performance-validation.md)
and reuses the declared limits in the [source surface](../phase-02/language-surface.md),
[artifact contract](../phase-03/artifact-contract.md), and
[workspace adapter contract](../phase-04/workspace-adapter-contract.md).
