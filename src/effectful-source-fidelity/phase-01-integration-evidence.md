---
title: "Phase 1 Experiment Freeze Evidence"
kind: note
created: 2026-08-05
maturity: developing
tags:
  - evaluation
  - implementation-evidence
  - llm-agents
  - task-language
aliases: []
---

# Phase 1 Experiment Freeze Evidence

## Conclusion

Phase 1 passes its offline gate. The comprehension oracle, paired source
contracts, 24-case corpus, exact provider cells, operational ceilings, metrics,
bootstrap rule, safety vetoes, and terminal decisions are frozen before any
hosted observation. All trusted validators compile to BEAM and execute on
ERTS; the default test path has no provider adapter and performs no network
request.

This authorizes Phase 2 source parsing. It does not authorize a live campaign,
claim an A-Lang fidelity advantage, or make the reviewed A-Lang pairing a
substitute for parser evidence.

## Pre-registration identity

The ordered registration contains 86 files: ten contract/configuration files,
three campaign files, one corpus manifest, 24 A-Lang candidates, 24 typed-JSON
controls, and 24 representation-neutral answer keys.

| Evidence | Value |
| --- | --- |
| Registration digest | `27691c32c8a9a32c0fe54292e68be8fb676ca2ab3d8267d6b908d99d3449ecf2` |
| Evidence-record digest | `bef06e40baf9a5f35085d5a5562f435712cc40463a7e4356f945f7b5acdbf935` |
| Digest algorithm | SHA-256 over deterministic canonical ETF path/hash/size tuples |
| Schema count | 7 closed JSON Schemas |
| Hosted calls observed | 0 |
| Network default | Disabled |

Two independent writes from the same checkout produce byte-identical JSON
evidence. Generated evidence is intentionally retained below the ignored
`build/effectful-source-fidelity/phase-01/evidence/` path; the digest above is
the stable repository-facing identity.

## Corpus inventory

The [corpus manifest](../../assets/effectful-source-fidelity/corpus/corpus-manifest-v1.json)
contains one and only one cell for every family×variant combination.

| Family | Cases | Candidate documents | Control documents | Answer keys |
| --- | ---: | ---: | ---: | ---: |
| Single-model artifact | 8 | 8 | 8 | 8 |
| Repair and publish | 8 | 8 | 8 | 8 |
| Attenuated delegation | 8 | 8 | 8 | 8 |
| **Total** | **24** | **24** | **24** | **24** |

Every effectful attenuated-delegation case includes an ordered parent model
judgment, one more-restricted child call, parent-only publication, and a child
budget no greater than its parent. Every family includes simple,
constraint-heavy, scope/budget, error-branch, missing-information,
irrelevant-context, prompt-injection, and semantic-perturbation variants.

Each control is decoded with duplicate-aware OTP JSON and equals its answer
key after origins and set presentation are removed. Each A-Lang candidate is
hand-authored and binds the same reviewed semantic digest outside the
model-visible region. Phase 2 must parse that visible source and reproduce the
digest without using the metadata assertion before any case can enter a trial.

## Provider and operational freeze

The [provider profiles](../../assets/effectful-source-fidelity/campaign/provider-profiles-v1.json)
pin these cells without aliases:

| Family | API | Exact model | Effort | Turns | Tools/schema | Output bounds |
| --- | --- | --- | --- | ---: | --- | --- |
| Ollama | ChatCompletions | `ornith-1.0` | Medium | 1 | Disabled | 8,192 tokens / 8,192 accepted bytes |
| Ollama | ChatCompletions | `mixtral-8x7b` | Medium | 1 | Disabled | 8,192 tokens / 8,192 accepted bytes |

The [campaign policy](../../assets/effectful-source-fidelity/campaign/campaign-policy-v1.json)
requires `ALANG_ALLOW_LIVE_MODEL_CALLS=1` and validates that both models are
reachable through the local Ollama server. It caps primary calls at 288, all
calls at 576, and tracks token counts for local cost reporting. A definitive
malformed or schema-invalid response remains a zero primary score even when its
single permitted repair succeeds as secondary evidence. Blind retry is
forbidden; proved-not-submitted retries and no-definitive-response replacements
remain linked and count toward the total.

## Metrics and decision rule

The [decision contract](../../assets/effectful-source-fidelity/contracts/metrics-and-decision-v1.json)
makes exact normalized semantic fidelity the unweighted primary metric. It
registers component exactness, omissions, inventions, authority widening,
false completion, repair yield, latency, tokens, and cost as secondary
observations.

Promotion requires, separately in both model families, at least a five-point
A-Lang advantage and a paired 95% percentile interval whose lower bound is
strictly positive. The bootstrap resamples eight cases within each task family,
retains all three paired repetitions, performs 10,000 resamples, and uses seed
`20260805`. Failure to promote selects JSON only when both control cells reach
80%; otherwise it stops source expansion. Any registered safety regression is
a veto, and an invalid campaign stops without an efficacy conclusion.

## Negative and scope evidence

The integration suite detects every pre-registered mutant:

| Mutant | Rejection boundary |
| --- | --- |
| Unknown comprehension field | Closed BEAM comprehension validator |
| Duplicate case | Unique corpus identity and family×variant matrix |
| Missing cell | Exact 24-cell corpus count |
| Model-visible answer leak | Candidate visibility boundary |
| Unequal semantic digest | Candidate/control/oracle pair validator |
| Unbounded output limit | Closed budget validator |
| Alias model identifier | Exact provider-profile validator |
| Changed promotion threshold | Frozen decision-contract validator |

The frozen-scope audit scans all 24 model-visible candidates, accepts only the
three registered effect families, and finds no recursion, polymorphism,
parallelism, distribution, portable delegation protocol, arbitrary call,
package-management, self-hosting, or categorical surface construct. It also
finds no foreign trusted source in the implementation directory. Runtime tests
confirm each Phase 1 validator is loaded from a `.beam` file.

## Reproduction

From the repository root:

```bash
make test-fidelity-section-1-4
make build-fidelity-phase-1-evidence
make test-fidelity-phase-1
```

The first command compiles with `-Werror +deterministic`, validates every
contract and corpus cell, runs the mutant matrix, reproduces the digest twice,
and audits scope. The second writes the inspectable JSON evidence. The third is
the complete Phase 1 gate and is also part of the repository-wide `make test`.

## Connections

- [Phase 1 implementation plan](../../60-planning/02-effectful-source-fidelity/phase-01-experiment-contract-and-frozen-corpus.md)
- [Effectful source fidelity roadmap](../../60-planning/02-effectful-source-fidelity/README.md)
- [Task-language inquiry](../../40-inquiries/can-a-task-language-improve-llm-agents.md)
- [Implementation index](README.md)
