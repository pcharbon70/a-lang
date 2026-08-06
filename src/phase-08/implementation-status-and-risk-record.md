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
- The successor fidelity stream adds a closed `alang-source-v2` effectful
  frontend, an independent `alang-task-json-v1` frontend, matched v2 IR,
  inspected BEAM execution, fixed provider adapters, and deterministic
  campaign analysis. Its hosted campaign was closed invalid before any call.

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
| Effectful A-Lang source syntax | Implemented for the frozen experimental subset | All 24 source cases parse, check, lower, compile, and execute through inspected BEAM; the surface is frozen because comparative fidelity was not measured |
| Runtime effects and local authority | Implemented locally | Broker/sidecar tests and Phase 8 direct-handler ablation |
| Durable workspace effect | Implemented for the local file-backed slice | Phase 5 recovery and Phase 8 verified artifact |
| Model completion | Partial | Deterministic offline model plus fixed, fault-tested provider adapters; zero hosted calls and no provider-behavior evidence |
| More-restricted child task | Implemented for the frozen source/runtime subset | Source-declared child attenuation lowers to the existing supervised restricted-child boundary |
| User-facing task notation | Stopped | Invalid hosted campaign produced no A-Lang-versus-JSON efficacy result; both authoring paths remain experimental and frozen |
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
| Source-notation value is unmeasured | The closed source subset exists, but no hosted campaign tested whether models recover it better than typed JSON | Freeze both authoring paths; any later comparison requires a newly authorized and pre-registered stream |
| Same-node code is trusted | A malicious BEAM module can exceed language-level intent | Generated imports are closed, but hostile execution requires a disposable OS sandbox |
| Workspace sidecar shares the host account | Path containment is not tenant isolation | Treat as a bounded adapter PoC, not a multi-tenant sandbox |
| Hosted provider behavior is unmeasured | Fixed adapters pass offline faults, but availability, output, latency, price, privacy, and drift were never observed | No efficacy or live-provider reliability claim; do not infer from fixtures |
| File-backed durability is local | Disk loss, distributed races, and operational restore are untested | Keep production status rejected |
| One fixed generated module | Concurrent code-version and high-churn artifact operation are unresolved | Measure an artifact-cache/module-lifecycle design before broad workloads |
| One OTP environment | Backend maintenance across releases is unknown | Add an explicit compatibility matrix before release claims |
| Property and mutant selection are bounded | Passing tests do not constitute proof | Preserve falsifiable laws and label formal proof deferred |
| No human study | Authoring and reviewer benefits are unknown | Do not infer usability from line or field counts |

The [architecture decision](proof-of-concept-architecture-decision.md) retains
only claims that survive these limits. The [deferred-work ledger](deferred-work-ledger.md)
keeps expansion visible without treating it as implemented. The successor
[fidelity decision](../effectful-source-fidelity/effectful-source-fidelity-architecture-decision.md)
records why the authoring surfaces did not advance.
