---
title: "A PropEr Integration of Types and Function Specifications with Property-Based Testing"
kind: source
created: 2026-07-31
authors:
  - "Manolis Papadakis"
  - "Konstantinos Sagonas"
published: 2011
citation_key: papadakisSagonas2011PropEr
container: "Proceedings of the 10th ACM SIGPLAN Workshop on Erlang"
edition: null
isbn: null
doi: "10.1145/2034654.2034663"
url: "https://proper-testing.github.io/papers/proper_types.pdf"
accessed: 2026-07-31
tags:
  - property-based-testing
  - proper
  - type-systems
  - categorical-laws
aliases:
  - "PropEr types and properties"
---

# A PropEr Integration of Types and Function Specifications with Property-Based Testing

## Reference

Manolis Papadakis and Konstantinos Sagonas. “A PropEr Integration of Types and
Function Specifications with Property-Based Testing.” In *Proceedings of the
10th ACM SIGPLAN Workshop on Erlang*, 39–50, 2011.
[doi:10.1145/2034654.2034663](https://doi.org/10.1145/2034654.2034663).
[Open paper](https://proper-testing.github.io/papers/proper_types.pdf) ·
[Current project](https://github.com/proper-testing/proper) ·
[QuviQ QuickCheck overview](https://quviq.com/documentation/eqc/overview-summary.html)

## Contribution

PropEr is an open-source property-based testing system inspired by QuviQ
QuickCheck. It generates inputs from types and custom generators, checks
properties repeatedly, and shrinks failing cases. Its ecosystem includes
state-machine testing for systems whose behavior is better represented as
generated command sequences than isolated function calls.

## Finding

Property-based testing can turn algebraic laws into executable, generative
checks. For pure functions, examples include identity, associativity, functor
identity and composition, product/coproduct behavior, and serialization
round-trips. Shrinking can reduce a complex generated workflow to a small
counterexample that exposes a compiler or runtime defect.

For effectful concurrent code, a property needs a model and an observation
function. Literal equality of process identifiers, references, timestamps, or
scheduler traces is normally meaningless. State-machine and trace properties
can instead compare externally visible results after normalizing fresh names
and permitted reorderings.

## Relevance

PropEr is the practical open-source default for testing categorical laws on the
actual BEAM runtime. The new language can emit small adapter modules or invoke a
versioned runtime testing ABI; PropEr need not interpret agent programs or
become part of the production language.

The law runner should remain framework-neutral so commercial Erlang QuickCheck,
a compiler-host property library, or a proof-generated conformance suite can
reuse the same generators and observations.

## Limits

Passing generated tests is evidence of implementation conformance, not a proof
that a law holds universally. Generators can miss important regions, equality
can be chosen incorrectly, and shrinking concurrent histories is difficult.
Proofs for the small semantic core and property tests for its compiler/runtime
realization are complementary, not interchangeable.

## Derived notes

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
- [Can categorical semantics materially improve an agent language?](../40-inquiries/can-categorical-semantics-improve-agent-language.md)
- [Can BEAM support a native agent language safely?](../40-inquiries/can-beam-support-a-native-agent-language.md)
