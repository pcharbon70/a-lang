---
title: "Phase 4 Source-to-BEAM Enforcement Integration Evidence"
kind: note
created: 2026-08-06
maturity: developing
tags:
  - beam
  - capability-security
  - compiler-testing
  - implementation-evidence
  - runtime-enforcement
aliases: []
---

# Phase 4 Source-to-BEAM Enforcement Integration Evidence

## Conclusion

Phase 4 passes its complete offline source-to-enforcement gate. Both the
A-Lang and typed-JSON frontends independently compile every one of the 24
frozen semantic cases to inspected BEAM. All 48 generated programs execute on
ERTS through the same broker, durable workflow, model protocol, bounded repair,
attenuated child, workspace adapter, and independent completion verifier.

After representation-local provenance is removed, every pair has the same
semantic executable identity, result class, counters, remaining budgets,
generated-code trace, broker decisions, durable journal projection, artifact
content, and completion witness. The raw BEAM artifacts remain distinct
because their inspected metadata retains the original frontend, source digest,
and source map.

This authorizes Phase 5's opt-in hosted evaluation work. It does not show that
A-Lang improves model comprehension, make hosted calls, remove the same-node
trust assumption, or establish production readiness.

## Enforced execution path

The backend lowers `alang_typed_task_ir_v2` directly to an allowlisted Erlang
Abstract Format subset in memory and asks OTP's compiler for a BEAM binary. It
does not emit Erlang source, use Core Erlang, or interpret accepted source or
typed JSON. The artifact inspector binds the generated module, imports,
exports, chunks, toolchain, manifest, limits, child descriptor, completion
contract, execution plan, semantic digest, and representation-local
provenance before code loading.

Generated programs can call only four fixed runtime ABI functions: begin a
task, request a registered effect, delegate to the statically declared child,
and ask the independent verifier to complete. Runtime configuration supplies
only exact operator bindings and deterministic test fixtures. Grants, shared
budgets, deadlines, operation identities, durable state, and completion
evidence are derived from inspected metadata; model-visible text cannot
supply or widen them.

## Complete paired matrix

| Family | Semantic cases | Representations executed | Result |
| --- | ---: | ---: | --- |
| Single-model artifact | 8 | 16 | Matched |
| Repair and publish | 8 | 16 | Matched |
| Attenuated delegation | 8 | 16 | Matched |
| **Total** | **24** | **48** | **All matched** |

Each pair is compiled and loaded independently. The normalized comparison
includes the terminal class and witness digest, runtime counters and remaining
budgets, step trace, broker audit projection, and durable journal projection.
An accounting oracle separately derives expected step, model, repair, child,
and workspace charges from the inspected execution plan and child limit, then
requires the runtime counters to agree.

All 24 raw source and JSON BEAM binaries differ, while the two members of each
pair have the same normalized executable-artifact digest. This is the intended
boundary: executable meaning agrees, but source provenance is not erased from
the inspected artifact.

## Negative, incomplete, and uncertain outcomes

Eight offline scenarios run through both representation paths and reach the
same fail-closed class.

| Scenario | Matched class |
| --- | --- |
| Undeclared model scope | `scope_mismatch` |
| Exhausted model-call budget | `budget_exhausted` |
| Malformed response with no repair allowance | `repair_budget_exhausted` |
| Failed bounded repair | `repair_failed` |
| Cancellation before child execution | `cancelled` |
| Adapter crash after mutation | `outcome_unknown` |
| Completion evidence with the wrong digest | `incomplete` |
| Required information absent | `incomplete` |

The uncertain workspace case preserves `outcome_unknown` through broker and
workflow normalization. The wrong-digest case records an incomplete Phase 6
verifier witness rather than converting failed independent verification into
completion or an invalid witness.

## Reproducibility identities

The build launches two separate ERTS processes. Each recompiles and executes
one representative pair from every family, retaining both representation
conditions. Their deterministic ETF bundles contain the actual BEAM bytes,
canonical metadata ETF, normalized trace ETF, artifact content, and completion
witness ETF for six executions. The two complete bundle files compare
byte-for-byte equal.

| Evidence | SHA-256 |
| --- | --- |
| Phase 4 evidence body | `bfc3d737c6ee66410533183ae204ac14ebdd2bfac0959bc310fb1495c26b1dc7` |
| Generated Phase 4 evidence artifact | `592921b7f60b55bed14216e122d22202ef172c7cfefeafbf90c1e37958ebb009` |
| Clean-process reproduction body | `d6e644bec7e162fade2d84e2a37715dc03847ada0e0f4e09f2df45e7a66a308d` |
| Each clean-process reproduction artifact | `4aa20131fc2d7401d2276b3210b6978a8223aed89658824f7522d465771d227f` |
| Complete offline normalized matrix | `72601cfc9335993eb45fe4592a4f75c0df410eafca5b52fa047ba5edcc8906f6` |

Generated ETF files remain below the ignored
`build/effectful-source-fidelity/phase-04/evidence/` directory. Their outer
envelopes decode with safe ETF handling; nested metadata and witness terms use
their contract-specific safe decoders and validators.

## Security, law, and mutation gates

The Phase 4 target depends on the unchanged Phase 1–8 gate. That reruns the
compiler and categorical laws, differential reference checks, broker and
workspace isolation, durability and recovery, adversarial inputs, pressure and
leak checks, fault campaigns, seeded mutations, completion verification,
offline demonstration, comparison, architecture decision, and release audit.

Phase 4 adds detection for ignored manifests, a JSON frontend bypass,
operator-supplied limit increases, recursive child authority, skipped repair
accounting, swapped source maps, a model-authored completion or authority
claim, and a condition-specific runtime handler. The paired fault matrix also
exercises the v2-specific cancellation, uncertainty, digest, and repair
transitions.

## BEAM residency and no-interpreter gate

The evidence loads the trusted lexer, parsers, JSON decoder, source adapter,
semantic checker, authority and IR passes, compiler, Abstract Format backend,
artifact inspector, runtime ABI, broker, durable workflow, workspace adapter,
model/repair/child components, completion verifier, offline runner, and
evidence builders from `.beam` files. OTP release `29` produced the frozen
evidence.

Campaign acceptance rejects manual IR and test reference evaluators. The
trusted compiler-source list contains Erlang modules only; no Rust, Cargo, C,
C++, Zig, Go, port, NIF, or foreign compiler executable participates. Ports
remain confined to the previously bounded workspace runtime effect and are not
part of source acceptance or compilation.

## Remaining limitations

- Runtime modules still share one trusted BEAM node and do not provide an OS
  security boundary between mutually hostile Erlang processes.
- Durable state uses the local filesystem implementation and is not a
  replicated production store.
- Generated programs use one fixed module identity, which serializes loading
  and is unsuitable for concurrent multi-tenant compilation.
- Reproducibility is frozen only for the recorded OTP 29 toolchain profile and
  platform.
- Model behavior is supplied by deterministic offline fixtures; no provider
  transport, credential, cost, or live-model variability is exercised.
- Passing Phase 4 is an implementation gate, not production approval or
  evidence that the candidate notation improves task comprehension.

## Reproduction

From the repository root, the single complete command is:

```bash
make test-fidelity-phase-4
```

It rebuilds changed BEAM-resident toolchain and runtime modules, reruns the
Phase 1–8 and fidelity Phase 1–3 dependencies, compiles and executes all 48
representations, runs the paired fault and mutation gates, starts the two clean
ERTS reproduction processes, compares their files byte-for-byte, writes the
Phase 4 evidence artifact, and verifies the frozen identities. The phase target
is also part of repository-wide `make test`.

## Connections

- [Phase 4 implementation plan](../../60-planning/02-effectful-source-fidelity/phase-04-source-to-beam-enforcement-integration.md)
- [Effectful source fidelity roadmap](../../60-planning/02-effectful-source-fidelity/README.md)
- [Phase 3 matched lowering evidence](phase-03-integration-evidence.md)
- [Phase 8 implementation status and risk record](../phase-08/implementation-status-and-risk-record.md)
- [Task-language inquiry](../../40-inquiries/can-a-task-language-improve-llm-agents.md)
- [Implementation index](README.md)
