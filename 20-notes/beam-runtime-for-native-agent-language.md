---
title: "BEAM as the runtime for a native agent language: a deep dive"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - agent-programming
  - beam
  - compiler-design
  - category-theory
  - property-based-testing
aliases:
  - "BEAM runtime for A-Lang"
  - "Native agent language on BEAM"
---

# BEAM as the runtime for a native agent language: a deep dive

## Executive conclusion

BEAM is a strong candidate for the *control-plane runtime* of a new language
for agents. Its lightweight processes, asynchronous messages, preemptive
scheduling, per-process garbage collection, links, monitors, timers,
supervision conventions, code loading, and external-process ports align well
with long-lived agents that spend much of their time waiting for models, tools,
humans, and other agents.

The new language does not need to be interpreted by Erlang, Elixir, Gleam, or
another BEAM language. The recommended architecture is:

```text
agent-language source
  -> native lexer, parser, resolver, and type/effect checker
  -> small typed categorical IR owned by the language
  -> actor/effect lowering
  -> Erlang Abstract Format adapter pinned to an OTP release
  -> OTP compiler validation and BEAM emission
  -> signed .beam artifacts plus language metadata
  -> ERTS / BeamAsm execution
```

The generated module is native BEAM program code. There is no `eval` loop and
no translation to an existing surface language at runtime. On supported
architectures BeamAsm further translates loaded BEAM instructions to native
machine code while retaining BEAM semantics.

There is one important correction to the initial premise. Core Erlang has a
small, explicit grammar, but it is a compiler intermediate language, not the
BEAM instruction set. OTP 29's opcode table has 191 numbered entries—132
active and 59 obsolete—and both Core internals and BEAM instructions can change
between major releases. OTP 29 now gives explicit
[guidance for language implementors](../30-sources/erlang-otp-2026-language-implementors.md):
generate Erlang source or Erlang Abstract Format, and avoid direct Core Erlang
or BEAM assembly as a production boundary. Abstract Format is preferable here
because it does not make Erlang source the generated language.

Core Erlang still has two valuable roles:

1. it is a model for designing a small normalized agent IR;
2. it can be an experimental cross-checking backend and a bridge to formal
   actor semantics.

Property-based testing is also a good match, with a qualification. Erlang
QuickCheck is the historically important system; open-source
[PropEr](../30-sources/papadakis-sagonas-2011-proper.md) is the practical
default for an open toolchain. It can test identity, associativity, functor,
product, coproduct, serialization, effect-handler, and state-machine
properties on the actual VM. Passing generated tests does not prove a
categorical law. Pure laws can use value equality, while effectful and
concurrent laws require observational or trace equivalence.

The recommendation is therefore conditional but positive:

> Use BEAM as the concurrent execution substrate, use a native compiler and an
> A-Lang-owned categorical IR, lower through OTP's supported Abstract Format,
> and treat Core Erlang and direct BEAM emission as research backends. Put
> external effects behind a durable capability broker, and never confuse BEAM
> process isolation, supervision, or messaging with a security sandbox,
> durable workflow engine, or exactly-once transaction system.

## Scope and decision criteria

This study asks whether BEAM should run programs in a new agent-specific
language. It does not ask whether an agent framework should be authored in
Erlang or whether the new language should copy Erlang syntax.

The language is assumed to need:

- many concurrent, mostly I/O-bound agent sessions;
- explicit state, message, tool, model, timer, and human-interaction semantics;
- typed categorical composition and law-driven transformations;
- cancellation, deadlines, monitoring, and structured failure recovery;
- durable checkpoints and auditable effects;
- isolation of untrusted tools and model-serving code;
- reproducible artifacts and source-level diagnostics;
- a path to formal and generative validation.

BEAM is a good choice only if it improves these properties without forcing the
language to inherit unstable compiler internals or unsafe runtime assumptions.

“Native agent language” means that its compiler, static semantics, module
system, effect system, and runtime-visible behavior belong to the new language.
It does not mean reimplementing the BEAM loader, garbage collector, scheduler,
or OTP compiler. Reusing those components is the reason to target the VM.

## 1. Separate four levels that are easily conflated

### 1.1 The agent source language

This is what people and models write. It should express goals, schemas,
branches, effects, capabilities, state machines, budgets, completion evidence,
and composition in vocabulary suited to agents. It should not expose Erlang
syntax merely because the runtime is BEAM.

### 1.2 The language-owned semantic IR

The IR is the stable contract of the new compiler. A useful minimal distinction
is:

```text
pure  A -> B
task  A ~{effects, capabilities}-> B
agent S -> Step[Observation, Action, S, Outcome]
```

It should normalize rich surface constructs into typed products, coproducts,
functions, explicit effect operations, handlers, state transitions, and
serial or parallel composition. Category laws belong here because this is the
level the project owns and can keep stable.

### 1.3 Core Erlang

[Core Erlang](../30-sources/carlsson-et-al-2004-core-erlang-specification.md)
is a compact functional compiler IR with explicit bindings, calls, matching,
exceptions, binaries, and concurrency operations. Its economy is attractive,
but OTP's `cerl` API is internal and OTP 29 warns that `primop` details can
change without notice at a major version. Generating unusual Core forms can
exercise backend paths not reached by the Erlang compiler.

Core Erlang should inform the design and may support experiments; it should not
be confused with a versioned third-party compiler ABI.

### 1.4 BEAM code and ERTS

BEAM code is the loader and execution representation. ERTS supplies processes,
scheduling, garbage collection, messaging, timers, ports, code loading, and
distribution. BeamAsm maps BEAM operations to native instructions at module
load time on supported CPUs.

The [current instruction machinery](../30-sources/erlang-otp-2026-beam-execution.md)
is optimized as part of OTP and changes with it. A compiler that emits raw
BEAM assembly or writes `.beam` files directly must reproduce operand
conventions, stack and frame rules, exception metadata, labels, literal and
line tables, loader transformations, and safety invariants. That is avoidable
work and a poor default trust boundary.

## 2. Why BEAM fits agent execution

### 2.1 Agents naturally decompose into processes

An agent is not just a function call. It waits, observes, makes decisions,
starts effects, receives late replies, handles cancellation, updates state, and
may live far longer than any individual request. The
[ERTS process model](../30-sources/erlang-otp-2026-process-runtime.md) provides a
direct runtime representation for those activities.

A process is a useful owner for one mutable state machine. Links and monitors
make lifecycle relationships explicit without sharing state. Asynchronous
signals fit model and tool calls. Timers express deadlines and wakeups.
Reduction-based scheduling keeps a CPU-consuming process from voluntarily
owning the scheduler forever, while many waiting processes remain cheap.

This is particularly suitable for a coalgebraic view of agents. A step observes
the current state and environment and yields a continuation, an output, or a
terminal result. A receive loop is an operational realization of that shape;
the compiler can preserve the higher-level semantics instead of exposing a raw
mailbox language.

### 2.2 Per-process memory improves fault locality

ERTS normally allocates a stack and heap per process and garbage-collects them
independently. A short-lived tool worker can release most of its memory when it
exits, and garbage collection of one ordinary process does not require a
global stop across every agent.

This is not absolute isolation. Large binaries can be shared by reference,
messages can be copied, and the node still shares schedulers, memory, native
extensions, atom tables, and external resources. The advantage is local memory
ownership and collection, not a security boundary.

### 2.3 Failure topology is a first-class runtime idea

Links, monitors, and
[supervision](../30-sources/erlang-otp-2026-supervision-and-releases.md) let the
compiler map a language-level fault tree into runtime structure. A policy
monitor can outlive an effect worker; a session supervisor can decide whether
to restart only an adapter or terminate the whole session; restart intensity
can stop a permanent failure from becoming an infinite retry storm.

The language should nevertheless define its own fault vocabulary. “Process
restarted,” “logical action retried,” “workflow replayed,” and “external effect
compensated” are different events.

### 2.4 Ports match the agent ecosystem

Large models, Python tool ecosystems, browsers, databases, and GPU servers do
not need to move inside BEAM. Ports or network sidecars keep those components
in separate operating-system processes. A crash or memory leak in an inference
server then need not corrupt the agent node.

The [OTP security and interoperability guidance](../30-sources/erlang-otp-2026-interoperability-and-security.md)
recommends external processes where practical because native implemented
functions run inside the VM and can block, corrupt, or crash it. Dirty
schedulers reduce scheduling damage but do not isolate faulty native code.

### 2.5 Code loading and introspection help long-lived systems

BEAM modules can carry debug information and custom chunks. A language can
embed:

- source and IR hashes;
- compiler and OTP versions;
- source maps and symbolic function names;
- declared effects and capabilities;
- a schema and state-version identifier;
- provenance and reproducible-build data;
- a signature reference for loader policy.

Hot loading permits a current and an old module version to coexist, but the
language must decide when an agent changes version and how state migrates. The
loader mechanism does not supply those semantics.

## 3. What BEAM does not solve

### 3.1 Mailboxes are not durable bounded queues

BEAM messages are asynchronous signals delivered to process mailboxes. Order
is guaranteed only from the same sender to the same receiver. Selective receive
can scan preceding unmatched messages, and a producer can outpace a consumer.
Distribution failure can lose messages.

The language runtime therefore needs:

- explicit inbox capacity and admission policy;
- per-sender or per-effect quotas;
- deadlines and stale-reply handling;
- correlation and deduplication identifiers;
- observability for mailbox age and size;
- backpressure at the broker or transport boundary;
- a durable queue when loss across node failure is unacceptable.

An unbounded mailbox containing model-sized payloads is a denial-of-service
mechanism, not an agent architecture.

### 3.2 Supervision is not exactly-once execution

Suppose an email service accepts a request, but the worker dies before recording
the response. A supervisor can restart the worker; it cannot know whether
sending again is correct. Exactly the same issue applies to payments,
deployments, database writes, and human notifications.

Effects should pass through a durable broker with:

1. an intent record written before dispatch;
2. a stable idempotency key;
3. an adapter that propagates that key when the external system supports it;
4. a durable result record;
5. reconciliation for ambiguous completion;
6. an explicit compensating action where appropriate.

The process tree handles liveness and containment. The effect protocol handles
semantic correctness.

### 3.3 Process isolation is not hostile-code isolation

Processes on one node share the VM's finite resources and authority. Atom-table
exhaustion, memory pressure, pathological binary handling, unsafe native code,
or a deliberately malicious module can affect the whole node. Distributed
Erlang also assumes trusted nodes; a shared cookie is not a zero-trust security
model.

The compiler and loader should enforce a closed runtime ABI, reject arbitrary
module calls, and verify artifact provenance and imports. Untrusted generated
programs or tool code should still run in disposable OS-level sandboxes with
CPU, memory, network, filesystem, and time limits. Static capabilities are most
valuable when a separate broker enforces them.

### 3.4 BEAM is not the model-inference data plane

BEAM excels at orchestration and concurrency. Tensor kernels, GPU scheduling,
large vector operations, and foreign runtimes belong in specialized services.
Moving them into long NIF calls would trade away the VM's fault isolation and
scheduler properties.

### 3.5 Concurrency is not deterministic composition

Sequential composition can usually preserve an ordinary input/output relation.
Parallel agent actions can race through external state, budget counters, tool
limits, and mailboxes. A symmetric monoidal `par` operator is sound only when
an effect and resource analysis establishes non-interference or when the
semantics explicitly admit the possible interleavings.

## 4. Choosing the compiler boundary

OTP 29's official compiler documentation makes the tradeoff clearer than older
third-party guidance.

| Boundary | Existing-language interpreter? | Stability and safety | Recommendation |
| --- | --- | --- | --- |
| Generate Erlang source | no runtime interpreter, but Erlang becomes generated surface | supported and easy to debug | viable bootstrap, rejected as the primary identity of this language |
| Generate Erlang Abstract Format | no | supported compiler input; release-coupled | **production default** |
| Generate Core Erlang | no | specified language, internal compiler details and `primop` drift | semantic reference and experimental backend |
| Generate BEAM assembly | no | instructions and conventions change; malformed code can crash VM | research only |
| Write `.beam` directly | no | owns file, loader, validation, and opcode compatibility | reject unless a future stable API appears |

### 4.1 Why Abstract Format wins

Abstract Format is an Erlang-term representation of syntax, not Erlang source
text. A native compiler can construct those terms using the external term
format or a small versioned compiler service. `compile:forms/2` can validate and
emit a BEAM binary. This retains OTP's optimizer and loader invariants.

The compiler should target a deliberately small subset:

- fixed-shape functions and local calls;
- explicit `case` control flow;
- tuples, maps, binaries, integers, lists, and bounded fixed atoms;
- receive and process primitives only through generated runtime adapters;
- no arbitrary dynamic apply;
- no direct native extension access;
- no user-controlled atom construction.

Every build should first run `strong_validation`, then compile with
`deterministic`, inspect the result through `beam_lib`, verify imports and
metadata, and load it in an isolated test node before promotion.

A local feasibility spike with OTP 27 constructed an Abstract Format module
programmatically, validated it, emitted a 484-byte BEAM binary, loaded it, and
executed a function returning `{ok, 42}`. This demonstrates the path, not
production readiness; the same spike must be checked against the chosen OTP 29
toolchain and each supported deployment release.

### 4.2 How to use Core Erlang without depending on it

The language-owned IR can adopt Core Erlang's strengths—few constructs,
explicit evaluation, easy traversal—while remaining independent. A compiler
pass can optionally print or ingest Core Erlang for:

- inspecting lowering decisions;
- differential tests against the Abstract Format backend;
- connecting with formal semantics;
- experimenting with optimizations;
- diagnosing OTP compiler changes.

Production artifacts should not depend on an undocumented `.core` textual
format or assume that Core `primop` names remain fixed.

### 4.3 Leex and Yecc are optional bootstrap tools

[Leex and Yecc](../30-sources/erlang-otp-2026-leex-and-yecc.md) are mature lexer
and LALR-1 parser generators, but they generate Erlang source. The BEAM VM does
not itself offer a language-neutral parser frontend.

Three coherent choices exist:

1. implement the production frontend in a non-BEAM host language and emit the
   IR or Abstract Format;
2. bootstrap a reference parser with Leex/Yecc, then replace it during
   self-hosting;
3. keep Leex/Yecc only as a differential parser oracle.

The first choice most directly meets the requirement. Rust, Zig, C++, or
another implementation language could host the compiler; that choice should
be based on parser, type-system, packaging, and FFI needs rather than BEAM
affinity.

## 5. Proposed runtime architecture

### 5.1 Compilation and loading

```text
source
  │
  ├─ lexical + concrete syntax diagnostics
  ├─ name, schema, type, effect, and capability checking
  ├─ desugaring to categorical IR
  ├─ law-safe normalization and optimization
  ├─ actor/state-machine lowering
  └─ OTP-29 Abstract Format adapter
       ├─ strong_validation
       ├─ deterministic BEAM compilation
       ├─ import and chunk inspection
       ├─ manifest/signature attachment
       └─ isolated load smoke test
```

The OTP compiler can run as a tightly scoped build service or subprocess. It
is a code generator, not the main interpreter. Production agent nodes should
load only artifacts created by an approved compiler version and accepted by a
policy verifier.

### 5.2 A session is a supervision subtree

```text
session supervisor
├── coordinator / typed state machine
├── bounded inbox and admission controller
├── effect dispatcher
│   └── short-lived effect workers or ports
├── policy and budget monitor
├── trace / provenance emitter
└── checkpoint and durable-state adapter
```

This separation prevents a slow tool, overloaded inbox, trace exporter, or
policy decision from silently becoming the agent's whole failure domain. The
source language can describe one logical agent while the compiler derives the
tree.

### 5.3 Versioned runtime messages

Generated code should communicate through a narrow ABI. A conceptual envelope
is:

```text
Envelope = {
  version: UInt,
  kind: ClosedTag,
  correlation: Binary,
  deadline: MonotonicDeadline,
  reply_to: RuntimeAddress,
  capability: CapabilityRef,
  payload: ValidatedValue
}
```

`ClosedTag` means a compiler-known bounded enumeration. User, prompt, model,
tool, tenant, and artifact names remain binaries or integers; they are never
blindly interned as atoms. Decoders reject unknown versions and oversized
payloads before they enter the coordinator mailbox.

### 5.4 Control dynamic module creation

BEAM module names are atoms, and atoms are not garbage collected. A design that
creates a fresh module name for every prompt or run will eventually exhaust the
node even after code is purged.

Use content-addressed artifacts only for approved, reusable programs, subject
to a bounded registry and tenant quota. Reuse a compiled module across runs.
Perform high-churn or untrusted compilation on disposable build nodes, and
recycle nodes according to an explicit policy. Never derive an atom directly
from untrusted text.

### 5.5 Durable state remains explicit

The coordinator heap is a live cache, not the system of record. At defined
semantic boundaries the runtime should record:

- program and state-schema versions;
- an event or transition identifier;
- accepted observations;
- pending effect intents and idempotency keys;
- completed effect results;
- remaining budgets and deadlines;
- enough state to replay or resume under declared semantics.

This can be implemented with a database, durable log, or external workflow
service. The language should define the contract without hard-coding one
storage product.

## 6. Categorical laws on BEAM

### 6.1 Laws belong to the semantic layer

For pure arrows, the familiar equations are direct:

```text
id >>> f                 ≈ f
f >>> id                 ≈ f
(f >>> g) >>> h          ≈ f >>> (g >>> h)
map(id)                   ≈ id
map(f >>> g)              ≈ map(f) >>> map(g)
decode(encode(x))         ≈ x
```

These laws can justify IR rewrites and catch compiler defects. The symbol `≈`
must be defined per semantic domain. For total pure values it may be structural
equality. If floats, resource limits, divergence, failure details, or external
effects are visible, the equivalence needs more care.

An initial executable law registry should make the generator and equivalence
part of each law rather than hiding them in the test framework:

| Structure | Representative property | Generated domain | Required observation |
| --- | --- | --- | --- |
| category | left/right identity and associativity | composable well-typed pure arrows | structural output equality over generated inputs |
| product | `fst(pair(a,b)) ≈ a`, `snd(pair(a,b)) ≈ b` | values satisfying both schemas | value equality |
| coproduct | case after left/right injection selects the matching branch | tagged values and branch functions | result equality plus no observation from the unselected branch |
| functor | identity and composition preservation | containers, values, and total functions | shape and value equality |
| serialization | `decode(encode(x)) ≈ x` | every runtime-representable value | canonical language-value equality |
| task composition | Kleisli identity and associativity | typed tasks and deterministic handlers | normalized result and effect trace |
| monoidal composition | associator/unit laws; symmetry only when valid | effect-disjoint tasks | causal trace equivalence |
| state machine | implementation refines the transition model | generated commands, replies, failures, and timeouts | model state, public outputs, and pending-effect set |
| coalgebraic agent | equivalent states remain behaviorally equivalent | bounded observations and transition depth | trace equivalence or bisimulation approximation |

Function extensionality cannot be established by comparing closures. Tests
must generate observations from a finite or bounded input domain. Product,
coproduct, and functor laws also need generators that preserve the source
language's refinements instead of manufacturing invalid values and then
mistaking rejection for a counterexample.

### 6.2 Effectful laws need controlled interpreters

An agent task is closer to a Kleisli arrow or an algebraic-effect program than
a function in `Set`. Associativity can be tested under a deterministic mock
handler that records effect requests and supplies generated responses. The
property compares normalized results and effect traces.

Parallel composition should not claim commutativity merely because two syntax
trees can be swapped. It is valid only when their effects commute, use disjoint
capabilities and state, or are interpreted in a model that deliberately
quotients away ordering.

### 6.3 Concurrent equality is observational

The [formalisation of concurrent Core Erlang](../30-sources/bereczky-et-al-2024-formalisation-concurrent-core-erlang.md)
uses labelled transitions and bisimulation, which is the right direction for
BEAM law testing. Scheduler choices, fresh process identifiers, references,
timestamps, and trace-event arrival order can differ while a program remains
semantically equivalent.

A test observer should:

- replace fresh identifiers with canonical names;
- compare only declared public messages and final outcomes;
- preserve causally significant order;
- permit reordering only for proven-independent events;
- make time virtual where a law is not specifically about real time;
- bound execution and classify timeout, divergence, and deadlock separately;
- include resource and policy observations when they are language-visible.

### 6.4 Use PropEr without making Erlang the language

PropEr properties are normally authored as Erlang modules, but they can sit in
the conformance harness rather than the production language. The native
compiler can emit small test adapters with a stable ABI:

```text
generate(seed, size) -> encoded input
run(artifact, input, handler, schedule_seed) -> encoded observation
shrink(input) -> candidate inputs
compare(law, left_observation, right_observation) -> pass | counterexample
```

The adapter can be generated through Abstract Format or maintained as a small
trusted BEAM test component. An equivalent host-language property engine can
test parser and IR passes before BEAM emission. Framework-neutral encoded
generators and observations allow PropEr, commercial QuickCheck, and future
tools to share a conformance corpus.

### 6.5 A validation ladder

Use several kinds of evidence instead of asking one property library to act as
a proof system:

1. **Static validation:** types, effects, capabilities, exhaustiveness, linear
   resources, and closed runtime imports.
2. **IR law tests:** generators and shrinkers over well-typed terms.
3. **Compiler validation:** `strong_validation`, deterministic builds, chunk
   inspection, and isolated loading.
4. **Differential tests:** IR evaluator versus compiled BEAM; optionally Core
   and Abstract Format backends.
5. **Runtime model tests:** generated command histories for coordinators,
   brokers, restarts, timeouts, and deduplication.
6. **Schedule perturbation:** repeated runs with seeded runtime choices and
   timing perturbations, followed by observational comparison.
7. **Fault injection:** process, port, node, and storage failures at every
   effect protocol boundary.
8. **Proof:** machine-check the small core and selected transformations where
   the value justifies it.

Property testing can falsify universal claims efficiently; it cannot certify
them from a finite sample.

## 7. Security and capability design

The language should make an effect impossible to request without a typed
capability. That is useful but insufficient if generated BEAM code can call
arbitrary exports. Defense requires aligned layers:

1. the source type/effect checker permits only declared operations;
2. lowering routes operations through a fixed runtime ABI;
3. artifact inspection rejects unauthorized imports and suspicious chunks;
4. artifacts are signed or content-addressed by an approved compiler;
5. the loader accepts only authorized artifacts;
6. the effect broker checks capability, tenant, budget, deadline, and policy;
7. tools and generated foreign code run in OS isolation;
8. audit records connect source, artifact, session, intent, and result.

Avoid exposing `binary_to_term` on untrusted data without safe decoding,
dynamic atom construction, arbitrary module application, unrestricted ports,
or NIF loading. A user-visible capability must be unforgeable and revocable;
an ordinary tuple containing a capability name is not enough.

The proof of concept deliberately stops at a local grant design. A BEAM task
receives only an opaque `CapabilityRef`; the trusted broker retains the typed
resource scope, budget, deadline, revocation state, ownership rules, and
durable-effect checks. References are valid only inside the issuing runtime,
are never derived from untrusted text, and convey no portable delegation
semantics.

## 8. Versioning and operational discipline

Pin the native compiler to an OTP backend version. Record both versions in the
artifact and runtime trace. For each supported OTP release:

- regenerate or compile through that release's Abstract Format adapter;
- run validation and the full conformance suite;
- inspect imports and custom chunks;
- benchmark representative workloads;
- test loading, purge, and migration behavior;
- run mixed-version protocol tests when nodes can differ;
- reject artifacts whose backend contract is outside policy.

Do not assume that an old BEAM binary is the optimal or supported representation
for every newer node. Reproducible source-to-artifact builds are more valuable
than treating `.beam` as a permanent portable object format.

Hot upgrades need language-level state migrations. A safe default is to pin a
running session to its program version, drain it, and start new sessions on the
new version. Live adoption should require an explicit migration function and a
testable compatibility declaration.

## 9. Prototype and evaluation plan

### Phase 0 — backend contract spike

- Select OTP 29.x and encode a minimal Abstract Format subset.
- Compile pure functions, algebraic data encodings, exceptions, receives,
  process creation, monitors, and timeouts.
- Run `strong_validation`, deterministic compilation, import inspection, and
  isolated loading.
- Record source mappings and a capability manifest in custom chunks.
- Confirm that no source program uses an existing BEAM-language evaluator.

Exit criterion: the compiler can produce inspectable, reproducible, safe-load
artifacts through a documented interface.

### Phase 1 — native frontend and semantic core

- Implement the lexer and parser outside an existing BEAM language.
- Define products, coproducts, pure arrows, tasks, effects, capabilities, and
  coalgebraic state machines.
- Write a deterministic IR evaluator as an oracle.
- Lower the same well-typed IR to Abstract Format.

Exit criterion: evaluator and BEAM observations agree for generated pure and
deterministic-effect programs.

### Phase 2 — agent runtime kernel

- Implement the session supervision topology and versioned message ABI.
- Add bounded admission, deadlines, cancellation, stale-reply handling, policy
  checks, and trace emission.
- Put model and tool calls behind ports or sidecars.
- Add durable intent/result recording and checkpoint recovery.

Exit criterion: injected worker and node failures neither lose acknowledged
state nor duplicate an idempotent external effect.

### Phase 3 — categorical law harness

- Define equality and observation explicitly for every type constructor and
  task class.
- Generate well-typed IR, handlers, command histories, and effect responses.
- Shrink counterexamples at the IR and workflow levels.
- Run pure laws, effect-handler laws, serialization laws, and state-machine
  properties on the IR evaluator and BEAM backend.

Exit criterion: the suite detects deliberately seeded violations of every law
and produces actionable minimal counterexamples.

### Phase 4 — adversarial and performance evaluation

Measure:

- runnable and waiting sessions per node;
- p50, p95, and p99 control-message latency under CPU and I/O load;
- reductions, heap size, GC time, binary memory, and mailbox age per session;
- behavior under slow consumers, oversized tool results, and late replies;
- recovery time and duplicate-effect rate under process, port, node, and store
  failure;
- artifact build and load time;
- atom, process, port, ETS, memory, and scheduler exhaustion behavior;
- cross-version compiler and runtime conformance;
- throughput against a simpler conventional runtime baseline.

Exit criterion: the BEAM design wins on concurrency and recovery without
unacceptable tail latency, memory amplification, deployment coupling, or
operational complexity.

## 10. Falsification criteria

The project should reconsider BEAM if experiments show that:

- most work is CPU-bound inside the agent runtime rather than external I/O;
- mailbox and message-copying costs dominate representative workflows;
- the Abstract Format adapter requires release-specific work comparable to a
  direct custom VM backend;
- OS-level sandboxing eliminates the operational benefits of in-node process
  isolation;
- durable workflow semantics require a second runtime whose state machine
  becomes the real execution engine;
- categorical observations cannot be defined usefully under the intended
  concurrency and effect model;
- module/atom lifecycle constraints make dynamic program deployment unsafe;
- the team cannot operate pinned OTP releases and conformance matrices
  reliably.

Conversely, success means more than “the demo runs.” It means thousands of
agent state machines can wait, resume, fail locally, recover from recorded
state, respect capabilities and budgets, and preserve the language's declared
observations across compiler and runtime changes.

## 11. Design verdict

BEAM's deepest advantage is not that it has a small instruction set. It is that
ERTS already embodies an unusually mature set of semantics for concurrent,
long-lived, failure-aware processes. Those semantics correspond closely to
the operational shape of agents and to the coalgebraic, effectful layer of the
proposed category-informed language.

The price is that BEAM is a living runtime, not a frozen bytecode standard. The
new language should own a small stable IR and place a versioned adapter between
that IR and OTP's supported Abstract Format. That preserves language identity,
compiler control, and categorical reasoning while allowing OTP to own the
moving code-generation and VM invariants.

The resulting system is not an Erlang interpreter wearing a new syntax. It is
a native agent compiler whose programs execute as BEAM modules, use ERTS as
their process machine, and interact with a small capability-aware runtime ABI.
That is the most credible way to obtain BEAM's advantages without inheriting an
existing BEAM language as the agent language itself.

## Connections

- [Set and category principles for an agent programming language](set-and-category-principles-for-agent-programming-language.md)
  supplies the semantic architecture whose effectful and coalgebraic layers
  this runtime must implement.
- [Task languages for LLM agents](llm-agent-task-languages-deep-dive.md) supplies
  the broader evidence for separating human intent, typed task structure,
  deterministic control, and model judgment.
- [Can BEAM support a native agent language safely?](../40-inquiries/can-beam-support-a-native-agent-language.md)
  turns the recommendation into a falsifiable engineering inquiry.
- [BEAM runtime for agent languages](../10-maps/beam-runtime-for-agent-languages.md)
  provides the short path through the underlying sources.

## Sources

- [Erlang/OTP compiler guidance for language implementors](../30-sources/erlang-otp-2026-language-implementors.md)
- [Core Erlang 1.0.3 language specification](../30-sources/carlsson-et-al-2004-core-erlang-specification.md)
- [A Formalisation of Core Erlang, a Concurrent Actor Language](../30-sources/bereczky-et-al-2024-formalisation-concurrent-core-erlang.md)
- [BEAM instructions, loading, JIT execution, and compatibility](../30-sources/erlang-otp-2026-beam-execution.md)
- [Erlang runtime processes, signals, scheduling, and memory](../30-sources/erlang-otp-2026-process-runtime.md)
- [Erlang/OTP supervision and release handling](../30-sources/erlang-otp-2026-supervision-and-releases.md)
- [Erlang/OTP interoperability and secure coding](../30-sources/erlang-otp-2026-interoperability-and-security.md)
- [Leex and Yecc parser tools](../30-sources/erlang-otp-2026-leex-and-yecc.md)
- [PropEr types and property-based testing](../30-sources/papadakis-sagonas-2011-proper.md)
