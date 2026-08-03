---
title: "Can BEAM support a native agent language safely and maintainably?"
kind: inquiry
created: 2026-07-31
status: open
tags:
  - agent-programming
  - beam
  - compiler-design
  - evaluation
aliases:
  - "BEAM backend feasibility"
---

# Can BEAM support a native agent language safely and maintainably?

## Why this matters

BEAM appears unusually well suited to numerous long-lived, concurrent,
failure-aware agent state machines. That conceptual fit is not enough. A new
language needs a supported compiler boundary, stable source semantics, durable
effects, defensible security isolation, controllable dynamic code, and evidence
that its categorical laws survive compilation and concurrency.

The [BEAM runtime deep dive](../20-notes/beam-runtime-for-native-agent-language.md)
now requires a BEAM-resident frontend and language-owned IR lowered through
OTP's Erlang Abstract Format. “Runs on BEAM” covers the trusted compiler
toolchain as well as generated programs. This inquiry asks whether that design
survives implementation, version changes, adversarial workloads, and
comparison with simpler runtimes.

## Operational question

Can a compiler whose lexer, parser, semantic passes, IR transformations,
backend adapter, command driver, and validators all execute as BEAM modules
produce safe and maintainable BEAM artifacts—without using Erlang, Elixir,
Gleam, or another language to interpret A-Lang programs—that:

- preserve the source language's types, effects, capabilities, and
  observational laws;
- support thousands of concurrent waiting agents with predictable tail
  latency;
- recover from process, port, node, and storage failures without silently
  duplicating effects;
- bound mailboxes, atoms, processes, memory, code versions, and external work;
- isolate untrusted tools and generated code at an OS boundary;
- remain operable across explicitly supported OTP releases?

## Provisional answer

Probably, if ERTS hosts both the trusted A-Lang compiler application and the
generated process runtime, and OTP's compiler is used as a versioned in-VM
backend service. The answer becomes doubtful if a foreign executable owns a
trusted compiler pass, if direct Core Erlang or BEAM emission is required, if
high-churn programs create unbounded module atoms, or if in-memory process
recovery is expected to substitute for durable workflow and effect semantics.

### H0 — whole-toolchain residency

Every trusted source-to-artifact component can run as a `.beam` module on ERTS.
Bootstrap Erlang source is permitted, but an Erlang AST evaluator, generated
Erlang source program, foreign compiler executable, or deployable IR evaluator
cannot satisfy the compiler or runtime gate.

## Working hypotheses

### H1 — supported lowering

A small Abstract Format subset can express the language's pure, effectful, and
actor constructs while passing `strong_validation` and remaining tractable
across selected OTP releases.

### H2 — runtime fit

Generated supervision subtrees will support more waiting agent sessions and
localize failures better than an OS-thread-per-session or callback-oriented
baseline, without unacceptable message-copying or mailbox cost.

### H3 — semantic preservation

An IR evaluator and the compiled BEAM backend will produce equivalent public
observations for generated well-typed programs, after normalizing fresh names,
virtual time, and permitted independent event reorderings.

### H4 — durable effects

A brokered intent/result protocol with idempotency keys will prevent duplicate
acknowledged effects under injected worker and node failures. Supervision alone
will not.

### H5 — security boundary

Closed imports, artifact verification, and runtime capabilities will prevent
accidental authority escalation, but malicious generated programs will still
require a disposable OS-level sandbox.

### H6 — categorical validation

PropEr generators and state-machine models will find seeded violations of
identity, associativity, functor, handler, serialization, recovery, and
protocol laws and shrink them to useful counterexamples.

### H7 — lifecycle ceiling

Content-addressed artifact reuse, admission quotas, and disposable build nodes
will keep permanent atom and module growth bounded. Per-run module generation
will fail this requirement.

## Paths to explore

1. Build the smallest BEAM-resident compiler spike that creates Abstract
   Format terms without generating Erlang source or invoking a foreign
   compiler executable.
2. Compile on OTP 29 with `strong_validation` and deterministic output; inspect
   imports and custom chunks before isolated loading.
3. Implement one pure evaluator, one deterministic effect handler, and one
   concurrent coordinator semantics.
4. Generate typed terms and compare evaluator results with compiled BEAM
   observations.
5. Create a PropEr adapter and seed one defect per stated categorical or
   runtime law.
6. Build a supervision subtree with bounded admission, deadlines, cancellation,
   late-reply handling, and trace emission.
7. Put a mock external effect behind a durable intent/result journal; kill
   processes and nodes at each transition.
8. Fuzz the parser, Abstract Format adapter, message decoder, artifact loader,
   and capability broker.
9. Measure scheduler latency, reductions, GC, binary memory, mailbox growth,
   and recovery under representative agent workloads.
10. Repeat against each supported OTP version and against a simple alternative
    runtime baseline.

## Findings

- OTP 29 explicitly recommends Erlang source or Abstract Format to implementors
  of other languages and warns against direct Core Erlang or BEAM assembly.
- Core Erlang is a compact semantic IR, not the BEAM instruction set or a
  stable public backend.
- OTP 29's opcode source table has 191 numbered entries, of which 132 are
  active and 59 obsolete; the exact set evolves.
- BEAM's process and failure model fits I/O-bound agent coordination, but its
  mailboxes are not durable or bounded and its same-node processes are not a
  hostile-code sandbox.
- Leex and Yecc generate Erlang source and are optional bootstrap tools, not a
  VM-provided neutral frontend.
- PropEr can test law implementations on VM, but proof and observational
  semantics remain necessary for universal or concurrent claims.
- The Phase 2 counter compiler now provides initial evidence for H0: its
  handwritten lexer and parser, canonical ETF boundary, semantic checker,
  typed IR lowering, projections, test oracle, bridge, and compiler driver are
  Erlang-bootstrap modules compiled to `.beam` and run by OTP 29 ERTS. This is
  feasibility evidence for the narrow slice, not yet a general compiler.

## Resolution criteria

Resolve positively only after the prototype passes all of these gates:

- compiler validation and differential semantics across the supported OTP
  matrix;
- machine-checkable evidence that every trusted compiler component was loaded
  as a BEAM module and that no foreign compiler executable participated;
- no unbounded atom or dynamic-module path under load;
- bounded mailbox behavior and acceptable tail latency;
- correct durable effect recovery under fault injection;
- artifact and capability enforcement plus OS isolation for hostile code;
- law tests that detect and shrink deliberately seeded failures;
- an operational comparison showing a material advantage over a simpler
  runtime.

Resolve negatively if the supported compiler boundary proves too unstable, if
durable execution requires a separate engine that becomes the real runtime, or
if BEAM's resource and deployment constraints erase its concurrency advantage.

## Outcome

Open. The source-level architecture is credible, and a local Abstract Format
spike has demonstrated the basic compile/load path. The decisive evidence must
come from a pinned OTP 29 prototype, a property and fault-injection harness,
and representative performance measurements.
