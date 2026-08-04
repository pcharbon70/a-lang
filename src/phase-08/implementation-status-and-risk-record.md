---
title: "Phase 8 Implementation Status and Risk Record"
kind: note
created: 2026-08-04
maturity: developing
tags:
  - beam
  - implementation-status
  - proof-of-concept
  - risk-management
aliases: []
---

# Phase 8 Implementation Status and Risk Record

## Supported environment and commands

The only declared acceptance environment is Erlang/OTP 29.0.4, ERTS 17.0.4,
`x86_64-pc-linux-gnu`, Rebar3 3.27.0, and PropEr 1.5.0. No compatibility claim
is made for another OTP release, architecture, or operating system.

```bash
make demo
make compare
make decide
make test-section-8-4
make test
```

The trusted compiler path uses BEAM-resident modules and OTP
`compile:forms/2` with strong validation and deterministic binary output. It
does not emit Erlang source, lower through Core Erlang, assemble raw BEAM, or
invoke a foreign compiler executable. PropEr and all reference evaluators are
test-only.

## Implemented architecture and versions

- The source frontend owns a bounded A-Lang module/task grammar, canonical ETF
  boundary, static checker, and typed task IR (`alang_typed_task_ir_v1`).
- The backend validates the A-Lang IR, lowers an allowlisted subset to Erlang
  Abstract Format, invokes the pinned OTP compiler in memory, and inspects the
  resulting fixed-module artifact.
- The runtime ABI uses closed versioned envelopes, a supervised task worker,
  effect gateway, bounded mailboxes and in-flight work, deadlines,
  cancellation, and normalized traces.
- The effect boundary uses a closed registry, opaque runtime-local grants,
  broker authorization, structural resource scopes, shared budgets, and an
  owned workspace sidecar.
- Durable sessions use versioned state, hash-chained journal records,
  checkpoints, generation fencing, stable operation identities,
  reconciliation, and explicit uncertainty.
- Model and child-task support uses a deterministic offline model protocol,
  context projection, bounded repair, a more-restricted supervised child, and
  evidence-backed completion.
- Validation uses BEAM-native EUnit and PropEr laws, state models, adversarial
  inputs, a 63-case fault matrix, pressure measurements, and 17 seeded defects.

The exact artifact metadata, effect ABI, grant, journal, model, child,
completion, comparison, decision, and release-record format atoms are asserted
by their owning modules and tests. They are proof-of-concept contracts, not a
long-term compatibility promise.

## Feature status ledger

| Feature | Status | Evidence or boundary |
| --- | --- | --- |
| BEAM-resident trusted compiler path | Implemented for the accepted subset | Phase 2/3 compiler, residency check, and artifact inspection |
| Pure A-Lang source task | Implemented | Counter source compiles and runs to result 42 |
| Products, results, branching, sequencing, calls, and closed effect nodes in typed IR | Implemented in IR/backend | Generated differential and law tests |
| Effectful A-Lang source syntax | Partial | Effects compile from promoted typed IR fixtures, not accepted source text |
| Runtime effects and local authority | Implemented locally | Broker/sidecar tests and Phase 8 direct-handler ablation |
| Durable workspace effect | Implemented for the local file-backed slice | Phase 5 recovery and Phase 8 verified artifact |
| Model completion | Partial | Deterministic offline mock only; live-provider gate remains disabled |
| More-restricted child task | Implemented as runtime/IR fixture | No source-level spawn construct |
| Categorical laws | Partial | Selected laws are executable; no formal proof or categorical advantage |
| Completion verification | Implemented for the Markdown workspace artifact | Digest, bound, syntax, section, and journal predicates |
| Supported release matrix | Partial | One pinned OTP/ERTS/architecture environment |
| Malicious generated-code isolation | Rejected as an in-process claim | BEAM processes are not a hostile-code sandbox |
| Deployable IR/reference evaluator | Rejected | Test-only and cannot satisfy execution gates |
| Core Erlang, raw BEAM, or foreign compiler backend | Rejected | Outside the supported compiler boundary |
| Portable delegation/UCAN | Deferred outside this PoC | Runtime-local opaque grants only |

## Security assumptions and risks

| Risk | Current consequence | Treatment |
| --- | --- | --- |
| Effectful source gap | The demo does not prove a complete user-facing language | Highest-priority next decision boundary; no manual IR in future acceptance tasks |
| Same-node code is trusted | A malicious BEAM module can exceed language-level intent | Generated imports are closed, but hostile execution requires a disposable OS sandbox |
| Workspace sidecar shares the host account | Path containment is not tenant isolation | Treat as a bounded adapter PoC, not a multi-tenant sandbox |
| Model adapter is a mock | Provider drift, latency, privacy, and failures are unmeasured | No live-provider reliability claim |
| File-backed durability is local | Disk loss, distributed races, and operational restore are untested | Keep production status rejected |
| One fixed generated module | Concurrent code-version and high-churn artifact operation are unresolved | Measure an artifact-cache/module-lifecycle design before broad workloads |
| One OTP environment | Backend maintenance across releases is unknown | Add an explicit compatibility matrix before release claims |
| Property and mutant selection are bounded | Passing tests do not constitute proof | Preserve falsifiable laws and label formal proof deferred |
| No human study | Authoring and reviewer benefits are unknown | Do not infer usability from line or field counts |

The [architecture decision](proof-of-concept-architecture-decision.md) retains
only claims that survive these limits. The [deferred-work ledger](deferred-work-ledger.md)
keeps expansion visible without treating it as implemented.
