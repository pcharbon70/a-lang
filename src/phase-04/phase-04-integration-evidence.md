---
title: "Phase 4 Capability and Effect Integration Evidence"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - beam
  - capability-security
  - effect-systems
  - integration-testing
aliases: []
---

# Phase 4 Capability and Effect Integration Evidence

## Claim under test

An inspected A-Lang artifact compiled by the BEAM-resident toolchain can run as
a supervised BEAM process, request one manifest-declared workspace effect
through the versioned runtime ABI, resolve an opaque local grant in the BEAM
broker, and receive the digest produced by the isolated BEAM sidecar. Generated
code must not import the broker or adapter, and denied requests must not reach
the external-effect boundary.

## Reproduction

Run:

```text
make test-section-4-5
```

The target first reruns Sections 4.1–4.4, rebuilds the Phase 3 toolchain after
the contextual handler extension, and then runs
`alang_phase4_integration_tests` on OTP 29.

## Authorized path

The integration fixture constructs typed A-Lang IR containing
`workspace.write`. The Phase 3 backend lowers it to the fixed generated module,
OTP performs strong validation and deterministic BEAM compilation, and the
artifact inspector verifies its metadata and closed imports before loading.

At execution time the generated task sends only the registry identity and
tagged arguments to `alang_phase3_abi`. The supervised gateway contributes the
session, task, correlation, deadline, requester, and source context. A
three-argument trusted handler adds the inspected artifact digest and opaque
grant, then calls the broker. The broker decodes, checks the artifact manifest,
resolves the grant, validates scope, budget, deadline, cancellation, and policy,
and dispatches through its private adapter seal. The generated task receives
only the artifact digest in its typed result.

The test correlates the runtime trace, authorization audit, adapter events,
remaining budget, output path, content digest, ERTS process snapshots, loaded
artifact identity, and `.beam` paths of every trusted compiler and runtime
module. Artifact import inspection proves that generated code cannot call the
broker or adapter module directly.

## Rejection matrix

The integration suite exercises forged, stale, wrong-session, out-of-scope,
exhausted, expired, revoked, undeclared, and policy-denied requests. It also
discovers the adapter PID without its private seal and compiles a malicious
generated module that imports the adapter directly.

For denials before dispatch, the adapter event count and workspace remain
unchanged and the grant budget is preserved. An exhausted retry cannot replace
the file created by the one authorized attempt. A broker restart changes both
runtime instance and generation, loses all grants, rejects the stale reference,
and does not replay it. The direct adapter call is denied by the seal, while
artifact inspection rejects the direct module import before loading.

## Boundary of the evidence

This evidence establishes a local, in-memory Phase 4 authority boundary. It
does not claim crash-safe effect identity, grant restoration, or durable
recovery. Those mechanisms remain planned for Phase 5. The OS adapter is a
bounded external effect sidecar running a fixed BEAM module; it is neither a
foreign compiler component nor an interpreter for A-Lang source or IR.

See the [workspace adapter contract](workspace-adapter-contract.md), the
[Phase 4 implementation index](README.md), and the
[Phase 4 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-04-local-capability-broker-and-effect-boundary.md).
