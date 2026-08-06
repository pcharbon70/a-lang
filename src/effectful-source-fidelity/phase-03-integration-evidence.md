---
title: "Phase 3 Matched Lowering Integration Evidence"
kind: note
created: 2026-08-05
maturity: developing
tags:
  - beam
  - compiler-testing
  - effect-systems
  - implementation-evidence
  - typed-ir
aliases: []
---

# Phase 3 Matched Lowering Integration Evidence

## Conclusion

Phase 3 passes its offline matched-lowering gate. The independent A-Lang and
typed-JSON frontends accept all 24 frozen pairs, the shared semantic core gives
each pair the same origin-free meaning, and the authority and lowering passes
produce byte-identical `alang_typed_task_ir_v2` values. Direct IR, fixture, and
reference-evaluator inputs remain outside campaign acceptance.

This authorizes Phase 4 integration with the existing inspected Abstract
Format backend and runtime enforcement path. It does not show that these IR
programs execute through that path, that either source notation improves LLM
comprehension, or that a hosted campaign is valid. Those remain later gates.

## Frozen identities

The evidence builder orders the 24 corpus paths, checks each representation,
removes frontend-local origins from meaning, lowers both paths independently,
and hashes deterministic ETF records.

| Evidence | SHA-256 |
| --- | --- |
| Evidence body | `1d6f0c2a46a49d104bf7106d190e122aeca1d43fddd05fbb0c961ddbdea4d826` |
| Generated ETF artifact | `9f0f891c750528c1471a20791886e1a92692449a6b87eb5c16d0501a76a87801` |
| Semantic-digest bundle | `1e5d7321588c001d5851667a613a461a79b6e0d52a37daff6d24f8229c3a82ba` |
| IR-digest bundle | `2f84a95398fe71b44e781d82b91a4b9fbf5b8c7efbc661c1a9a9109573de4a89` |
| Manifest bundle | `563c40e22ee58c601b9211a5fe610fa26c85acdecee3268b23abe841fd3f2e00` |
| Task-limit bundle | `db05e96dabe3b7fc92a20db1fef8a9ad78de11e6957cac2e4047500ee760c248` |
| Completion bundle | `c1c2457e28c805e02e4a586a779085cb12221eff7a5a1246016e4a55bacdf9a1` |

The generated artifact remains below the ignored
`build/effectful-source-fidelity/phase-03/evidence/` tree. Integration tests
freeze both its byte identity and the evidence-body identity.

## Paired lowering result

Each case record retains the original source and control hashes, the shared
semantic and IR hashes, component hashes for the manifest, declared limits,
static bounds, child descriptor, and completion specification, plus distinct
source-map hashes. All 24 records satisfy these equalities:

- A-Lang and JSON checked meanings and semantic digests are equal;
- their complete v2 IR values and deterministic IR digests are equal;
- module and task manifests are equal and use only closed registry mappings;
- task limits cover recomputed direct and delegated static bounds;
- child effects, authority, limits, and deadlines do not widen the parent;
- completion predicates and terminal classes survive checking and lowering;
- deterministic preorder node IDs, prior-only dependencies, and contiguous
  effect-site ordinals validate; and
- representation-specific origins remain outside normalized meaning and IR.

The manifest contains static resource requirements, not a grant, credential,
endpoint, process identity, or capability handle. `model.generate` and
`model.repair` map to the registered `model.complete` runtime operation;
workspace and child operations retain their closed registry identities.

## Equivalent rejection evidence

Eight paired mutants pass through both frontend paths. Every pair produces the
same class and code while retaining an A-Lang byte/line origin or a typed-JSON
Pointer/byte origin.

| Semantic defect | Shared rejection |
| --- | --- |
| Dependency names a non-prior action | `control/dependency_not_prior` |
| Input uses an unknown type | `type/unknown_type` |
| Declared effects omit an inferred operation | `authority/declared_effect_mismatch` |
| Step ceiling is below the static bound | `limit/limit_below_static_bound` |
| Child receives recursive child authority | `attenuation/recursive_child_authority` |
| Completion path traverses outside the workspace | `completion/unsafe_completion_path` |
| Journal completion names an unknown action | `completion/unknown_completion_action` |
| Clarification terminal performs effects first | `control/effects_before_clarification` |

Messages and origin shapes remain notation-specific; only the semantic error
identity is required to agree.

## Law and mutation evidence

A deterministic 256-case sweep cycles across all frozen programs and checks
IR serialization, safe full-consumption decoding, manifest agreement, finite
limit bounds, child attenuation, stable node references, and completion
preservation. The EUnit gate additionally runs two PropEr properties for 128
generated selections each: paired lowering remains deterministic, and every
accepted IR retains valid bounds and attenuation.

Six seeded defects are detected by the same integration oracles:

| Seeded defect | Detection |
| --- | --- |
| Removed effect inference | `manifest_effect_mismatch` |
| Widened child model limit | `child_limit_widens_parent` |
| Dropped completion field | `completion_not_preserved` |
| Condition-specific default | `paired_ir_mismatch` |
| Unstable preorder node ID | `unstable_node_identity` |
| Direct IR campaign input | `manual_ir_forbidden` |

## BEAM residency and isolation

The evidence loads the JSON pointer scanner, JSON decoder, lexer, parser,
source adapter, shared semantic checker, authority pass, IR pass, compiler,
mutation runner, and evidence builder from `.beam` files. OTP release `29`
produced the frozen artifact. The compiler gate records no hosted call, runtime
effect, or foreign compiler executable.

Corpus reads and the explicitly requested evidence write belong to the test
harness. The accepted compiler path consumes bounded source bytes, constructs
A-Lang-owned semantic and IR terms, and executes on ERTS; it does not translate
accepted A-Lang into Erlang source or Erlang AST/IR.

## Reproduction

From the repository root:

```bash
make test-fidelity-section-3-4
make build-fidelity-phase-3-evidence
make test-fidelity-phase-3
```

The section target first reruns every Phase 1–2 experiment and frontend gate,
then the typed-JSON, shared-semantics, authority, lowering, paired-negative,
law, mutation, campaign-provenance, and evidence suites. The phase target is
also part of repository-wide `make test`.

## Connections

- [Phase 3 implementation plan](../../60-planning/02-effectful-source-fidelity/phase-03-static-semantics-manifests-and-matched-lowering.md)
- [Effectful source fidelity roadmap](../../60-planning/02-effectful-source-fidelity/README.md)
- [Phase 2 frontend evidence](phase-02-integration-evidence.md)
- [Task-language inquiry](../../40-inquiries/can-a-task-language-improve-llm-agents.md)
- [Implementation index](README.md)
