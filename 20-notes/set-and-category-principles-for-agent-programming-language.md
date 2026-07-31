---
title: "Set and category principles for an agent programming language: a deep dive"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - agent-programming
  - category-theory
  - programming-languages
  - compositionality
  - formal-semantics
aliases:
  - "Categorical agent language deep dive"
  - "Set-based agent programming language"
---

# Set and category principles for an agent programming language: a deep dive

## Executive conclusion

An agent-specific programming language built on principles from the category
**Set** could offer substantial advantages, but only if “category-based” means
a precise semantic architecture rather than category-theory vocabulary painted
onto an ordinary workflow language.

The useful starting point is simple:

- treat data types as sets of admissible values;
- treat pure transformations as total functions;
- require typed boundaries between every composable component;
- make identity and associative composition language laws;
- use products for paired information and coproducts for explicit alternatives;
- interpret the same abstract task through structure-preserving compiler
  backends.

That foundation would make invalid wiring harder, make task decomposition
reusable, and give the compiler an algebra for refactoring and interpreting
workflows. Yet `Set` alone is not a realistic model of agency. A function in
`Set` is total, deterministic, and free of observable effects. Agent actions
can fail, branch, change state, spend resources, call models, wait for humans,
and alter an external world. The language therefore needs a *layered*
categorical semantics:

1. `Set` or a schema-equivalent category for pure data;
2. a Kleisli or algebraic-effect layer for tool calls and failure;
3. a symmetric monoidal layer for explicit sequential and parallel wiring;
4. coalgebraic state machines for ongoing behavior;
5. polynomial interfaces or related constructions for multi-turn interaction;
6. Markov-category structure where uncertainty is genuinely probabilistic;
7. functorial interpreters for execution, simulation, tracing, policy checking,
   visualization, and migration.

The main prospective advantages are compositionality, typed interfaces,
explicit effects, modular safety enforcement, reusable state and interaction
protocols, principled uncertainty, local verification, smaller repair scopes,
backend portability, and better provenance. Category theory is particularly
valuable because it asks whether each interpretation preserves composition:
does executing, simulating, tracing, pricing, or checking a composite mean the
same thing as composing the corresponding interpretations of its parts?

The evidence must be bounded carefully. Programming-language research strongly
supports categorical accounts of effects and composition. Applied-category
work demonstrates software, data, probability, feedback, and interactive
systems built this way. Existing agent DSLs show benefits from interpreters,
typed workflows, context control, and runtime enforcement. There is not yet
direct evidence that adding categorical laws to an otherwise comparable agent
DSL improves LLM task understanding or end-to-end success. That is an open
empirical question, not a mathematical corollary.

The practical recommendation is therefore:

> Build a familiar agent DSL over a small categorical intermediate
> representation. Keep category theory mostly beneath the surface, begin with
> typed arrows, serial and parallel composition, explicit sums/products, and an
> effect system, and require every more advanced categorical feature to earn
> its place in controlled ablations.

## Scope and interpretation

“Set category principles” is interpreted here as principles derived from the
category **Set**, whose objects are sets and whose morphisms are total
functions, together with categorical extensions used in programming-language
semantics and applied category theory.

This is not a proposal to teach category theory to the LLM or to write prompts
in mathematical notation. It is a proposal for the compiler and runtime to
have a compositional model of:

- which values cross a component boundary;
- which processes can be connected;
- which effects and permissions a process requires;
- how processes run sequentially or in parallel;
- how observations update state;
- how uncertainty propagates;
- how one task representation is interpreted by several backends;
- which equivalences are safe for optimization or refactoring.

An advantage counts as operational only if it improves at least one measurable
property: task success, semantic fidelity, rejected invalid plans, policy
compliance, reusable components, model or tool portability, fault localization,
repair cost, audit quality, execution cost, or authoring effort.

## 1. The useful core of Set

### 1.1 Objects, functions, and composition

In `Set`:

- an object `A` is a set;
- a morphism `f: A -> B` is a total function;
- every `A` has an identity `id_A: A -> A`;
- compatible functions compose: `f: A -> B` and `g: B -> C` yield
  `g ∘ f: A -> C`;
- composition is associative;
- identity is neutral under composition.

For a language, “set” should usually mean a machine-checkable schema rather
than a collection enumerated in memory. `Topic`, `Query`, `VerifiedSourceSet`,
`EvidenceGraph`, and `Report` can all denote sets of values satisfying their
schemas. A pure component such as `normalize_query: Topic -> Query` denotes a
total transformation between two such sets.

The category laws are small but important:

```text
(h after g) after f  ==  h after (g after f)
id after f           ==  f
f after id           ==  f
```

If the language makes these observable laws, a compiler may regroup a pipeline,
remove true no-ops, reuse generic combinators, and compare two workflow
representations without changing their meaning. [Fong and Spivak's applied
category account](../30-sources/fong-spivak-2019-seven-sketches-compositionality.md)
([manuscript](https://arxiv.org/abs/1803.05316)) develops this broader idea of
building systems from composable, interface-bearing parts.

### 1.2 Products, coproducts, and function spaces

`Set` is cartesian closed. Several of its constructions map cleanly to language
features:

| Set construction | Programming form | Agent-language role |
| --- | --- | --- |
| terminal set `1` | unit value | a step with no informative input or output |
| initial set `0` | uninhabited type | an impossible state or unreachable branch |
| product `A × B` | pair or record | both pieces of information are present |
| coproduct `A + B` | tagged union or result | exactly one explicit alternative occurred |
| exponential `B^A` | function type `A -> B` | a policy, callback, evaluator, or strategy |
| diagonal `A -> A × A` | copying | share ordinary immutable data with two consumers |
| map `A -> 1` | discarding | deliberately ignore ordinary data |

This is more than syntax. A verifier result should be a tagged alternative such
as `Pass VerifiedReport + Fail DefectSet`, not an untyped string that downstream
steps must reinterpret. An input needed by two independent analyses should be
paired or copied explicitly. An impossible branch should not be represented by
`null` and wishful thinking.

### 1.3 Why Set is not the category of agent actions

The same conveniences reveal a boundary. Total functions between sets do not
represent:

- nontermination or timeout;
- exceptions and recoverable failure;
- nondeterministic model output;
- probabilistic beliefs;
- reading or changing persistent state;
- network and filesystem I/O;
- resource consumption;
- approval and revocation;
- concurrent interference;
- an evolving conversation with the environment.

[Moggi](../30-sources/moggi-1991-notions-computation-monads.md)
([paper](https://person.dibris.unige.it/moggi-eugenio/ftp/ic91.pdf)) made this
point precise: identifying all programs with total value-to-value functions
erases nontermination, nondeterminism, and side effects. His examples over
`Set` distinguish a value `A` from computations such as partial `A`, finite
nondeterministic choices over `A`, stateful computations, or `A + Error`.

There is a second boundary. Cartesian structure permits every value to be
copied and discarded. That is correct for a topic string and wrong for a
one-use approval, a secret, a budget, a lock, or an exclusive capability.
Resources should therefore live in a linear, affine, or otherwise
resource-sensitive layer where copying and deletion are not automatic.

The right thesis is not “agents are functions in `Set`.” It is:

> Pure agent data can begin in `Set`; agent computations and resources require
> categories whose morphisms retain effects, state, interaction, and usage
> constraints.

## 2. A categorical semantic core for an agent language

The language can expose a small surface while compiling to a richer typed IR.
At minimum, the IR should distinguish pure functions from agent tasks:

```text
pure   A -> B
task   A ~{effects, capabilities}-> B
```

A task arrow should carry:

- input and output schemas;
- required capabilities;
- possible effects;
- failure and cancellation channels;
- preconditions and postconditions;
- state and context projections;
- cost or budget annotations;
- provenance requirements;
- completion evidence.

The category of tasks then needs an identity task and associative sequential
composition. A symmetric monoidal product can represent independent parallel
composition, but only when effect analysis shows that the two tasks do not
conflict. Products and coproducts organize data and branches. Handlers interpret
effects. State machines govern resumable behavior.

[Hughes's arrows](../30-sources/hughes-2000-generalising-monads-arrows.md)
([publisher page](https://www.sciencedirect.com/science/article/pii/S0167642399000234))
are a useful precedent for a typed composition interface wider than monads. The
surface language does not need Haskell's arrow notation; it needs the same
discipline that heterogeneous computations implement common, law-governed
composition operations.

### Semantic layers

| Concern | Candidate structure | What the language gains |
| --- | --- | --- |
| pure values and transforms | `Set`, products, coproducts, exponentials | schemas, typed data flow, explicit alternatives |
| effectful actions | monads/Kleisli arrows or algebraic effects | typed failure, state, I/O, nondeterminism, model calls |
| independent composition | symmetric monoidal category | explicit serial versus parallel wiring |
| bounded resources | affine or linear structure | capabilities that cannot be silently copied |
| ongoing state | coalgebras and state machines | resumability, observation, bisimulation, coinduction |
| interactive interfaces | polynomial functors/dependent lenses | response-dependent legal inputs and multi-turn protocols |
| focused update | optics | lawful context views and local updates |
| probabilistic information | Markov categories | typed kernels, conditional independence, filtering |
| multi-agent strategy | open games or related open systems | compositional boundaries with forward and backward context |
| interpreters and migration | functors and natural transformations | execution, simulation, tracing, visualization, backend change |

These structures should not be forced into one enormous category. A better
design uses a small common task model with explicit translations among
specialized layers.

## 3. The principal advantages

### 3.1 Composition becomes a checked operation

Most workflow systems let users connect named blocks. A categorical language
can make composition itself part of the semantics:

- outputs must match the next input;
- identities and grouping have declared laws;
- sequential and parallel composition are distinct;
- a composite exposes a derived boundary;
- local contracts can be lifted to the composite when the rules permit it.

This provides *local reasoning*. If `fetch` always returns a
`FetchedDocument + FetchError` and `extract` accepts only `FetchedDocument`, the
compiler can require the error branch to be handled before composition. The
runtime no longer discovers this mismatch after the LLM has already acted.

The benefit should grow with the number of reusable subworkflows. A one-step
prompt gains little. A library of research, coding, approval, evidence, and
publishing components gains a shared algebra for assembling larger tasks.

### 3.2 Interfaces become semantic boundaries rather than prompt conventions

Typed objects identify what a component is allowed to know and return. This can
reduce several common agent failures:

- passing prose where a file handle is required;
- confusing a goal with a proposed plan;
- treating an observation as a verified fact;
- forgetting an error or refusal branch;
- giving a subagent the full conversation instead of a scoped view;
- interpreting “stopped” as “succeeded.”

This extends the distinctions proposed in the earlier
[task-language deep dive](llm-agent-task-languages-deep-dive.md): goal versus
plan, fact versus assumption, capability versus permission, observation versus
inference, and stop versus success can be different types rather than
documentation.

The categorical contribution is not just having a type checker. It is defining
the common constructors by which these types and their processes compose, so
that libraries, interpreters, and law-based tests share the same model.

### 3.3 Syntax and execution can be separated by functorial interpreters

A functor maps objects and morphisms from one category into another while
preserving identities and composition. For an agent IR, this suggests several
interpreters over the same workflow:

- **execute** with real tools;
- **simulate** with deterministic test doubles;
- **trace** into a provenance graph;
- **visualize** as a wiring diagram;
- **estimate** cost and required capabilities;
- **monitor** events against safety policies;
- **compile** specialized fragments to PDDL, SQL, SMT, shell, or Python;
- **explain** the workflow as human-readable documentation.

The design test is strong: interpreting a composite should agree with composing
the interpretations of its parts, or the implementation should explicitly say
where it is only lax, approximate, or effect-dependent.

[Functorial Data Migration](../30-sources/spivak-2012-functorial-data-migration.md)
([paper](https://arxiv.org/abs/1009.1166)) demonstrates the pattern for schemas:
database instances are set-valued functors, and schema mappings induce
structured migrations. For agents, analogous mappings could translate tool
versions, task-state schemas, evidence records, or model-specific request
formats without scattering field conversions across prompts.

This does not make migrations semantically correct automatically. It makes
their structure explicit and testable.

### 3.4 Effects and permissions can be separated from business logic

An agent language needs more than `Task<Input, Output>`. It must express what
may happen while producing the output. [Moggi's
monads](../30-sources/moggi-1991-notions-computation-monads.md) give one uniform
semantic family. [Plotkin and Pretnar's algebraic effects and
handlers](../30-sources/plotkin-pretnar-2013-handling-algebraic-effects.md)
([paper](https://lmcs.episciences.org/705)) give a particularly useful runtime
architecture:

- a program requests an operation;
- an external handler decides how to interpret it;
- the same request can be executed, denied, logged, simulated, retried, or
  redirected;
- operation laws support reasoning independent of one handler.

Agent operations such as `search`, `write`, `send`, `spend`, `ask_human`, and
`delegate` can therefore be named effects rather than unrestricted functions.
A capability layer decides whether the operation is available to this task.
Handlers can add sandboxing, approval, rollback, and provenance.

For the first proof of concept, that layer remains local to the BEAM runtime.
If `I` is the set of well-typed invocations, a broker-held grant `c` denotes
`⟦c⟧ ⊆ I`; restriction is subset inclusion, and separately issued grants
combine by union only when the broker's policy permits it. The external handler
still decides resource ownership, budgets, deadlines, revocation, and stateful
constraints. This keeps the semantic law independent of any portable
certificate representation.

This architecture connects to current agent evidence. [AgentSpec](../30-sources/wang-et-al-2026-agentspec.md)
([paper](https://arxiv.org/abs/2503.18666)) reports that event-intercepting
runtime rules can prevent classes of unsafe actions more reliably than prompt
advice. Category theory does not supply AgentSpec's predicates, but effects and
handlers provide a principled place to invoke such enforcement.

### 3.5 State and resumability gain a behavioral semantics

A long-running agent is better modeled as an observed state transition system
than as a function that magically returns a final artifact. [Rutten's universal
coalgebra](../30-sources/rutten-2000-universal-coalgebra.md)
([CWI paper](https://ir.cwi.nl/pub/48/)) provides concepts for:

- state and observation;
- transition behavior;
- potentially infinite processes;
- behavioral equivalence through bisimulation;
- coinductive reasoning.

For an agent runtime, this can support:

- checkpoint and resume semantics;
- event-sourced state transitions;
- explicit waiting, cancellation, retry, and escalation states;
- protocol conformance across an ongoing run;
- replacement of one component by another with equivalent observable behavior;
- regression tests that compare traces modulo irrelevant internal details.

The last benefit is subtle. Two LLM calls will rarely produce identical text.
Bisimulation suggests comparing the observations that matter—tool effects,
accepted artifacts, policy events, and completion evidence—rather than raw
hidden state or exact prose.

### 3.6 Tool and subagent protocols can depend on previous responses

A flat signature `Request -> Response` hides multi-turn protocol structure. A
login flow, database transaction, clarification dialogue, browser session, or
delegated subtask offers different legal next actions after each response.

[Niu and Spivak's polynomial-functor account of
interaction](../30-sources/niu-spivak-2025-polynomial-functors-interaction.md)
([manuscript](https://arxiv.org/abs/2312.00990)) starts concretely from `Set`.
A polynomial has positions and directions; morphisms send positions forward
and directions backward. The framework develops these into interaction
protocols, dependent lenses, state systems, and wiring patterns.

An agent-language adaptation could describe:

- the outputs a tool or subagent may expose;
- the inputs legal after each output;
- wrappers that adapt one interface to another;
- state-dependent capabilities;
- legal protocol composition;
- generators for clients, mocks, and conversation tests.

This is more expressive than OpenAPI-style isolated endpoints and safer than
asking the LLM to infer a protocol from tool descriptions on every run.

### 3.7 Feedback and local repair can become typed channels

Agent systems send information in both directions. A forward pass produces an
action or artifact; backward information may contain an error, critique,
reward, failed test, policy decision, or clarification.

[Categorical cybernetics](../30-sources/capucci-et-al-2022-categorical-cybernetics.md)
([paper](https://arxiv.org/abs/2105.06332)) models processes that interact
bidirectionally with an environment and a controller. [Categories of
optics](../30-sources/riley-2018-categories-of-optics.md)
([paper](https://arxiv.org/abs/1809.00738)) gives a common construction and
lawfulness conditions for bidirectional accessors.

Used carefully, these ideas could support:

- project a minimal context view into a subtask;
- return a typed patch, result, or defect set;
- apply the update only through a lawful boundary;
- send verifier feedback to the smallest responsible component;
- separate environmental observation from controller evaluation;
- compose feedback paths along with forward execution paths.

This could reduce repair blast radius and context duplication. It is not a
license to call every feedback loop a lens: human revisions and external state
changes often lack the round-trip laws of a lawful optic.

### 3.8 Uncertainty can be distinguished from failure and nondeterminism

Agent code often compresses several concepts into a float called `confidence`.
A categorical design can at least require the author to distinguish:

- a deterministic value;
- an explicit set of alternatives;
- a partial computation;
- a probability distribution;
- an observation conditioned on hidden state;
- an unsupported subjective score.

[Fritz and colleagues](../30-sources/fritz-et-al-2025-hidden-markov-bayes-filter-categorical-probability.md)
([paper](https://arxiv.org/abs/2401.14669)) formulate hidden Markov models and
Bayesian filtering in Markov categories. Their abstract algorithms specialize
to discrete, Gaussian, measure-theoretic, and possibilistic settings while
string diagrams expose information flow.

For agents with sensor uncertainty or defensible probabilistic models, this
offers a compositional account of belief updates. For ordinary LLM token
generation, it should be used more cautiously: a model's verbal confidence is
not thereby calibrated, and a category cannot create a missing probability
model.

### 3.9 Multi-agent composition can include incentives and context

Putting two agents in parallel is not enough to make a multi-agent system
modular. Their outputs may conflict, local goals may undermine the global goal,
and one agent's best action may depend on another's possible responses.

[Compositional game theory](../30-sources/ghani-et-al-2018-compositional-game-theory.md)
([paper](https://arxiv.org/abs/1603.04641)) models open games as morphisms in a
symmetric monoidal category. Sequential and simultaneous composition are
distinct, and an open boundary carries enough context to reason about
strategies and best responses.

An agent DSL could borrow the boundary discipline without assuming every
subagent is a rational utility maximizer:

- declare what information flows forward and backward;
- separate sequential delegation from parallel consultation;
- type message protocols;
- retain each participant's authority and goal scope;
- evaluate the composite, not only each local result;
- make conflicts and aggregation policies explicit.

The key warning is itself an advantage: categorical composition does not imply
that locally good components yield a globally good outcome. It gives a place to
state and test the conditions under which composition preserves a property.

### 3.10 Laws enable refactoring and property-based tests

Once a language declares identity, associativity, functor, monoidal, handler,
or optic laws, implementations can be tested against those laws. Examples
include:

- adding an identity step does not alter relevant behavior;
- regrouping sequential composition does not alter the result;
- tracing a composite equals the appropriate composition of component traces;
- a mock and live interpreter agree on pure fragments;
- a schema migration preserves declared relationships;
- a context projection and update obey the chosen round-trip rules;
- independent parallel tasks commute only when their effects are declared
  commutative.

This gives property-based testing and compiler optimization a semantic target.
It also prevents the language manual from being the only definition of what
composition is supposed to mean.

The caveat is non-negotiable: a law is useful only if observability and equality
are defined realistically. Nondeterministic LLM text will not satisfy ordinary
equality. Laws may need to concern types, traces, accepted outcomes, effect
sets, distributions, or other observational equivalence classes.

### 3.11 One IR can support text, diagrams, simulation, and execution

[Catlab and SemanticModels](../30-sources/halter-et-al-2020-compositional-scientific-computing.md)
([paper](https://arxiv.org/abs/2005.04831)) are an existence demonstration for
computational applied category theory. They represent categorical expressions
as formulas, ASTs, wiring diagrams, and conventional program syntax, then
compose models and connect them to numerical solvers.

An agent language could likewise provide:

- concise text for version control;
- a visual graph for workflow inspection;
- a canonical typed AST for tools and compilers;
- deterministic simulation for tests;
- live execution with effect handlers;
- a provenance view generated from the same structure.

This improves accessibility without making the diagram or the surface syntax
the semantics. It also suggests embedding the categorical IR in a mature host
language first, rather than building a parser, package manager, debugger, and
runtime simultaneously.

### 3.12 The LLM can be given a smaller, more stable responsibility

The category-theoretic advantage for an LLM is indirect. The model does not
become more intelligent because its workflow has morphisms. Instead, the
system can move deterministic responsibilities out of the prompt:

- the type checker rejects incompatible steps;
- the effect checker calculates required permissions;
- the runtime owns declared control flow and budgets;
- protocol types constrain legal next actions;
- handlers enforce approval and sandboxing;
- the verifier produces localized defects;
- functorial interpreters generate minimal per-step views.

The LLM can focus on semantic judgments that genuinely require language and
world knowledge: interpreting intent, generating hypotheses, extracting
evidence, or drafting prose.

This mechanism is consistent with adjacent evidence. [AgentSPEX](../30-sources/wang-et-al-2026-agentspex.md)
([paper](https://arxiv.org/abs/2604.13346)) reports better results for an
interpreter-enforced workflow than for placing the same workflow in a ReAct
prompt. [DSPy](../30-sources/khattab-et-al-2024-dspy.md)
([paper](https://openreview.net/forum?id=sY5N0zY5Od)) separates declarative
language-model modules from compiled prompt parameters. These works support
structured execution and interpretation, not category theory specifically.

## 4. A concrete language sketch

The surface language should use domain terms. Category theory should determine
the IR and laws beneath it.

```text
type Topic
type SourceSet
type VerifiedSources
type EvidenceGraph
type Draft
type DefectSet
type VerifiedReport
type Artifact

effect Network
effect Model(model_id)
effect WorkspaceWrite(path)
effect Trace

capability WebRead
capability WriteResearch

task discover:
  Topic ->{Network, Model, Trace | WebRead} SourceSet

task validate:
  SourceSet ->{Network, Trace | WebRead}
  Result[RejectedSources, VerifiedSources]

task extract:
  VerifiedSources ->{Model, Trace} EvidenceGraph

task draft:
  Topic * EvidenceGraph ->{Model, Trace} Draft

task verify:
  Draft * EvidenceGraph ->{Trace}
  Result[DefectSet, VerifiedReport]

task publish:
  VerifiedReport ->{WorkspaceWrite, Trace | WriteResearch} Artifact

workflow research(topic: Topic): Artifact =
  let evidence =
    topic
    >>> discover
    >>> handle_error(recover_sources)
    >>> validate
    >>> require_ok
    >>> extract

  pair(topic, evidence)
  >>> draft
  >>> pair_with(evidence)
  >>> verify
  >>> repair_until(max = 2)
  >>> require_ok
  >>> publish
```

The design sketch has several categorical readings:

- named types denote objects;
- pure functions and task steps denote different classes of morphisms;
- `>>>` is typed sequential composition;
- `*` is a product of ordinary data;
- `Result[A, B]` is a coproduct, so both branches are explicit;
- the effect row determines the task category or effect interpretation;
- capabilities are requirements, not copyable ordinary data;
- `handle_error` and `repair_until` are runtime interpretations, not vague
  suggestions to the LLM;
- a parallel combinator would use monoidal composition and require a
  noninterference check;
- execution, simulation, trace generation, and visualization consume the same
  IR.

Notice what is absent: the author does not write “Kleisli,” “coalgebra,” or
“natural transformation.” Those terms guide the language designer and support
formalization; they do not need to burden routine programs.

## 5. What could be verified

### Static checks

A compiler could decide or conservatively approximate:

- input/output compatibility;
- complete handling of tagged alternatives;
- undeclared effects;
- missing capabilities;
- illegal copying or discarding of resource tokens;
- use of a tool outside its protocol state;
- incompatible parallel effects;
- unresolved names and schema versions;
- unreachable branches and some impossible states;
- presence of a verifier and completion type;
- whether each interpreter covers every primitive operation.

### Runtime checks

Handlers and monitors could enforce:

- sandbox and path scope;
- network and communication policies;
- cost, time, and retry budgets;
- preconditions and postconditions around effects;
- approval gates;
- provenance event creation;
- state-machine transitions;
- cancellation and compensation policies;
- mechanically testable completion criteria.

### What remains semantic

Neither sets nor categories prove:

- that the natural-language request was translated faithfully;
- that a research source is true;
- that an LLM-generated claim follows from its evidence;
- that a type or schema captures every domain requirement;
- that a subjective report is satisfactory;
- that a backend implementation obeys its declared semantics;
- that two agents share the intended meaning of a message.

The language can expose these obligations, attach evidence, and route ambiguity
to a human. It cannot eliminate the symbol-grounding and specification
problems.

## 6. Comparison with plausible alternatives

| Approach | Strength | Limitation relative to categorical IR |
| --- | --- | --- |
| natural-language prompt | expressive and immediately usable | soft control flow, untyped effects, difficult reuse and enforcement |
| JSON/YAML workflow | inspectable structure and easy parsing | composition laws and multiple interpretations are usually ad hoc |
| conventional typed DSL | static interfaces, enums, effects if designed well | may already deliver most benefits; categorical advantage must be demonstrated |
| typed host-language library | mature compiler, tooling, packaging, tests | surface may expose host complexity and permit escape around DSL rules |
| theorem-prover language | strongest machine-checked properties | high authoring cost and difficult modeling of open-world semantics |
| categorical agent DSL | unified algebra of composition and interpretations | abstraction cost, unfamiliarity, and limited direct agent evidence |

The most serious comparator is a well-designed conventional typed DSL. Products,
sum types, effects, state machines, and interpreters do not require users to
know category theory. A categorical implementation earns its complexity only
if it supplies useful laws, generic combinators, compositional analyses,
backend coherence, or cross-domain reuse that the conventional design lacks.

## 7. Risks and failure modes

### Categorical theater

Renaming functions “morphisms” and pipelines “categories” produces no benefit.
Each categorical structure needs explicit objects, morphisms, composition,
laws, and at least one operation or analysis enabled by those laws.

### The total-function fiction

Modeling an external tool as `A -> B` hides failure and effects. Modeling an
LLM as deterministic because an API returns one response makes refactoring laws
unsound. The language must retain the relevant effect or observational
equivalence.

### An overgrown effect stack

A single monad containing error, state, I/O, nondeterminism, probability,
logging, authorization, and concurrency can become difficult to infer,
compose, and explain. Algebraic effects or a deliberately small effect row may
be more usable, but their interaction laws still require design.

### Unsound parallelism

A monoidal `parallel` operator is not proof of independence. Two tasks may
write the same file, spend from the same budget, use a rate-limited API, or
observe each other's state. Effect commutation must be declared and checked.

### Invalid resource copying

Cartesian copying is convenient for data and dangerous for permissions,
secrets, and one-use resources. Treating all objects as `Set` values could
silently defeat the capability system.

### Formalizing the wrong intent

A beautifully typed program can encode the wrong task. Round-trip explanations,
examples, clarification, and human confirmation remain necessary at the
natural-language boundary.

### Surface-language burden

LLMs have extensive exposure to Python, JSON, YAML, and common type syntax;
they have less reliable exposure to a novel categorical DSL. A familiar
surface and grammar-constrained compiler target are safer than novel notation.

### Global properties that do not compose automatically

Deadlock freedom, privacy, fairness, global optimality, and multi-agent
incentive compatibility require additional conditions. Category theory helps
state composition interfaces; it does not make every property compositional.

### Lawful specification, unfaithful backend

A functorial interpreter is an implementation obligation. A buggy or malicious
backend can claim to preserve structure while violating effects or policies.
Runtime isolation, tests, and trusted computing boundaries remain necessary.

## 8. Minimum viable categorical agent language

The first prototype should be intentionally modest.

### Required core

1. A canonical typed AST with stable IDs.
2. Objects represented by JSON Schema, algebraic data types, or equivalent
   validators.
3. Pure functions distinguished from effectful task arrows.
4. Identity and sequential composition with executable law tests.
5. Products and tagged coproducts for data and branch structure.
6. Explicit effect and capability rows.
7. A symmetric parallel combinator gated by noninterference rules.
8. An event log carrying typed provenance.
9. At least three interpreters: live execution, deterministic simulation, and
   trace/visualization.
10. Completion values that contain verifier evidence rather than a boolean
    `done` flag.

### Add only after demonstrated need

- coalgebraic protocol types for resumable sessions;
- polynomial interfaces for response-dependent tool protocols;
- optics for lawful context projection and repair;
- Markov-category semantics for calibrated probabilistic domains;
- open-game semantics for strategic multi-agent systems;
- natural transformations for verified backend replacement;
- proof-assistant export for high-assurance fragments.

### Implementation path

Build the IR and interpreters as a library in a mature typed language first.
Use familiar YAML, JSON, or a small textual syntax as the source form. Generate
a visual wiring diagram from the IR rather than making diagrams the only source
of truth. Once composition and effect semantics stabilize, a dedicated parser
can target the same IR.

This mirrors the pragmatic lesson of [Catlab](../30-sources/halter-et-al-2020-compositional-scientific-computing.md):
categorical models can be operationalized within an existing language and
represented through several syntaxes.

## 9. Research program

The categorical hypothesis must be isolated from the more general benefits of
structure, types, and runtime enforcement.

### 9.1 Conditions

Implement semantically matched versions of each benchmark workflow:

1. natural-language prompt only;
2. structured Markdown prompt;
3. JSON/YAML workflow with no enforced types;
4. conventional typed agent DSL;
5. the same typed DSL with categorical IR and law-driven interpreters;
6. categorical IR plus runtime effect and policy enforcement.

Condition 4 versus 5 is essential. If they perform the same, category theory
may be a useful design explanation but not an operational feature. Condition 5
versus 6 isolates runtime enforcement from representation.

### 9.2 Task suites

Use tasks that stress different claimed advantages:

- research synthesis with citation provenance;
- code changes with tests and filesystem effects;
- web workflows with stateful sessions and recoverable failure;
- tool-schema migration across API versions;
- long-running tasks with checkpoint and resume;
- parallel tasks with intentional effect conflicts;
- multi-agent tasks with local/global objective tension;
- partially observable tasks with calibrated probabilistic state;
- human clarification and approval loops.

### 9.3 Perturbations

Do not evaluate only happy paths. Vary:

- base model and model version;
- tool ordering and naming;
- schema versions;
- unavailable or faulty tools;
- injected timeouts and malformed responses;
- context-window pressure;
- revoked permissions;
- subworkflow replacement;
- serial versus parallel execution;
- ambiguous and conflicting user constraints.

### 9.4 Metrics

Measure:

- end-to-end task success;
- faithful translation of user intent;
- compile-time rejection of seeded defects;
- runtime policy violations;
- unhandled failure branches;
- repair localization and number of re-executed steps;
- component reuse without modification;
- backend migration effort;
- trace completeness and causal attribution;
- tokens, latency, model calls, and tool cost;
- authoring time and learning burden;
- human ability to predict the workflow's behavior;
- law-test failures across interpreters.

### 9.5 Falsification criteria

The categorical design should be rejected or reduced if:

- a conventional typed DSL matches its reliability and reuse at lower cost;
- category-specific laws do not enable useful checks or transformations;
- the LLM produces categorical IR less reliably than ordinary typed workflows;
- interpreter coherence cannot be tested meaningfully under model
  nondeterminism;
- authors routinely escape into unrestricted code;
- protocol and effect annotations cost more than the failures they prevent;
- advanced structures appear only in documentation and not in compiler or
  runtime behavior;
- end-to-end success does not improve after controlling for runtime
  enforcement.

## 10. Evidence assessment

| Claim | Evidence status |
| --- | --- |
| categories provide laws for identity and composition | mathematically established |
| monads and algebraic effects model broad classes of computation | established programming-language semantics |
| coalgebras model stateful and ongoing systems | established systems semantics |
| categorical probability can unify filtering across probabilistic models | demonstrated in peer-reviewed theory |
| categorical schemas support structured data migration | demonstrated in theory and implementations |
| categorical software can represent, compose, and execute structured models | implemented proof of feasibility |
| interpreted agent workflows and runtime monitors can improve reliability | supported by adjacent agent-language evaluations |
| a categorical agent DSL improves LLM understanding | not established |
| a categorical IR outperforms a conventional typed IR | not established |
| advanced structures improve usability for agent authors | not established and plausibly negative if exposed directly |

The responsible conclusion is conditional. The mathematical structures are
mature enough to guide a prototype. The product claim still requires an
evaluation.

## 11. Design verdict

A Set- and category-informed agent language is most promising when all of the
following are true:

- the platform has many reusable tools and workflows;
- tasks cross multiple effect and permission boundaries;
- execution, simulation, tracing, and policy checking must agree;
- tool and state schemas evolve;
- long-running or multi-agent interactions are common;
- local components need to be replaced without redesigning the whole system;
- the organization values formal audit and repeatable composition.

It is probably excessive when the system is a small prompt wrapper, when task
components are rarely reused, or when the categorical model cannot be connected
to executable checks.

The best architectural slogan is:

> **Set for values; categories for composition; effects for agency; coalgebras
> for persistence; interaction types for protocols; functors for
> interpretation; evidence for completion.**

The central advantage would not be that the LLM “thinks categorically.” It
would be that the surrounding language makes fewer responsibilities depend on
the LLM remembering an informal convention.

## Annotated research trail

### Composition and programming-language semantics

- [Seven Sketches in Compositionality](../30-sources/fong-spivak-2019-seven-sketches-compositionality.md)
  — the general applied-category case for interface-based composition.
- [Notions of Computation and Monads](../30-sources/moggi-1991-notions-computation-monads.md)
  — why real computations cannot be collapsed into total functions in `Set`.
- [Handling Algebraic Effects](../30-sources/plotkin-pretnar-2013-handling-algebraic-effects.md)
  — operations and modular runtime handlers.
- [Generalising Monads to Arrows](../30-sources/hughes-2000-generalising-monads-arrows.md)
  — a broader typed interface for composable computations.

### State, interaction, feedback, and uncertainty

- [Universal Coalgebra](../30-sources/rutten-2000-universal-coalgebra.md)
  — state systems, observation, bisimulation, and coinduction.
- [Polynomial Functors](../30-sources/niu-spivak-2025-polynomial-functors-interaction.md)
  — a Set-based theory of interaction protocols and dynamical systems.
- [Categorical Cybernetics](../30-sources/capucci-et-al-2022-categorical-cybernetics.md)
  — compositional environment and controller feedback.
- [Categories of Optics](../30-sources/riley-2018-categories-of-optics.md)
  — lawful bidirectional views and updates.
- [Categorical Hidden Markov Models](../30-sources/fritz-et-al-2025-hidden-markov-bayes-filter-categorical-probability.md)
  — compositional probabilistic information flow and filtering.

### Data, tooling, and multi-agent structure

- [Functorial Data Migration](../30-sources/spivak-2012-functorial-data-migration.md)
  — schemas, set-valued functors, and structured migrations.
- [Compositional Game Theory](../30-sources/ghani-et-al-2018-compositional-game-theory.md)
  — sequential and simultaneous composition with strategic context.
- [Catlab and SemanticModels](../30-sources/halter-et-al-2020-compositional-scientific-computing.md)
  — executable categorical tooling with text, AST, and diagrammatic forms.

### Bridge to the existing agent-language research

- [AgentSPEX](../30-sources/wang-et-al-2026-agentspex.md) — interpreter-enforced
  workflows and explicit context management.
- [AgentSpec](../30-sources/wang-et-al-2026-agentspec.md) — event-based runtime
  enforcement.
- [DSPy](../30-sources/khattab-et-al-2024-dspy.md) — declarative modules and
  compiled prompt parameters.
- [Agent Programming with Declarative Goals](../30-sources/de-boer-et-al-2002-agent-programming-with-declarative-goals.md)
  — formal separation of goals from procedures.

## Connections

- [Categorical foundations for agent languages](../10-maps/categorical-foundations-for-agent-languages.md)
  is the compact navigation map for this research cluster.
- [Can categorical semantics materially improve an agent language?](../40-inquiries/can-categorical-semantics-improve-agent-language.md)
  turns the design claim into falsifiable hypotheses.
- [Task languages for LLM agents](llm-agent-task-languages-deep-dive.md) provides
  the broader language and runtime context in which this categorical proposal
  belongs.
- [BEAM as the runtime for a native agent language](beam-runtime-for-native-agent-language.md)
  examines one concrete execution substrate and defines how its backend and
  property-testing layers could preserve these laws.

## Status of the thesis

**Developing.** The semantic rationale is well supported, and multiple adjacent
fields show that the required categorical structures can be formalized and
implemented. The proposed benefits for LLM-agent correctness, portability, and
task success remain to be measured against a strong conventional typed-DSL
baseline.
