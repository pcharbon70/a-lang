---
title: "Phase 8 Controlled Baseline and Ablation Comparison"
kind: note
created: 2026-08-04
maturity: developing
tags:
  - ablation-study
  - beam
  - evaluation
  - proof-of-concept
aliases: []
---

# Phase 8 Controlled Baseline and Ablation Comparison

## Question and controls

This comparison asks which parts of the A-Lang proof of concept contribute
observable semantic agreement, authority enforcement, recovery, explanation,
or cost. It does not compare unrelated applications. All conditions use input
41 and result 42 for the pure task; the effect conditions use the same model
output, workspace ID, paths, content, operation identities, declared budget,
effect registry, BEAM workspace sidecar, journal-evidence schema, and completion
verifier.

Run the executable matrix with:

```bash
make test-section-8-2
```

The target first accepts the Phase 7 adversarial, fault, performance, and
seeded-defect gates. It then writes the current host's complete measurements to
`build/phase-08/comparison/comparison.config`. Timings are deliberately not
frozen as golden values.

## Conditions

| Question | A-Lang condition | Matched comparison | Status |
| --- | --- | --- | --- |
| Pure execution | Inspected compiled `.beam` | Bounded semantic oracle and a minimal conventional typed stack program | All return 42 and complete without effects |
| Effect interpretation | Compiled model-effect `.beam` and law-declared typed task IR | A conventional typed instruction map with the same handler and output | Result, completion, and effect observation agree |
| Local enforcement | Opaque broker grant scoped to `reports/` with budget two | Direct handler reaches the same effect registry and sidecar without the broker | Positive results agree; enforcement differs |
| Recovery | Phase 5 journal/recovery protocol under the Phase 7 fault matrix | No-recovery direct handler | The ablation cannot make a recovery claim |

The bounded reference evaluators and conventional evaluators are test-only
oracles. They compile to BEAM for the validation harness but are explicitly
nondeployable and do not satisfy an A-Lang execution gate.

## Correctness and enforcement observations

The compiled program, bounded reference evaluator, and conventional typed
runtime agree on the pure observation. The compiled effect program,
law-declared IR reference, and conventional effect IR agree on result,
completion, and the single `model.complete` intent. This is differential
evidence for the frozen examples, not proof that either IR is generally
equivalent.

Four workspace attempts isolate the authority layer. Both conditions receive a
budget of two and the same ordered requests. The broker denies the path outside
`reports/`, accepts the two in-scope writes, and denies the third in-scope write
after its budget is exhausted. The direct handler performs all four writes.
Both paths use the same registry and sidecar, and their authorized writes have
the same digest and completion-verifier result. The direct path's out-of-scope
artifact also passes content verification, demonstrating that output validity
does not imply authority compliance. Only the broker emits structured denial
records.

The accepted Phase 7 evidence is incorporated rather than relabelled as a new
experiment: 17 seeded semantic and authorization/recovery defects are detected,
and 63 component-by-transition fault cases preserve the recovery invariants.
Seven ambiguous post-submission cases remain explicitly uncertain and seven
post-mutation cases require reconciliation; neither is reported as automatic
success. The matrix separately records zero observed false completions and zero
duplicate logical effects within those bounded cases.

## Cost and usability observations

The evidence preserves compile, inspect/load, task startup, message, grant,
broker, journal, adapter, recovery, and verifier latency distributions from the
same host run. It also records VM pressure, artifact byte sizes, and source-file
and line counts for selected compiler, IR, broker, and durability groups. These
are characterization and structural proxies, not service-level objectives or
causal estimates. In particular, source lines across architectural groups are
not comparable to user-authored A-Lang lines.

No human authoring or reviewer study was run. The matrix can establish which
machine-readable records exist—manifest, grant description, broker audit,
normalized trace, journal, and completion witness—but it cannot establish that
people understand them faster or make fewer mistakes. Reviewer effort and
authoring burden therefore remain `not_run`, rather than being inferred from
field or line counts.

## Interpretation and limits

For this slice, compiled execution does not change the semantic answer relative
to either oracle; its demonstrated value is a deployable, inspectable BEAM
artifact. Law-declared IR brings explicit laws and mutation-sensitive tests,
but this single matched example does not show an advantage over conventional
typed IR. The broker is the only varied layer that prevents the safe but
out-of-scope and over-budget writes. Durability is necessary for the observed
recovery classifications, while the direct ablation has no basis for claiming
recovery.

The comparison uses a deterministic mock model, one host, one task family, and
small fixed effects. It does not measure live-provider variability,
multi-node behavior, language learnability, agent task success rates, or human
review. Those limits constrain the architecture decision in Section 8.3.

See the [reproducible demonstration](reproducible-demonstration-package.md),
[Phase 7 fault and performance characterization](../phase-07/fault-and-performance-characterization.md),
and the [Phase 8 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-08-end-to-end-demonstration-and-poc-decision.md).
