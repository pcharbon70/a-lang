---
title: "Phase 8 Deferred Work Ledger"
kind: note
created: 2026-08-04
maturity: developing
tags:
  - deferred-work
  - implementation-planning
  - proof-of-concept
  - scope-control
aliases: []
---

# Phase 8 Deferred Work Ledger

## Rule

Deferred means unimplemented and unauthorized unless its trigger is met and a
new planning stream is explicitly approved. It does not mean “nearly
complete.” The effectful source-to-IR successor authorized by the original
[architecture decision](proof-of-concept-architecture-decision.md) has ended
with a conservative invalid-campaign stop; it authorizes no further expansion.

## Language and semantics

| Work | Why deferred | Reconsider only when |
| --- | --- | --- |
| General recursion | Complicates termination, budgets, and verifier reasoning | A bounded benchmark cannot be expressed with current state machines |
| Parametric polymorphism | Expands checker and backend without testing language value | Repeated source tasks demonstrate concrete duplication |
| Parallel composition | Requires non-interference, deterministic observation, and effect-order laws | Sequential effectful source fidelity is established |
| User-visible categorical notation | No evidence of authoring or model benefit | A study shows it beats familiar notation |
| More products, coproducts, and protocol forms | The present typed IR is sufficient for the slice | A named acceptance task requires them |
| Self-hosting | Would entangle bootstrap confidence with language evaluation | The surface and compiler contract are stable across releases |

## Runtime and authority

| Work | Why deferred | Reconsider only when |
| --- | --- | --- |
| Distribution and multi-node scheduling | BEAM distribution is not a security boundary; recovery semantics are local | Identity, partition, placement, and durable coordination requirements are explicit |
| Portable delegation and UCAN | The PoC deliberately uses opaque VM-local grants | A cross-trust-domain use case cannot use local issuance |
| Hot code upgrades | Generated module lifecycle and state migration are unresolved | A long-lived deployment requirement exists |
| Additional effect families | Each new effect enlarges registry, policy, adapter, recovery, and verification surface | The effectful source comparison needs a specific second resource |
| Hostile-code sandbox service | OS isolation is required but not part of compiler semantics | Untrusted generated modules must execute rather than be statically constrained |
| Production identity, audit export, and key management | No production deployment is approved | Threat model and operators are identified |

## Models, durability, and operations

| Work | Why deferred | Reconsider only when |
| --- | --- | --- |
| Live-provider integration and hardening | Fixed adapters exist, but the closed campaign made zero hosted calls and provider behavior remains unmeasured | A newly authorized study declares providers, privacy policy, prices, cost, and replay rules |
| Provider routing and model fallback | Would confound language evaluation | Single-provider fidelity evidence exists |
| Distributed or external durable store | Local file evidence is sufficient for bounded recovery | Recovery objectives require host-loss tolerance |
| Exactly-once external effects | Generally unavailable without resource cooperation | A resource exposes transactional or idempotent semantics that can be specified |
| Production observability, alerting, backup, and restore | No service is approved | A deployment SLO and operator model exist |
| Package management and release signing | The language and compatibility surface are not stable | Multiple independently versioned packages exist |

## Research and validation

| Work | Why deferred | Reconsider only when |
| --- | --- | --- |
| Formal categorical proof | Current properties are falsification tools, not a proof basis | Stable semantics and a theorem target are selected |
| Multi-OTP/architecture matrix | Only OTP 29.0.4 on x86-64 is declared | A second supported environment is proposed and reproducible |
| Representative alternative-runtime study | Current typed baselines characterize components, not runtime superiority | A workload and equivalent runtime are specified |
| Broad performance and scale campaign | One host and small fixtures cannot define service capacity | Representative task arrival, state, effect, and retention distributions exist |
| Human authoring/reviewer study | No current human-benefit claim is accepted | Such a claim is required for promotion |
| Broader model-family task study | The source subset no longer requires constructed IR, but the first hosted campaign was closed invalid | A new question, budget, providers, and pre-registration receive explicit authorization |

## Completed boundary disposition

The effectful source-language mechanics were implemented, while the hosted
comparison was closed invalid without efficacy evidence. The canonical
[successor decision](../effectful-source-fidelity/effectful-source-fidelity-architecture-decision.md)
therefore stops both experimental authoring surfaces and retains the bounded
runtime-enforcement evidence. Nothing in this ledger becomes authorized as a
consequence.
