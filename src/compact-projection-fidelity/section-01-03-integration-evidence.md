---
title: "Compact Projection Phase 1 Section 1.3 Integration Evidence"
kind: note
created: 2026-08-12
maturity: developing
tags:
  - confirmatory-corpus
  - evaluation
  - implementation-evidence
  - token-efficiency
aliases: []
---

# Compact Projection Phase 1 Section 1.3 Integration Evidence

## Conclusion

Section 1.3 is complete. The confirmatory corpus contains exactly 48 new
semantic cases: sixteen in each runtime family and two independent cases in
each of eight family/stratum cells. Every case stores natural-language
requirements, explicitly untrusted context, and a representation-neutral
oracle descriptor. A BEAM validator expands each descriptor into the inherited
closed comprehension contract and checks its semantic digest, authority,
budgets, scopes, child attenuation, completion evidence, and terminal class.

The corpus remains blinded to all six condition labels and both screening
tokenizers. It has no copied case identity, prompt, goal fact, resource, or
path from the Stream 02 development corpus. All 48 semantic digests are unique,
all top-level and oracle field shapes match, and the exclusion/replacement log
is present and empty because no authored item failed the registered audit.

## Operational registration

The Stream 02 Ornith and Mixtral families are retained for comparability, but
their mutable shorthand tags are not. The registration pins the exact Ollama
identifiers and SHA-256 manifest identities:

| Family | Exact identifier | Manifest SHA-256 | Local snapshot |
| --- | --- | --- | --- |
| Ornith | `hf.co/unsloth/Ornith-1.0-35B-GGUF:UD-Q5_K_M` | `6959cafd1e245e8fd083f223c951d6f1e3c778b13d1ad33b4919f3c465927a25` | installed and matching |
| Mixtral | `mixtral:8x7b` | `a3b6bef0f836ff29ddb576a80eeb1b7def43ec9b809466f62e96adb871fe8498` | registry identity fixed; not installed |

Mixtral's current absence does not substitute another model or weaken the
design. The availability rule blocks authorization until both local manifests
match; a later mismatch invalidates the campaign. The request profile also
freezes sampling, context, output, streaming, seed derivation, turn count,
tool access, and schema assistance.

Provider-reported usage is authoritative for provider and full-request token
metrics. Exact tiktoken `0.12.0` `cl100k_base` and `o200k_base` identities are
registered only for reproducible document screening; estimated provider usage
is forbidden.

## Bounds and negative evidence

Network access defaults to disabled and requires the exact environment opt-in
`ALANG_ALLOW_COMPACT_MODEL_CALLS=1`. The policy requires no credentials and
accepts only the loopback Ollama endpoint. It freezes 2,304 primary requests,
4,608 total requests, one transport-linked replacement per primary cell,
8,192 source bytes, 32,768 full input bytes, 8,192 response bytes and output
tokens, 120 seconds per request, 9,600 local-compute minutes, and zero external
monetary cost.

Mutation tests reject copied development wording, family/design drift, child
scope widening, a substituted manifest digest, an enabled network default,
and a 4,609-request ceiling. No provider adapter, model request, credential,
projection, efficacy score, or model-visible materialization occurs.

## Reproduction

```bash
make test-compact-section-1-3
```

The command reruns Sections 1.1 and 1.2, compiles the reused semantic contract
and new validators to deterministic BEAM files, validates every corpus case,
and runs all registration and mutation checks on ERTS.

## Connections

- [Phase 1 plan](../../60-planning/03-compact-projection-fidelity/phase-01-campaign-contract-and-confirmatory-corpus.md)
- [Confirmatory corpus](../../assets/compact-projection-fidelity/corpus/confirmatory-corpus-v1.json)
- [Provider profiles](../../assets/compact-projection-fidelity/campaign/provider-profiles-v1.json)
- [Tokenizer profiles](../../assets/compact-projection-fidelity/campaign/tokenizer-profiles-v1.json)
- [Campaign policy](../../assets/compact-projection-fidelity/campaign/campaign-policy-v1.json)
