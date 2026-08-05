---
title: "Phase 2 Effectful Source Frontend Evidence"
kind: note
created: 2026-08-05
maturity: developing
tags:
  - beam
  - compiler-testing
  - implementation-evidence
  - parsing
  - task-language
aliases: []
---

# Phase 2 Effectful Source Frontend Evidence

## Conclusion

Phase 2 passes its offline frontend gate. All 24 frozen `alang-source-v2`
documents parse on ERTS into the exact, bounded `alang_source_ast_v2` shape,
round-trip through a distinct deterministic ETF envelope, and retain
source-local origins. The trusted lexer, parser, AST validator, canonical
boundary, and evidence builder all execute from `.beam` files.

This authorizes Phase 3 static semantics and matched lowering. It does not show
that the candidate and typed-JSON representations have equal semantics, execute
the effectful programs, or improve model comprehension. Those remain later
gates.

## Implemented source contract

Phase 1 froze a clause-based candidate surface using `facts`, typed `input`
declarations, `effects`, `requirements`, `scopes`, `limits`, ordered `step`
dependencies, `on-error`, one attenuated `child`, structured `complete`
predicates, `clarify`, and an explicit `terminal` class. Earlier Phase 2 prose
still described a superseded `do`/`let` sketch. The plan was reconciled to the
already preregistered documents; none of the 24 source candidates was rewritten
after the freeze.

The v2 parser accepts only the operations and declarations represented in that
corpus. It does not intern source-controlled atoms, interpret source, dispatch
effects, select adapters, or translate A-Lang into Erlang source or Erlang
AST/IR. Inputs without the v2 shebang continue through the unchanged v1
frontend.

## Stable identities

The evidence builder sorts all corpus paths, parses and canonicalizes each
document, extracts every origin-bearing source-map entry, and hashes the
deterministic records.

| Evidence | SHA-256 |
| --- | --- |
| Evidence body | `1cb5dda589ed04aa1e9f20fc4b69f56cbf5878bd447aff7b502ffd3d310c97da` |
| Twenty-four-case AST manifest | `fe669efed7d5d915ca5cfaac32017fca7da433ec270c814a45ba5830c2fac27b` |
| Canonical AST bundle | `f5c3b26017c5dc8e8994b79fae53433c5c28acb3869e9b7ea2a99c0b3ab1b143` |
| Source-map bundle | `23aa22b62b5c0d01b3c730fc2166e4833ca0a726ebf87a1b3163b823b05a429f` |
| Generated ETF artifact | `7ce89c581b5bbc782277263033aeac788cdbac1c9cbe2cebfeaf87ce907e9e61` |

Individual canonical ASTs range from 3,588 to 8,752 bytes and contain 44 to
105 origin entries. The generated evidence remains under the ignored
`build/effectful-source-fidelity/phase-02/evidence/` directory; the hashes above
are the repository-facing identities and are asserted by integration tests.

## Corpus and syntax coverage

| Family | Documents | Result |
| --- | ---: | --- |
| Single-model artifact | 8 | Parsed and round-tripped |
| Repair and publish | 8 | Parsed and round-tripped |
| Attenuated delegation | 8 | Parsed and round-tripped |
| **Total** | **24** | **24 unique task identities** |

The accepted AST covers empty-authority clarification cases, reordered
set-valued declarations, optional inputs, model generation and repair,
workspace publication, child execution, explicit failure results, child
attenuation, six completion-predicate kinds, and both complete and
needs-clarification terminal classes. Every node has exact fields; unsupported
constructs have no AST representation.

## Canonical and compatibility boundary

V2 canonical data is the deterministic ETF term
`{alang_source_canonical_v2, Ast}`. Decoding uses safe atom handling and exact
byte consumption, rejects compressed, trailing, oversized, unsafe, and
noncanonical terms, and revalidates the complete AST before returning it.

The existing v1 counter source, AST, canonical bytes, and representative
diagnostic remain unchanged:

| V1 evidence | SHA-256 |
| --- | --- |
| Source | `5229e7c04a1ce1c10ef06f49f02bcd81f55be6e26206c5e0594929d207ecb9d4` |
| Canonical ETF | `0ac9fab3031c93311ae0e42f9f494c17797d2b05662443c281b2b6f7af781d28` |
| Diagnostic record | `4d557c6cf98b78cfc5f41942ee681448756c1cccfb92027218be1d8477b27eff` |

The complete prior `alang_phase2_compiler_tests` suite is part of the new
integration target rather than being represented by one compatibility fixture
alone.

## Negative and generative evidence

Eight seeded mutants each fail at their intended boundary:

| Mutant | Diagnostic |
| --- | --- |
| Dynamic declared effect | `unknown_effect` |
| Dynamic step operation | `unknown_operation` |
| Missing error table | `missing_task_clause` |
| Widened child record | `unknown_child_field` |
| Traversing completion path | `unsafe_completion_path` |
| Duplicate limit | `duplicate_field` |
| Unsupported loop syntax | `unexpected_task_clause` |
| Invalid UTF-8 | `invalid_utf8` |

The deterministic robustness pass uses seed `20260805` to exercise 512 inputs
up to 255 bytes against both text and canonical boundaries. It records zero
parser crashes, zero canonical-decoder crashes, and zero atom growth after
warmup. Two additional PropEr properties generate 256 bounded binaries per
boundary and require an ordinary result for every case. Token streams are
capped at 4,096 entries; source, canonical, action, child-depth, and output
bounds are recorded in the evidence body.

## BEAM residency and effect isolation

The evidence names these trusted frontend modules, each loaded from the
stream-owned Phase 2 build directory with a `.beam` extension:

- `alang_fidelity_lexer`
- `alang_fidelity_parser`
- `alang_fidelity_ast`
- `alang_fidelity_canonical`
- `alang_fidelity_frontend_evidence`

OTP release `29` produced this evidence. The evidence records no foreign
compiler executable, no hosted call, and no parser runtime effect. Corpus reads
and the explicitly requested evidence write belong to the test harness, not to
the lexer, parser, AST validator, or canonical decoder.

## Reproduction

From the repository root:

```bash
make test-fidelity-section-2-4
make build-fidelity-phase-2-evidence
make test-fidelity-phase-2
```

The section target compiles the frontend deterministically, reruns every Phase
1 experiment-freeze test, reruns the complete legacy v1 frontend suite, parses
and round-trips the 24 v2 sources, executes the negative and generative gates,
and verifies the frozen identities. The evidence target writes the inspectable
ETF record. The phase target is also included in repository-wide `make test`.

## Connections

- [Phase 2 implementation plan](../../60-planning/02-effectful-source-fidelity/phase-02-effectful-source-syntax-and-ast.md)
- [Effectful source fidelity roadmap](../../60-planning/02-effectful-source-fidelity/README.md)
- [Phase 1 freeze evidence](phase-01-integration-evidence.md)
- [Task-language inquiry](../../40-inquiries/can-a-task-language-improve-llm-agents.md)
- [Implementation index](README.md)
