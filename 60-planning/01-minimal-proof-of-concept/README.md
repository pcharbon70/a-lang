---
title: "A-Lang Minimal Proof-of-Concept Plan"
kind: map
created: 2026-07-31
tags:
  - agent-programming
  - beam
  - implementation-planning
  - proof-of-concept
  - ucan
aliases:
  - "A-Lang PoC roadmap"
---

# A-Lang Minimal Proof-of-Concept Plan (`01-minimal-proof-of-concept`)

## Purpose

This planning stream turns the current A-Lang research into the smallest
credible source-to-effect vertical slice. It starts by freezing meaning and
toolchain boundaries, then builds a native frontend, typed task IR, BEAM
backend, durable effect broker, UCAN authorization profile, bounded LLM loop,
law and fault harness, and final end-to-end evaluation.

The roadmap is a proof-of-concept plan, not a production backlog. Each phase
must produce evidence that either strengthens the architecture or exposes a
reason to stop, simplify, or change direction.

## What belongs here

- The ordered phase documents for this proof of concept.
- Scope, dependency, and completion rules shared by all phases.
- Links from implementation gates to the research claims they test.

Implementation results, source code, fixtures, and generated artifacts will
live in the code and test directories established during Phase 1. This
directory remains the planning authority and evidence index.

## Status rules

- Planned phases, sections, tasks, and subtasks use unchecked boxes.
- Every phase, section, task, and subtask begins with a description of its
  purpose and observable result.
- A task is complete only when its implementation, focused tests,
  documentation, diagnostics, and failure behavior are reviewable together.
- A section is complete only when every task is complete and all earlier phase
  gates remain green.
- Every phase ends with a numbered integration-test section and a completion
  evidence checklist.
- A phase is complete only when the checked evidence is reproducible from a
  clean checkout with the pinned toolchain.
- A parsed or lowered form is not executable-language evidence until the
  generated module passes OTP validation, loads, and produces the specified
  observation on ERTS.
- A model response never counts as a successful effect until it passes typed
  decoding, policy enforcement, durable recording, execution, and result
  verification.
- A UCAN token never counts as authority until the pinned profile, proof path,
  resource semantics, replay state, and execution-time policy all validate.
- A property suite must demonstrate sensitivity by detecting deliberately
  seeded law, backend, authorization, or recovery defects.

## Starting baseline

The repository currently contains a connected research archive and no
promoted A-Lang implementation. The relevant conclusions are:

- [Task-language research](../../20-notes/llm-agent-task-languages-deep-dive.md)
  recommends a typed declarative task representation, bounded model judgments,
  deterministic orchestration, runtime enforcement, and completion evidence.
- [Categorical research](../../20-notes/set-and-category-principles-for-agent-programming-language.md)
  recommends ordinary data types, typed task arrows, products, coproducts,
  explicit effects, lawful interpreters, and observationally tested
  composition without categorical surface jargon.
- [BEAM research](../../20-notes/beam-runtime-for-native-agent-language.md)
  recommends a native frontend and A-Lang-owned IR lowered through OTP's
  supported Erlang Abstract Format, with ports or sidecars for external work
  and no existing BEAM language as the main interpreter.
- [UCAN research](../../20-notes/ucan-capabilities-for-agent-language.md)
  recommends a version-pinned Delegation and Invocation profile behind an
  A-Lang broker, while leaving resource semantics, stateful policy, replay,
  durability, and isolation to the runtime.

The open
[task-language](../../40-inquiries/can-a-task-language-improve-llm-agents.md),
[categorical](../../40-inquiries/can-categorical-semantics-improve-agent-language.md),
[BEAM](../../40-inquiries/can-beam-support-a-native-agent-language.md), and
[UCAN](../../40-inquiries/can-ucan-enforce-a-lang-agent-capabilities.md)
inquiries supply the falsification criteria used in later phases.

## Proof-of-concept thesis

The PoC tests this claim:

> A small A-Lang program can be parsed and checked by a native compiler,
> compiled through Erlang Abstract Format into a validated BEAM module, run as
> an ERTS process, make one bounded LLM judgment, and perform one durable
> workspace effect only through a least-authority UCAN-backed broker, while a
> reference evaluator, law tests, fault injection, and an audit trace make the
> result independently inspectable.

## Target demonstration

A successful final demonstration performs this sequence from a clean checkout:

1. `alangc check` parses an A-Lang example and displays its typed IR, closed
   effect set, normalized capability requirement, and completion predicate.
2. `alangc build` lowers the same IR to Erlang Abstract Format, invokes a
   pinned OTP compiler bridge with strong validation, and emits a deterministic
   `.beam` artifact plus source and capability metadata.
3. A launcher loads the artifact and starts one supervised task process on
   ERTS; no Erlang, Elixir, Gleam, or other BEAM-language interpreter evaluates
   the A-Lang program.
4. The task requests a bounded `Model.complete` effect through a typed message
   ABI. A deterministic mock provider is mandatory; a live provider is an
   optional adapter using the same contract.
5. The task requests `Workspace.write` under a fixed output directory. It
   holds only an opaque `CapabilityRef`; signing keys and raw authority remain
   in the broker and isolated UCAN service.
6. The broker derives a short-lived session Delegation, creates a signed
   Invocation with canonical arguments, validates it at execution time,
   applies local policy and budget state, and records durable intent.
7. The workspace adapter writes by canonical path relative to an already
   opened workspace root, records the result, and returns an `ArtifactRef`.
8. The verifier checks the artifact, associates evidence with the declared
   completion predicate, and emits a provenance trace covering source,
   artifact, principal, grant, invocation, intent, effect, and result.
9. Replaying the invocation or killing the task around the effect boundary
   does not duplicate the acknowledged write.

## Minimal language boundary

The promoted PoC surface is deliberately small:

- primitive `Unit`, `Bool`, `Int`, `Text`, `Bytes`, and opaque identifier
  types;
- records, products, and `Result[Error, Value]` coproducts;
- modules, typed pure functions, and typed tasks;
- `let`, function application, sequential composition, and exhaustive result
  matching;
- declarations for effects, capability requirements, and mechanically
  checkable completion predicates;
- closed, monomorphic effect sets;
- `Model.complete`, `Workspace.write`, and `Trace.emit` runtime operations;
- one supervised task process and one mechanically attenuated child task in
  the final delegation test.

The following remain out of scope unless a phase explicitly promotes them:

- general recursion, effect polymorphism, higher-kinded types, or a broad
  standard library;
- user-authored supervision trees, arbitrary actor messaging, distribution,
  hot upgrade, or dynamic code loading;
- parallel task composition before noninterference is defined;
- general shell, arbitrary network, payment, secret, or messaging effects;
- direct Core Erlang or BEAM assembly as the production backend;
- a NIF-based validator, in-process model server, or untrusted code on the
  ERTS node;
- UCAN Powerline, `/` commands, non-expiring grants, Promise, Receipt, or RC
  Revocation as workflow foundations;
- claims of exactly-once effects, formal proof, or production security.

## Bootstrap implementation boundary

The roadmap assumes a Rust native compiler and reference evaluator, a small
Rust UCAN signer/validator sidecar, and narrowly scoped Erlang support modules
for the OTP compilation bridge and runtime ABI. Phase 1 must record or revise
this choice before code expands.

The Erlang modules are support code, not the A-Lang interpreter. A-Lang source
is evaluated only by the independent reference evaluator for comparison or by
compiled BEAM modules on ERTS. The production path never emits Erlang source
and never hands A-Lang source to an `eval` loop.

## Planned architecture

```text
A-Lang source + canonical JSON fixtures
    │
    ▼
Rust lexer/parser/resolver/type-effect checker
    │
    ▼
A-Lang-owned typed task IR
    ├──────────────► reference evaluator / simulator / trace interpreter
    │
    ▼
Erlang Abstract Format encoder
    │ pinned OTP compile bridge + strong validation
    ▼
BEAM artifact + source map + capability manifest
    │
    ▼
ERTS task process ──typed ABI──► effect gateway
                                  ├─ capability broker / policy / budgets
                                  ├─ UCAN signer-validator port
                                  ├─ intent-result journal
                                  └─ isolated model and workspace adapters
```

## Index

### Subdirectories

- None yet.

### Documents

- [Phase 1 — Executable contract and toolchain foundation](phase-01-executable-contract-and-toolchain-foundation.md)
  — freezes the PoC surface, repository layout, toolchain, semantic oracle,
  diagnostics, and clean-build gates.
- [Phase 2 — Native frontend and typed task IR](phase-02-native-frontend-and-typed-task-ir.md)
  — implements the canonical JSON form, native textual frontend, name and type
  checking, effects, capability requirements, and independent IR interpreters.
- [Phase 3 — Erlang Abstract Format and BEAM runtime kernel](phase-03-erlang-abstract-format-and-beam-runtime-kernel.md)
  — lowers typed IR through OTP's supported boundary into validated BEAM and
  establishes the closed runtime ABI and supervised process model.
- [Phase 4 — Capability broker and durable effects](phase-04-capability-broker-and-durable-effects.md)
  — adds opaque local authority, canonical effect schemas, a journal, budgets,
  workspace isolation, replay protection, and recovery.
- [Phase 5 — UCAN profile and portable authorization](phase-05-ucan-profile-and-portable-authorization.md)
  — pins an interoperable UCAN subset, isolates signing keys, and maps typed
  requirements into Delegations and concrete Invocations.
- [Phase 6 — Bounded LLM task and subagent execution](phase-06-bounded-llm-task-and-subagent-execution.md)
  — integrates deterministic and optional live model adapters, bounded repair,
  verification, context slicing, and one attenuated child task.
- [Phase 7 — Law, security, fault, and performance validation](phase-07-law-security-fault-and-performance-validation.md)
  — exercises composition, attenuation, semantic preservation, adversarial
  inputs, crash recovery, and resource behavior.
- [Phase 8 — End-to-end demonstration and PoC decision](phase-08-end-to-end-demonstration-and-poc-decision.md)
  — packages a reproducible demo, compares baselines, evaluates falsification
  criteria, and records the promote, revise, or stop decision.

## Dependency graph

```text
Phase 1: contract and toolchain
    -> Phase 2: frontend and typed IR
        -> Phase 3: Abstract Format and BEAM kernel
            -> Phase 4: broker and durable effects
                -> Phase 5: UCAN authorization
                    -> Phase 6: LLM and child task
                        -> Phase 7: laws, attacks, faults, performance
                            -> Phase 8: reproducible demo and decision
```

Phase 7 test scaffolding may begin earlier, but its acceptance evidence depends
on the complete Phase 6 vertical slice. Phase 8 documentation may evolve
throughout the work, but no architecture is promoted before its final gates.

## Research-to-phase traceability

| Research conclusion | Implementation phases |
| --- | --- |
| typed declarative tasks and explicit completion evidence | 1, 2, 6, 8 |
| familiar source plus typed semantic IR | 1, 2 |
| products, coproducts, typed composition, and lawful interpreters | 2, 7 |
| explicit effects outside unrestricted model control | 2, 4, 6 |
| native frontend and A-Lang-owned IR | 1, 2 |
| Erlang Abstract Format rather than Core or assembly | 1, 3 |
| ERTS processes for bounded I/O-oriented control | 3, 4, 7 |
| ports or sidecars for model, tools, and authorization | 3–6 |
| durable intent/result records instead of supervision-only retry | 4, 7 |
| declarative requirement distinct from grant and decision | 2, 4, 5 |
| short, attenuated UCAN Delegations and concrete Invocations | 5, 6 |
| broker key custody for model-controlled non-redelegation | 5, 6 |
| property, differential, adversarial, and fault evidence | 7, 8 |

## Roadmap completion gate

- [ ] A clean checkout builds with pinned Rust and OTP toolchains
- [ ] One A-Lang source program parses, resolves, type-checks, and produces a
      normalized capability manifest and completion predicate
- [ ] The program executes both in the reference evaluator and as an
      OTP-validated loaded BEAM module with equivalent normalized observations
- [ ] No existing BEAM-language interpreter evaluates A-Lang source at runtime
- [ ] Every external effect crosses the typed runtime ABI and reference monitor
- [ ] The task process holds only an opaque `CapabilityRef`; model-visible data
      contains no signing key or general delegation primitive
- [ ] A pinned UCAN profile produces and independently validates a short-lived
      workspace Delegation and signed Invocation
- [ ] Canonical path policy, local budget state, and replay protection deny the
      specified negative cases
- [ ] Killing the task and effect workers at every journal transition does not
      duplicate an acknowledged workspace write
- [ ] Property suites detect seeded composition, backend, attenuation, and
      recovery defects and shrink them to actionable counterexamples
- [ ] The deterministic mock-model demonstration is reproducible without
      network access or secrets
- [ ] Optional live-model execution uses the same typed boundary and is
      reported separately from deterministic acceptance evidence
- [ ] The final comparison records task correctness, unauthorized effects,
      recovery, latency, resource use, trace clarity, and implementation cost
- [ ] A written decision promotes, revises, narrows, or stops the architecture
      without treating a running demo as sufficient evidence

## Maintaining this index

Keep phase links, status boxes, dependencies, and completion evidence aligned
with the phase files. Do not mark a phase complete because implementation
began or because a focused happy-path test passed. Add newly discovered work
to the earliest phase whose contract it changes, and keep intentionally
deferred features visible rather than silently expanding the PoC.
