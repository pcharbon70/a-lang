---
title: "Phase 3 BEAM Artifact and Loading Contract"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - artifact-validation
  - beam
  - compiler-backend
  - runtime-systems
aliases: []
---

# Phase 3 BEAM Artifact and Loading Contract

## Metadata placement

Every generated module carries exactly one `alang_backend` module attribute.
The attribute contains the fixed module, backend metadata format, typed-IR
format, runtime ABI, BEAM-resident compiler identity, pinned OTP/ERTS identity,
reproducibility profile, source and IR digests, declared capability manifest,
and node-to-source map. The ordinary deterministic `Attr` chunk is the sole
metadata location; Phase 3 does not hand-assemble a custom BEAM chunk.

The source digest covers the original A-Lang source bytes. The IR digest covers
the deterministic ETF encoding of the typed IR. The compiler bridge reports a
separate digest over the deterministic ETF Abstract Format forms and a SHA-256
digest over the final BEAM binary. The latter two are build evidence rather
than embedded metadata, avoiding a self-referential artifact digest.

Capability metadata is recomputed from task signatures during lowering. A
caller-provided semantic view must match that result exactly or compilation
fails.

## Inspection policy

`alang_phase3_artifact:inspect/1` parses without executing the module and
requires:

- the fixed `alang_phase3_program_v1` module and only `execute/3` plus OTP's
  two `module_info` exports;
- only the fixed runtime ABI import, approved pure BIFs, and OTP-generated
  `get_module_info` imports;
- the required OTP-29 structural chunks and only the allowed deterministic
  compiler chunk profile, with no custom or unknown chunks;
- exactly one `alang_backend` attribute plus OTP's `vsn` attribute;
- the active pinned compiler version and exact OTP, ERTS, and architecture
  identity;
- 64-character lowercase source and IR SHA-256 values; and
- a BEAM container no larger than one MiB.

Missing, malformed, incompatible, oversized, or forbidden surfaces are
rejected before `code:load_binary/3` is reachable.

## Loading and lifecycle

The loader accepts only an inspected in-memory binary and refuses to replace
an already loaded generated module. It gives the code server an in-memory
digest identity, starts execution only through the supervised launcher, waits
for that session to terminate, deletes the generated module, and uses a soft
purge so live code references become an explicit failure instead of killing
an owner silently. Phase 3 deliberately provides no hot-upgrade semantics.

## Limits and remaining trust boundary

The PoC trusts artifacts produced by its bounded Abstract Format compiler; it
does not claim to be a general hostile-BEAM sandbox. `beam_lib` and the code
server are pinned OTP services inside the trusted ERTS node. Future isolation
work may move inspection and execution to a disposable peer node, but it must
not weaken the metadata, import, or lifecycle gates defined here.

## Connections

- [Erlang Abstract Format contract](abstract-format-contract.md)
- [Backend representation contract](backend-representation-contract.md)
- [Phase 3 implementation plan](../../60-planning/01-minimal-proof-of-concept/phase-03-erlang-abstract-format-and-beam-runtime-kernel.md)
