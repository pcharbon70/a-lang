---
title: "A-Lang Minimal Proof-of-Concept Plan"
kind: map
created: 2026-07-31
tags:
  - beam
  - implementation-planning
  - proof-of-concept
aliases:
  - "A-Lang PoC roadmap"
---

# A-Lang Minimal Proof-of-Concept Plan (`01-minimal-proof-of-concept`)

## Purpose

This directory defines the first end-to-end implementation roadmap for
A-Lang. Its purpose is to test one architectural claim: a new agent language
can own its syntax and typed semantic IR while both its trusted compiler
toolchain and generated programs execute directly as BEAM code on ERTS.

The plan is BEAM-first. Phase 1 must produce a generated `.beam` artifact,
load it into an isolated ERTS node, spawn it as a process, exchange the closed
runtime messages, and observe its result and termination. A host-language AST
or IR evaluator, Erlang source evaluator, simulator, or mocked execution path
cannot satisfy that gate.

## What belongs here

- Ordered implementation phases for the minimal BEAM-executed vertical slice.
- Sections, tasks, subtasks, dependencies, and observable completion evidence.
- Explicit language, compiler, runtime, capability, durability, model, tool,
  child-task, validation, and decision boundaries.
- Links to the research claims and inquiries that implementation must test.

Production code belongs in [`src`](../../src/README.md). Reproducible evidence
belongs with the phase or test suite that produces it. Broader feature ideas,
portable delegation protocols, distribution, and production hardening remain
outside this proof of concept.

## Architectural contract

The following statements are non-negotiable for this roadmap:

1. The entire trusted A-Lang compiler toolchain—lexer, parser, resolver,
   checker, IR passes, backend adapter, command driver, and validators—executes
   as BEAM modules on ERTS.
2. A-Lang programs execute as separate BEAM modules and ERTS processes.
3. The source language, static semantics, typed IR, and runtime-visible
   behavior belong to A-Lang rather than Erlang, Elixir, Gleam, or another
   BEAM language.
4. The supported production compiler boundary is Erlang Abstract Format plus
   the pinned OTP compiler; Core Erlang and direct BEAM emission are research
   paths only.
5. Erlang source may bootstrap A-Lang compiler and runtime modules, but it may
   not be generated from accepted A-Lang source or interpret A-Lang AST/IR.
6. A Rust, C, C++, Zig, Go, or other foreign executable may not own a trusted
   compiler pass. Ports and sidecars remain allowed only for bounded external
   runtime effects outside the compiler path.
7. Any independent evaluator is a test oracle only. It cannot be deployed as
   the execution engine or used to satisfy an end-to-end phase gate.
8. Generated code reaches models, tools, storage, and the filesystem only
   through a closed, typed, supervised runtime ABI.
9. Capability references are opaque and local to the issuing BEAM runtime.
   Portable signed delegation is not part of this proof of concept.
10. BEAM supervision provides fault topology, not durable progress or exactly
   once effects; checkpoints, journals, idempotency, and recovery stay
   explicit.
11. BEAM process isolation is not a security sandbox. Untrusted tools, model
   services, and foreign code remain behind OS-bounded ports or sidecars.
12. Completion means reproducible evidence against stated gates, not a stub,
    successful compilation alone, or a happy-path demonstration.

## Research baseline

- [BEAM runtime synthesis](../../20-notes/beam-runtime-for-native-agent-language.md)
  defines the compiler boundary, ERTS execution model, runtime ABI, security
  limits, and PropEr-based validation strategy.
- [BEAM feasibility inquiry](../../40-inquiries/can-beam-support-a-native-agent-language.md)
  supplies compatibility, correctness, durability, performance, and isolation
  falsification criteria.
- [Set and category principles](../../20-notes/set-and-category-principles-for-agent-programming-language.md)
  defines the typed composition, effect, capability, state, and law-testing
  hypotheses.
- [Categorical feasibility inquiry](../../40-inquiries/can-categorical-semantics-improve-agent-language.md)
  requires comparison against a conventional typed IR rather than assuming
  category-specific value.
- [LLM task-language synthesis](../../20-notes/llm-agent-task-languages-deep-dive.md)
  motivates separating declarative intent, deterministic control, model
  judgment, effects, and completion evidence.
- [Task-language feasibility inquiry](../../40-inquiries/can-a-task-language-improve-llm-agents.md)
  supplies semantic-fidelity and runtime-enforcement comparisons.

## Minimal end-to-end result

The final demonstrator compiles one A-Lang task into a validated `.beam`
artifact and runs it as a supervised ERTS process. The task:

1. receives typed input through the versioned BEAM runtime ABI;
2. requests one bounded model completion through an isolated adapter;
3. decodes and validates the model output into a closed result type;
4. may spawn one more-restricted child A-Lang task as a supervised BEAM
   process;
5. requests one workspace write through an opaque local capability reference;
6. records effect intent, result, checkpoint, and completion evidence;
7. survives injected process, adapter, and node failure without duplicating
   the logical workspace effect; and
8. returns a typed result, artifact digest, and auditable normalized trace.

The model never selects arbitrary functions, sees a capability reference, or
controls a module, atom, filesystem path root, budget counter, process address,
or completion decision.

## Compiler and runtime shape

```text
A-Lang source
  -> BEAM-resident lexer, parser, resolver, and type/effect checker
  -> small A-Lang-owned typed task IR
  -> BEAM-resident actor, state-machine, and runtime-operation lowering
  -> BEAM-resident pinned Erlang Abstract Format adapter
  -> OTP strong validation and deterministic compilation
  -> inspected and manifested .beam artifact
  -> ERTS load and supervised BEAM process execution

session supervisor
  ├─ generated A-Lang coordinator process
  ├─ bounded inbox and admission process
  ├─ local capability and effect broker
  ├─ trace and provenance process
  ├─ checkpoint and journal adapter
  └─ OS-bounded model, tool, and workspace adapters
```

Core Erlang may inform the language IR or support experiments, but it is not
the production compiler ABI. Direct BEAM assembly and hand-written `.beam`
files are outside the minimal implementation path.

## Scope boundaries

### Included

- one pinned OTP compiler and ERTS runtime pair;
- a small BEAM-resident A-Lang compiler frontend and typed task IR;
- products, coproducts, results, pure arrows, sequential tasks, closed effects,
  local capability requirements, and one coalgebraic agent loop;
- Abstract Format lowering, artifact validation, manifests, loading, and
  source-level diagnostics;
- generated BEAM coordinators and a supervised runtime ABI;
- one opaque local capability broker and one workspace effect;
- explicit intent/result journaling, checkpointing, recovery, and idempotency;
- one mock-first bounded model adapter and one more-restricted child task;
- differential, property, state-machine, security, fault, and performance
  evidence; and
- one final accept, revise, or reject decision for each major architectural
  hypothesis.

### Excluded

- an Erlang, Elixir, Gleam, or other BEAM-language interpreter for A-Lang;
- Core Erlang or raw BEAM emission as the production compiler boundary;
- portable authorization, signed delegation, distributed proof chains, or
  cross-trust-domain identity;
- arbitrary user module calls, dynamic apply, unbounded atom creation, NIFs,
  and in-process untrusted code;
- transparent Erlang distribution as a security boundary;
- parallel composition before non-interference semantics are validated;
- recursive or general-purpose language features not required by the slice;
- live-provider reliability claims based only on mock fixtures;
- hot upgrade, multi-node scheduling, package management, self-hosting, and
  production release engineering; and
- claims that property tests constitute formal proof.

## Status and evidence rules

- Every phase, section, task, and subtask starts as planned and unchecked.
- Complete subtasks only with reviewable implementation and reproducible test
  or inspection evidence.
- Complete a task only when all subtasks and the task's stated observable
  result pass.
- Complete a section only when its integration claim survives negative tests.
- Complete a phase only when its final numbered integration-test section and
  phase evidence checklist pass from a clean checkout.
- A host evaluator may support differential testing but can never substitute
  for BEAM execution evidence.
- A process restart does not count as durable recovery unless persisted state
  and uncertain effects reconcile under the declared semantics.
- A generated artifact does not count as safe merely because OTP accepts it;
  imports, manifests, ABI versions, resource limits, and isolation must also
  pass.

## Index

### Subdirectories

- None yet.

### Documents

- [Phase 1 — BEAM-executable vertical slice](phase-01-beam-executable-vertical-slice.md)
  — proves the architecture immediately by compiling, loading, spawning, and
  observing a generated A-Lang program on ERTS with no interpreter substitute.
- [Phase 2 — BEAM-resident compiler frontend and typed task IR](phase-02-native-frontend-and-typed-task-ir.md)
  — implements A-Lang syntax and static semantics as BEAM compiler modules and
  connects them to the already-proven BEAM artifact path.
- [Phase 3 — Erlang Abstract Format and BEAM runtime kernel](phase-03-erlang-abstract-format-and-beam-runtime-kernel.md)
  — generalizes lowering, artifact validation, actor semantics, supervision,
  bounded messaging, cancellation, and diagnostics.
- [Phase 4 — Local capability broker and effect boundary](phase-04-local-capability-broker-and-effect-boundary.md)
  — adds closed effects, opaque runtime-local grants, a supervised BEAM
  reference monitor, and one OS-bounded workspace adapter.
- [Phase 5 — Durable BEAM sessions and recovery](phase-05-durable-beam-sessions-and-recovery.md)
  — adds explicit state versions, intent/result journaling, checkpoints,
  generation fencing, local grant restoration, and crash recovery.
- [Phase 6 — Bounded LLM task and subagent execution](phase-06-bounded-llm-task-and-subagent-execution.md)
  — adds typed model judgments, repair limits, context projection, one
  more-restricted child BEAM process, and verifier-backed completion.
- [Phase 7 — Law, security, fault, and performance validation](phase-07-law-security-fault-and-performance-validation.md)
  — tests categorical and local capability laws, differential semantics,
  adversarial inputs, fault matrices, resource bounds, and seeded mutations.
- [Phase 8 — End-to-end demonstration and PoC decision](phase-08-end-to-end-demonstration-and-poc-decision.md)
  — runs the complete BEAM-native scenario, compares simpler baselines, and
  records evidence-backed accept, revise, or reject decisions.

## Dependency sequence

```text
Phase 1: prove execution on BEAM
    -> Phase 2: BEAM-resident source compiler and typed IR feed that path
        -> Phase 3: generalize BEAM lowering and runtime
            -> Phase 4: local capabilities and effects
                -> Phase 5: durable sessions and recovery
                    -> Phase 6: model and child-task execution
                        -> Phase 7: adversarial validation
                            -> Phase 8: demonstration and decision
```

No phase may move BEAM execution later in the sequence. Later phases extend
the path proven in Phase 1; they do not replace it with a host runtime.

## Roadmap completion gate

The roadmap is complete only when all eight phase evidence checklists pass and
a clean checkout can reproduce all of the following:

- [x] An A-Lang source program compiles into an inspected `.beam` artifact —
  [demonstration evidence](../../src/phase-08/reproducible-demonstration-package.md)
- [x] The artifact loads and runs as supervised BEAM processes on pinned ERTS —
  [release evidence](../../src/phase-08/phase-08-integration-evidence.md)
- [x] No host-language or existing BEAM-language interpreter executes the task —
  [implementation record](../../src/phase-08/implementation-status-and-risk-record.md)
- [x] Static types, effects, capability requirements, and runtime manifests agree —
  [controlled comparison](../../src/phase-08/controlled-baseline-and-ablation-comparison.md)
- [x] Opaque local grants and the broker prevent undeclared or out-of-scope effects —
  [controlled comparison](../../src/phase-08/controlled-baseline-and-ablation-comparison.md)
- [ ] Model, tool, storage, and workspace boundaries remain typed and OS-bounded —
  blocked because the mock model and local durable store are trusted BEAM
  processes and no general tool adapter is implemented; see the
  [risk record](../../src/phase-08/implementation-status-and-risk-record.md)
- [x] Process, adapter, and node failure do not duplicate the logical effect —
  [Phase 7 fault evidence](../../src/phase-07/fault-and-performance-characterization.md)
- [x] Completion requires the declared typed result and evidence digest —
  [demonstration evidence](../../src/phase-08/reproducible-demonstration-package.md)
- [x] Property and mutation suites detect seeded semantic and enforcement defects —
  [Phase 7 integration evidence](../../src/phase-07/phase-07-integration-evidence.md)
- [x] Performance and resource results are reported against declared baselines —
  [controlled comparison](../../src/phase-08/controlled-baseline-and-ablation-comparison.md)
- [x] BEAM, categorical IR, and agent-language hypotheses receive explicit decisions —
  [architecture decision](../../src/phase-08/proof-of-concept-architecture-decision.md)

**Roadmap outcome:** Revised, not complete. Phase 8 closes the planned
implementation and records the unmet OS-boundary gate rather than waiving it.
The combined architecture is not approved for production; exactly one bounded
effectful-source fidelity prototype may continue under the
[second planning stream](../02-effectful-source-fidelity/README.md).

## Maintaining this index

Keep phase filenames and numbers stable after implementation evidence links to
them. Update status and evidence in the phase documents rather than renumbering
the roadmap. Add a new numbered planning stream under `60-planning` if later
work materially changes the architecture or scope instead of silently
rewriting completed evidence.
