---
title: "Phase 2 Effects and Capability Requirements"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - capability-security
  - compiler-implementation
  - effect-system
  - proof-of-concept
aliases:
  - "Phase 2 authority semantics"
---

# Phase 2 Effects and Capability Requirements

## Purpose

This document freezes two related but separate Phase 2 judgments. Closed
effect sets state what operations a callable can reach. Capability requirements
state the least external authority a task asks a runtime to provide. A
requirement is an A-Lang-owned predicate, not a credential, token, grant, or
portable authorization protocol.

## Closed effect judgment

`perform E.operation(...)` contributes the operation's stable identity. Calls
propagate the complete effect set of the callee, branches and sequential
composition take set union, and literal/data nodes contribute the empty set.
Inference reaches a deterministic fixed point over the closed call graph.

Functions and completion predicates are pure and must infer the empty set.
Tasks declare their exact effect set: omitting a reachable operation and
declaring an unreachable operation are both errors. Duplicate annotations are
errors. Recursion, handlers, dynamic calls, and open or polymorphic effect rows
remain deferred, so a recursive call graph is rejected rather than assigned an
unspecified effect.

## Requirement domain

A normalized requirement contains:

- a stable resource identity and operation identity;
- an ordered set of typed string-equality, integer-equality, or string-prefix
  constraints;
- optional positive deadline, maximum-call, and maximum-byte limits.

Normalization strips the textual `_prefix` suffix from a prefix constraint's
key, sorts all entries and constraints, rejects duplicate keys and entries, and
rejects zero limits. Ordered sets provide deterministic equality and union.
Canonical serialization is compact JSON over those ordered structures.

One requirement subsumes another when it has the same resource and operation,
its limits are absent or at least as permissive, and every constraint it imposes
subsumes a constraint in the narrower requirement. Equality constraints match
exactly. A prefix constraint subsumes a narrower prefix or exact string with the
same canonical key.

## Coverage judgment

Every operation in a task's inferred effect set must have a normalized
requirement for that exact stable operation identity. Authority for an
operation outside the inferred set is rejected as unused. Direct effect sites
must also fit within declared limits:

- the number of direct sites cannot exceed `max_calls`; and
- a constrained `Workspace.write` path must be a string literal proven equal
  to an allowed path or inside an allowed prefix.

An unconstrained path requirement covers any path. A dynamic path under a
constrained requirement is rejected because the PoC has no refinement types
with which to prove it safe. Transitive calls propagate operations to the
calling task, so the caller must declare coverage too. Runtime grant matching,
budget consumption, revocation, delegation, and portable credential validation
remain later-phase runtime concerns.

## Failure and determinism contract

Effect and requirement failures are source-oriented and sorted by origin, code,
and message. No partially authorized module is returned. Effects, requirements,
constraints, and callable maps use ordered collections, so inference,
comparison, and serialization do not depend on declaration traversal or host
hash order.

## Reproducible evidence

Run the Section 2.3 gate from the repository root:

```console
make test-section-2-3
```

The effect tests cover transitive propagation, exact annotations, pure escapes,
recursion, missing coverage, workspace argument proof, and call budgets. The
requirement tests cover canonical form, union, equality, subsumption,
serialization, duplicate constraints, and invalid limits.
