---
title: "Phase 8 Falsification Review"
kind: note
created: 2026-08-04
maturity: developing
tags:
  - architecture-decision
  - beam
  - falsification
  - proof-of-concept
aliases: []
---

# Phase 8 Falsification Review

## Review rule

A working demonstration is feasibility evidence, not automatic evidence for
the research motivation. This review applies positive and negative criteria to
each layer independently. `Promote` means retain a layer in the next bounded
prototype; it does not mean production approval. `Narrow` retains only the
claim supported by current evidence. `Revise` changes the combined prototype's
next question before more features are added.

## Results

| Hypothesis | Supporting evidence | Falsification or narrowing evidence | Disposition |
| --- | --- | --- | --- |
| Task language | Types, effects, requirements, grants, and completion predicates are machine-checkable and runtime-enforced | The accepted source syntax expresses only the pure counter; effectful demonstrations start from constructed typed IR, and no LLM or human fidelity study exists | Narrow |
| Categorical IR | Identity, composition, manifest, serialization, handler, and observation laws execute under PropEr and detect seeded violations | A matched conventional typed IR produces the same frozen observation; no repair, reuse, portability, or human advantage was isolated | Narrow |
| BEAM compiler and runtime | Trusted compiler modules and generated artifacts execute on ERTS; artifact inspection, supervision, bounded messaging, and fault gates pass | Evidence covers one pinned OTP 29 host, not a release matrix, production scale, hostile code, or a strong alternative-runtime comparison | Promote to the next prototype |
| Local capability broker | The controlled ablation denies an out-of-scope write and an over-budget write that the same direct effect path performs; denials are auditable | The broker has nontrivial implementation cost and proves only runtime-local authority, not portable or distributed delegation | Promote locally |
| Explicit durability | Intent/result ordering, checkpoints, reconciliation, and explicit uncertainty survive the bounded fault campaign without a duplicate logical effect | It does not prove exactly-once external effects, distributed consensus, or production storage operability | Promote for consequential effects |
| Combined architecture | The offline source-to-evidence slice is reproducible and its core layers interoperate | The central effectful source-language and LLM-understanding claims remain untested; therefore the PoC is not a production platform candidate | Revise |

## Positive criteria applied

- Semantic fidelity: compiled BEAM and the bounded reference observations agree
  for generated pure and effectful cases, including the frozen Phase 8 tasks.
- Compiled execution: the source compiler, IR validation, lowering, OTP backend,
  inspector, loader, and generated programs are BEAM modules on ERTS.
- Compiler enforcement: malformed source, types, effects, manifests, Abstract
  Format, and artifacts fail closed in the accepted subset.
- Bounded behavior: admission, mailbox, request, trace, payload, deadline,
  retry, model-call, and child-task limits have executable gates.
- Recovery: effect ambiguity is reconciled or remains explicitly uncertain;
  supervision is not misreported as durability.
- Authority: grants are opaque, process- and generation-bound, monotonically
  restricted, budgeted, and checked by the broker before dispatch.
- Isolation: the workspace effect crosses an owned BEAM port to a bounded
  sidecar; same-node BEAM processes are not described as a malicious-code
  sandbox.
- Completion: the final Markdown must satisfy path, file, digest, size, UTF-8,
  section, and journal predicates before a witness reports completion.

## Rejection and narrowing criteria applied

Structured syntax has not yet demonstrated a user-facing benefit because the
effectful slice bypasses the source grammar. Categorical structure has earned a
place as internal laws and analyses, but it tied the conventional typed IR on
the only controlled semantic example. BEAM and explicit durability add visible
components and latency; current measurements characterize those costs without
showing a runtime advantage over a strong alternative. The broker, in contrast,
survives its simpler direct-handler ablation: the direct condition cannot match
its least-authority enforcement without reintroducing equivalent policy and
state machinery.

The evidence therefore rejects categorical superiority, improved LLM
understanding, production scale, hostile-code isolation, portable delegation,
exactly-once effects, and formal-proof claims. None is silently converted into
future work while being described as already demonstrated.

## Evidence trail

- [Controlled baseline and ablation comparison](controlled-baseline-and-ablation-comparison.md)
- [Reproducible demonstration package](reproducible-demonstration-package.md)
- [Phase 7 generated laws](../phase-07/typed-generators-and-law-observations.md)
- [Phase 7 seeded-defect sensitivity](../phase-07/seeded-defect-sensitivity.md)
- [Phase 7 fault and performance characterization](../phase-07/fault-and-performance-characterization.md)
- [Phase 5 durability evidence](../phase-05/phase-05-integration-evidence.md)
- [Phase 4 local-broker evidence](../phase-04/phase-04-integration-evidence.md)
