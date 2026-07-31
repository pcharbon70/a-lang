---
title: "Task languages for LLM agents: a deep dive"
kind: note
created: 2026-07-30
maturity: developing
tags:
  - llm-agents
  - programming-languages
  - task-specification
  - transformers
aliases:
  - "LLM agent task-language research"
  - "A language for assigning tasks to LLM agents"
---

# Task languages for LLM agents: a deep dive

## Executive conclusion

There is credible evidence that a task language can improve an LLM agent
system, but the most defensible claim is narrower than “the language makes the
model understand.”

A language helps when it moves work out of probabilistic token generation and
into inspectable, executable machinery:

1. It makes the intended goal, relevant state, constraints, available actions,
   and completion test explicit.
2. It gives the LLM a compact intermediate representation instead of requiring
   it to repeatedly reinterpret unrestricted prose.
3. It lets a compiler, planner, type checker, solver, or reference monitor
   enforce syntax, control flow, permissions, and invariants.
4. It supplies precise external diagnostics when a specification or action is
   invalid.
5. It controls which context reaches each reasoning step.

The strongest general architecture is therefore not “replace English with a new
syntax.” It is:

```text
human intent
    ↓ parse + clarify
typed declarative task representation
    ↓ validate + plan + select relevant context
bounded LLM reasoning calls
    ↓ typed actions
runtime enforcement + tools + environment
    ↓ observations and verifier diagnostics
state update, repair, and completion proof
```

This conclusion is supported from several directions:

- [SatLM](../30-sources/ye-et-al-2023-satlm.md) found that asking an LLM
  to produce a declarative constraint specification, then using a solver,
  outperformed imperative program-aided approaches across eight datasets.
- [Logic-LM](../30-sources/pan-et-al-2023-logic-lm.md) reported large gains
  from symbolic formulation, deterministic solving, and diagnostic-driven
  repair.
- [LLM+P](../30-sources/liu-et-al-2023-llm-plus-p.md) obtained mostly optimal
  plans by translating into PDDL, while direct LLM planning usually failed to
  produce a feasible plan.
- [CodeAct](../30-sources/wang-et-al-2024-codeact.md) found executable Python
  to be a more capable action representation than text or JSON tool calls.
- [AgentSpec](../30-sources/wang-et-al-2026-agentspec.md) showed that a small
  runtime-enforced policy language can prevent unsafe actions much more
  reliably than relying on model compliance.
- The recent [AgentSPEX](../30-sources/wang-et-al-2026-agentspex.md) preprint
  reports better results when a workflow is executed by an interpreter than
  when the identical workflow is merely included in a ReAct prompt.
- [TALAR](../30-sources/pang-et-al-2023-task-related-language.md) provides
  direct, bounded-domain evidence that translating natural language into a
  learned compact task language can improve instruction following and
  generalization.

No reviewed work establishes that a previously unseen, general-purpose syntax
alone gives an arbitrary pretrained LLM a deeper semantic grasp of arbitrary
assignments. A new language without examples, training, an interpreter, or
verification may instead add another translation problem.

## Scope and method

This review asks:

> Can a programming or specification language help LLM-based agents form a
> more faithful, durable, and executable representation of assigned tasks?

“Task language” is interpreted broadly. The review covers:

- languages used to prompt and compose LLM calls;
- formal intermediate representations such as logic and PDDL;
- code used as an action language;
- agent workflow and policy DSLs;
- learned task representations;
- older agent-oriented languages whose semantics remain relevant.

The review prioritizes primary papers and proceedings. It distinguishes
peer-reviewed results from recent preprints, and it separates improved task
success from claims about internal model cognition. The literature search is
current through 2026-07-30.

## 1. What a transformer receives

The original Transformer replaces recurrence with stacked self-attention and
feed-forward layers. Attention maps a query and key-value pairs to a weighted
combination of values, while positional information supplies sequence order.
The architecture operates on token representations; it does not parse a task
against a built-in operational semantics in the way a compiler parses a
program. See
[Attention Is All You Need](https://proceedings.neurips.cc/paper_files/paper/2017/hash/3f5ee243547dee91fbd053c1c4a845aa-Abstract.html).

Autoregressive LLMs turn this architecture into conditional next-token
predictors. At sufficient scale, text in the context can specify a task and
provide demonstrations without updating model weights, as established by
[Language Models are Few-Shot Learners](https://proceedings.neurips.cc/paper_files/paper/2020/hash/1457c0d6bfcb4967418bfb8ac142f64a-Abstract.html).
Instruction tuning and human feedback substantially improve whether generated
continuations satisfy user requests:
[Scaling Instruction-Finetuned Language Models](https://www.jmlr.org/papers/v25/23-0870.html)
and
[Training Language Models to Follow Instructions with Human Feedback](https://proceedings.neurips.cc/paper_files/paper/2022/hash/b1efde53be364a73914f58805a001731-Abstract.html).

Three consequences matter for language design:

1. **The representation is evidence, not authority.** Unless a runtime enforces
   it, a rule in context remains one influence among many on the next-token
   distribution.
2. **Familiar surface form matters.** In-context demonstrations communicate
   input distribution, output space, and sequence format, even when their
   input-label semantics are surprisingly weak. See
   [Rethinking the Role of Demonstrations](https://aclanthology.org/2022.emnlp-main.759/).
3. **Longer is not equivalent to better specified.** Models are distracted by
   irrelevant information, reason less reliably as irrelevant input grows, and
   often use information in the middle of long contexts poorly. See
   [Large Language Models Can Be Easily Distracted by Irrelevant Context](https://proceedings.mlr.press/v202/shi23a.html),
   [Same Task, More Tokens](https://aclanthology.org/2024.acl-long.818/), and
   [Lost in the Middle](https://aclanthology.org/2024.tacl-1.9/).

A task language should therefore reduce and route context, not merely wrap a
larger prompt in punctuation.

## 2. “Understanding” needs an operational definition

Correct output is not enough to show that a model recovered the intended task.
[Webson and Pavlick](../30-sources/webson-pavlick-2022-prompt-meaning.md)
found that irrelevant and misleading prompts could perform similarly to
meaningful prompts in natural-language inference.

For agent systems, task understanding should be measured as a bundle of
observable capabilities:

- **Goal fidelity:** Does the system preserve what outcome the assigner wanted?
- **Constraint fidelity:** Does it distinguish hard requirements, prohibitions,
  preferences, examples, and background information?
- **State grounding:** Does it bind names to actual resources, tools, files,
  people, objects, and environmental state?
- **Compositionality:** Can it combine independently specified subgoals without
  silently dropping constraints?
- **Counterfactual sensitivity:** If one condition changes, does the task model
  and behavior change in the corresponding way?
- **Clarification:** Does it identify missing or mutually inconsistent
  information instead of guessing?
- **Executability:** Can a runtime produce legal actions from the task model?
- **Completion recognition:** Can the system show why the goal is satisfied
  rather than merely deciding to stop?
- **Robustness:** Does the behavior survive paraphrase, reordering, distractors,
  longer context, and model substitution?

This definition prevents three different achievements from being conflated:

| Achievement | What it demonstrates | What it does not demonstrate |
|---|---|---|
| Syntactically valid output | Grammar or schema compliance | Correct intent |
| Successful execution | One trajectory reached an accepted result | Faithful task model or safe alternatives |
| Stable task model under perturbation | Semantic and constraint fidelity | Guaranteed execution in an open world |

The need is empirical. [FollowBench](https://aclanthology.org/2024.acl-long.257/)
found weaknesses as content, situation, style, format, and example constraints
accumulated. [Can LLMs Follow Simple Rules?](https://arxiv.org/abs/2311.04235)
found that nearly all evaluated models struggled with straightforward
programmatically checkable interaction rules and were vulnerable to simple
optimization attacks.

## 3. Six families of relevant languages

| Family | Representative work | What becomes explicit | Primary benefit | Main limitation |
|---|---|---|---|---|
| Prompt/query languages | LMQL, DSPy, APPL, PDL, SGLang | calls, variables, prompts, output shape | maintainability, optimization, constrained generation | often does not model user intent or world state |
| Reason-act protocols | ReAct, ProgPrompt | reasoning/action alternation and available actions | tool grounding and inspectable trajectories | control remains model-mediated |
| Formal task IRs | PDDL, temporal logic, SAT/SMT/FOL | state, actions, goals, logical constraints | planning and verification | semantic translation can still be wrong |
| Code action languages | PAL, Code as Policies, CodeAct | computation, data flow, tool composition | executable feedback and expressive actions | sandbox and effect risks |
| Agent workflow/policy DSLs | GOAL, ADL, AgentSpec, AgentSPEX | goals, steps, state, rules, context, permissions | runtime control and auditability | workflows can become rigid or verbose |
| Learned task languages | TALAR | compact task-relevant latent predicates | reduces policy learning burden | needs domain data and adaptation |

### 3.1 Prompt and query languages

[LMQL](../30-sources/beurer-kellner-et-al-2023-lmql.md) combines prompt text,
variables, control flow, and constraints over generated output. It demonstrates
that an inference runtime can exploit constraints during decoding, reporting
26–85% cost reductions while retaining or improving accuracy on its evaluated
tasks.

[DSPy](../30-sources/khattab-et-al-2024-dspy.md) goes further in separating a
pipeline’s declared transformations from the literal prompts used to realize
them. Natural-language typed signatures describe modules, while a compiler
optimizes instructions and demonstrations against a metric. This is a strong
argument for treating prompt wording as a compilation target, not the permanent
source language.

[APPL](https://arxiv.org/abs/2406.13161) embeds accumulated prompt context and
generation inside Python functions, adding automatic asynchronous execution,
context-passing modes, tool signatures, tracing, and replay.
[PDL](https://arxiv.org/abs/2410.19135) instead uses a declarative YAML
representation that keeps the exact prompt visible and composes model calls,
code, and tools. A later
[PDL compliance-agent case study](https://arxiv.org/abs/2507.06396) reports up
to a fourfold performance improvement after tuning the prompting pattern
relative to a canned agent pattern.

[SGLang](https://proceedings.neurips.cc/paper_files/paper/2024/hash/724be4472168f31ba1c9ac630f15dec8-Abstract-Conference.html)
provides a frontend language and optimized runtime for structured
language-model programs, reporting up to 6.4× throughput gains. This is
important systems work, but throughput is not evidence of improved task
interpretation.

**Lesson:** separate stable task semantics from model-specific prompt
realization, but do not mistake a prompt-composition language for a complete
language of intent.

### 3.2 Reasoning and acting protocols

[ReAct](https://openreview.net/forum?id=WE_vluYUL-X) interleaves reasoning
traces with actions and observations. It improved success on ALFWorld and
WebShop and reduced some hallucination and error propagation by allowing the
model to retrieve evidence. It established a highly influential agent protocol,
but both the decision to follow the protocol and the control flow remain
probabilistic.

[ProgPrompt](https://arxiv.org/abs/2209.11302) gives an LLM program-like
definitions of available actions and objects plus example executable programs.
It reported state-of-the-art success in VirtualHome and physical-robot
experiments, with ablations supporting the value of programmatic prompt
structure and constrained actions.

[Code as Policies](https://arxiv.org/abs/2209.07753) uses natural-language
commands as comments and few-shot Python policies as demonstrations. Generated
policies can compose perception and control APIs, use loops and conditionals,
and recursively define helper functions.

**Lesson:** exposing the real action vocabulary and feedback loop improves
grounding. However, a text protocol is still a soft protocol unless another
component parses and enforces it.

### 3.3 Formal intermediate representations

Formal representations produce some of the clearest results because they divide
semantic interpretation from search and execution.

[PAL](https://proceedings.mlr.press/v202/gao23f) asks the LLM to translate
natural-language reasoning problems into programs and delegates computation to
a Python interpreter. Across thirteen mathematical, symbolic, and algorithmic
tasks, program execution outperformed using the model for both decomposition
and arithmetic or symbolic manipulation.

[SatLM](../30-sources/ye-et-al-2023-satlm.md) makes an especially important
comparison: declarative constraint specifications outperformed imperative
program-aided reasoning. When the input describes relations and constraints
rather than an algorithm, matching the representation to that semantics reduces
the planning burden placed on the LLM.

[Logic-LM](../30-sources/pan-et-al-2023-logic-lm.md) translates into FOL, SAT,
constraint-satisfaction, or logic-program representations, selects a solver, and
uses solver errors to repair invalid formulations. Its reported gains over both
standard and chain-of-thought prompting support external, diagnostic-driven
repair.

[LLM+P](../30-sources/liu-et-al-2023-llm-plus-p.md) translates planning
problems into PDDL and delegates search to a classical planner. PDDL’s explicit
initial state, goal, preconditions, and effects let the planner test feasibility
and optimality instead of asking the model to imitate search.

[NL2TL](https://aclanthology.org/2023.emnlp-main.985/) addresses natural
language to temporal logic and publishes 23,000 NL–TL pairs. It uses a lifted
representation in which domain-specific propositions are abstracted away so
common logical structures can generalize across domains.
[CaStL](https://arxiv.org/abs/2410.22225) uses multi-stage extraction of goal,
ordering, and action-blocking constraints before translating them into PDDL and
Python; it reports improved constraint handling and planning success in three
PDDL domains.

**Lesson:** an agent task language should be declarative at its intent layer and
compile specialized fragments to solvers where possible. Formal syntax alone
does not guarantee semantic correctness, so round-trip explanation, unit
examples, and human confirmation remain necessary.

### 3.4 Code as an action language

Code is attractive because modern LLMs have extensive code exposure, and code
already supplies names, abstraction, data flow, composition, libraries, errors,
and an interpreter.

[CodeAct](../30-sources/wang-et-al-2024-codeact.md) provides the most direct
comparison in this category. Executable Python actions achieved up to a 20%
higher success rate than common text and JSON alternatives. A model can combine
multiple tool calls, retain intermediate values, and repair code after receiving
an exception.

Code should nevertheless be the action layer rather than the sole task layer:

- `delete(path)` says what to do, not why it is permitted.
- an imperative sequence hides acceptable alternative plans;
- success and safety properties are difficult to infer from arbitrary code;
- general-purpose execution dramatically expands the attack surface.

**Lesson:** compile or generate code behind typed capabilities and a sandbox.
Keep goals, effects, and constraints visible in a representation that can be
reviewed independently of the chosen implementation.

### 3.5 Agent specification and policy languages

Pre-LLM agent-language research already separated goal state from procedure.
[Agent Programming with Declarative Goals](../30-sources/de-boer-et-al-2002-agent-programming-with-declarative-goals.md)
introduced GOAL, in which beliefs, declarative goals, actions, and commitment
strategies have formal semantics. Its crucial distinction is between a
goal-to-be and a goal-to-do: the former survives replanning.

[ADL: A Declarative Language for Agent-Based Chatbots](https://arxiv.org/abs/2504.14787)
uses natural-language programming to describe task-oriented chatbot agents,
tool integration, and multi-agent interaction for authors who may not be
programmers. The paper emphasizes authoring and abstraction more than rigorous
comparative evidence about task fidelity.

[AgentSpec](../30-sources/wang-et-al-2026-agentspec.md) focuses on a narrower
but better-enforced layer: event triggers, predicates, and enforcement actions.
Its results show why safety rules belong in an execution monitor rather than
only in an LLM prompt.

[AgentSPEX](../30-sources/wang-et-al-2026-agentspex.md) is the closest direct
match to a contemporary agent programming language. It uses YAML for typed
steps, branching, loops, parallel execution, submodules, variables, and
explicit context management. Its key comparison uses the same workflow in two
conditions: interpreted step-by-step, or placed in a ReAct prompt for the model
to interpret freely. The interpreter-enforced condition performs better across
the reported benchmarks, while the prompt-only workflow can add enough
complexity to hurt performance.

[LLM-as-Code: Agentic Programming for Agent Harness](https://arxiv.org/abs/2606.15874),
a 2026 workshop paper, argues for ordinary code to govern branching, looping,
and sequencing while LLM calls remain adaptive components. Its case study
reports improved stability on long computer-use sequences, but the evidence is
narrower than AgentSPEX’s multi-benchmark evaluation.

[Provable Coordination for LLM Agents via Message Sequence Charts](https://arxiv.org/abs/2604.17612)
defines a DSL from which local multi-agent programs can be projected with
deadlock-free coordination and type-consistent messaging independent of the
unpredictability inside each LLM action. This is promising recent preprint
evidence that formal guarantees can surround, rather than attempt to eliminate,
model nondeterminism.

**Lesson:** a useful language draws a semantic firewall around probabilistic
reasoning. The runtime owns control flow, permissions, message protocols,
resource bounds, and hard invariants; the LLM owns interpretation and generation
only where those are genuinely needed.

### 3.6 Learned task languages

[TALAR](../30-sources/pang-et-al-2023-task-related-language.md) tests a different
hypothesis: instead of designing the representation manually, learn a concise
predicate-like language tied to the task environment, then train a translator
from natural language and a policy conditioned on that language.

The improvement over direct natural-language-conditioned reinforcement
learning supports a task-relevant bottleneck. The representation can discard
linguistic variation that is unimportant to action while retaining relations
the policy needs. It also adapts to unseen phrasings.

This evidence does not directly transfer to general pretrained LLM agents. The
language is learned jointly around a bounded environment and a trained policy.
It does suggest a longer-term direction: a human-readable source language could
compile into model- or domain-specific task embeddings rather than assuming one
surface representation is optimal for every agent.

## 4. What the evidence supports—and what it does not

### Supported with reasonably strong evidence

- Explicit action vocabularies and executable feedback improve agent grounding.
- Interpreters and solvers reliably remove classes of arithmetic, search,
  control-flow, and syntax errors.
- Declarative constraints can be easier for an LLM to extract than an imperative
  solution procedure when the source problem itself is declarative.
- Compact task-relevant representations can improve bounded-domain
  instruction-following policies.
- Separating modules and prompt parameters permits automated optimization
  across models and tasks.
- Runtime enforcement is substantially more reliable for hard safety
  constraints than asking a model to remember them.
- Explicit context routing can reduce the burden and degradation caused by
  growing conversation histories.

### Not established

- That LLMs possess a human-equivalent internal concept of an assigned task.
- That any one syntax is universally optimal across models and domains.
- That syntactic validity implies faithful intent translation.
- That a general-purpose agent DSL outperforms natural language on every task.
- That a language can compensate for missing world knowledge or perception.
- That self-reflection without new evidence provides reliable correction.
  [Large Language Models Cannot Self-Correct Reasoning Yet](https://openreview.net/forum?id=IkmD3fKBPQ)
  finds that intrinsic self-correction often fails or degrades answers; solver,
  test, tool, or human feedback is categorically more useful.

Constrained decoding deserves a similar caution. It can guarantee membership in
a grammar, but it can also distort the model’s learned distribution and reduce
quality. [Grammar-Aligned Decoding](https://proceedings.neurips.cc/paper_files/paper/2024/hash/2bdc2267c3d7d01523e2e17ac0a754f3-Abstract-Conference.html)
shows why “always parses” and “best semantic answer” are different objectives.

## 5. Recommended design for an agent task language

The proposed language should have two faces:

1. a concise human-facing source language with controlled natural-language
   escape hatches;
2. a typed intermediate representation consumed by the runtime.

The first prototype should use a familiar serialized AST—YAML or JSON with a
published schema—before inventing extensive novel punctuation. A later textual
syntax can compile to the same IR once the semantics are stable.

### 5.1 Semantic layers

#### Intent layer

Represents what the assigner means:

- task name and natural-language rationale;
- inputs and bindings;
- initial facts, assumptions, and unknowns;
- declarative goals;
- hard invariants and prohibitions;
- preferences and optimization objectives;
- examples and counterexamples;
- observable completion criteria.

#### Capability and effect layer

Represents what the agent can change:

- typed tool signatures;
- preconditions and postconditions;
- read, write, network, communication, and spending effects;
- resource and scope restrictions;
- reversibility and idempotence;
- authorization requirements.

These are three separate semantic objects. An **effect** names the observable
operation family; a **capability requirement** is the task's declarative upper
bound; and a **runtime grant** proves that a particular principal holds enough
authority. [UCAN capabilities for A-Lang](ucan-capabilities-for-agent-language.md)
develops one concrete grant backend: the broker issues a signed, attenuated
Delegation and turns a concrete typed effect call into a signed Invocation.
The execution-time reference monitor still owns stateful policy and resource
semantics.

#### Workflow layer

Represents deterministic orchestration:

- dependency graphs and concurrency;
- bounded loops;
- checkpoints;
- escalation and clarification;
- recovery policies;
- context inputs and outputs for each LLM call.

#### Evidence layer

Represents why the system believes it is done:

- observations and provenance;
- verifier results;
- tests and acceptance predicates;
- unresolved uncertainty;
- a completion witness tied back to each goal and hard constraint.

### 5.2 Essential distinctions

The language should make these pairs different types rather than conventions:

| Distinction | Why it matters |
|---|---|
| `goal` vs. `plan` | replanning must not mutate intent |
| `fact` vs. `assumption` | uncertain premises require checking |
| `hard` vs. `prefer` | only hard constraints block execution |
| `example` vs. `requirement` | examples should not silently become universal rules |
| `capability` vs. `permission` | a tool may exist without being authorized |
| `observation` vs. `inference` | provenance and confidence differ |
| `success` vs. `stop` | termination is not proof of completion |
| `private` vs. `shared` context | subagents should see only what they need |

### 5.3 Illustrative source syntax

This is a design sketch, not a settled grammar:

```text
task research(topic: Text) -> report: MarkdownArtifact {
  intent:
    "Determine whether task-specification languages improve LLM agents."

  given {
    workspace = path("/research")
    cutoff = date("2026-07-30")
  }

  unknown {
    preferred_citation_style
  }

  goal {
    report.exists
    report.answers(topic)
    report.distinguishes(peer_reviewed, preprint)
  }

  hard {
    every empirical claim has primary_source
    do_not invent citation
    writes within workspace
  }

  prefer {
    maximize evidence_quality
    minimize duplicated context
  }

  capabilities {
    web.search: allow
    web.read: allow
    workspace.read: allow(path = workspace/**)
    workspace.write: allow(path = workspace/**, reversible = true)
  }

  clarify when {
    unknown blocks goal
    constraints conflict
    requested action exceeds permission
  }

  verify {
    links.resolve
    frontmatter.valid
    claims.trace_to(primary_source)
  }

  recover {
    on tool.transient_failure: retry(max = 2)
    on verify.failure: repair(failed_fragment)
    on permission.denied: ask
  }
}
```

The compiler could lower this into:

- a JSON- or YAML-typed task object;
- a minimal prompt for each semantic step;
- JSON Schema or grammar constraints for model outputs;
- a dependency DAG;
- capability tokens for tool execution;
- PDDL, SMT, temporal-logic, or test fragments where applicable;
- runtime monitors for hard constraints;
- a completion checklist with machine and human evidence.

### 5.4 What the LLM should and should not control

| Concern | Preferred owner |
|---|---|
| Interpret open-ended human meaning | LLM, with clarification |
| Select relevant evidence | LLM plus retrieval |
| Generate hypotheses and prose | LLM |
| Branching required by a declared workflow | runtime |
| Loop bounds and budgets | runtime |
| Type and grammar validity | parser/type checker |
| Arithmetic and constraint solving | interpreter/solver |
| File, network, payment, and messaging permissions | capability system |
| Safety invariants | reference monitor |
| Completion of mechanically testable conditions | verifier |
| Acceptance of ambiguous subjective output | human or explicit evaluator |

## 6. Compiler and runtime architecture

A practical implementation can be staged:

1. **Parse.** Convert source text and embedded natural language into an AST.
2. **Resolve.** Bind names to tools, resources, artifacts, and principals.
3. **Type-check.** Check tool inputs, outputs, effects, state transitions, and
   hard-constraint references.
4. **Clarify.** Produce questions for unresolved variables that materially
   affect the task.
5. **Plan.** Build a dependency graph or call a specialized planner; preserve
   the original goals separately.
6. **Slice context.** Pass each model call only the goal fragment, state,
   capabilities, and evidence it requires.
7. **Execute.** Run typed actions within scoped capabilities and budgets.
8. **Monitor.** Check invariants before and after effects.
9. **Repair.** Feed parser, solver, test, or environment diagnostics back to the
   smallest responsible task fragment.
10. **Prove completion.** Evaluate each success predicate and retain its
    evidence.

The runtime should be event-sourced. Every change to beliefs, artifacts,
permissions, and task state should have a provenance-bearing event so that
replay, audit, recovery, and counterfactual evaluation are possible.

## 7. Research program to test the hypothesis

The language should be justified by controlled ablation rather than aesthetics.

### 7.1 Conditions

Run the same tasks and base models under:

1. natural-language prompt only;
2. structured Markdown sections;
3. JSON/YAML schema without runtime enforcement;
4. executable Python workflow;
5. a formal domain representation such as PDDL or SMT where applicable;
6. the proposed task language without runtime enforcement;
7. the proposed task language with compiler and runtime enforcement.

The difference between conditions 6 and 7 is crucial. AgentSPEX suggests that
the interpreter, not merely showing the workflow syntax to the model, produces
much of the benefit.

### 7.2 Task suite

Include tasks with different semantic shapes:

- repository changes with tests and scope constraints;
- evidence-based research with citation provenance;
- web workflows with forms, authentication, and side effects;
- scheduling and resource allocation;
- embodied or simulated planning;
- multi-agent delegation and message protocols;
- deliberately ambiguous tasks requiring clarification;
- safety-sensitive tasks with prohibited actions.

### 7.3 Perturbations

For every base task, generate controlled variants:

- paraphrase without semantic change;
- reorder requirements;
- insert irrelevant but plausible details;
- add one constraint at a time;
- create a conflict between two constraints;
- remove one necessary input;
- place critical information at the beginning, middle, or end;
- rename tools and resources;
- change one fact that should alter the plan;
- present malicious instructions inside retrieved content.

### 7.4 Metrics

Measure more than final success:

- goal and per-constraint satisfaction;
- semantic equivalence of the parsed task model;
- legal-action and tool-argument accuracy;
- unnecessary or unauthorized effects;
- clarification precision and recall;
- recovery success after injected failures;
- completion false-positive rate;
- tokens, latency, monetary cost, and tool calls;
- human authoring time and error rate;
- cross-model and cross-version portability;
- trace comprehensibility;
- performance under each perturbation.

Use executable tests wherever possible and blinded human evaluation where
meaning is subjective. Report syntax validity separately from semantic validity.

### 7.5 Minimum falsification criteria

The hypothesis should be rejected or narrowed if:

- a structured language improves parsing but not task success;
- gains disappear when token budget and examples are controlled;
- a familiar JSON/Python representation performs as well with less authoring
  cost;
- improvements depend entirely on one model family;
- the compiler silently repairs enough specifications that the source language
  no longer carries the claimed semantics;
- authors make more semantic mistakes than they do in structured natural
  language.

## 8. Research priorities

1. **Build the task model before the surface language.** Define the typed AST,
   effects, and completion semantics first.
2. **Prototype in YAML or JSON.** Modern models have ample exposure to these
   formats, and mature parsers and schema validators already exist.
3. **Start with a narrow domain.** Repository work is attractive because files,
   diffs, tests, commands, and permissions produce observable evidence.
4. **Implement hard/soft constraints and goal/plan separation first.** These
   have the clearest semantic value.
5. **Add a capability and effect system before arbitrary code execution.**
6. **Treat clarification as a language construct.** Missing information is a
   first-class state, not an invitation to hallucinate.
7. **Make compilation inspectable.** Users should see the normalized task model,
   planned workflow, and permissions before consequential execution.
8. **Use external feedback for repair.** Parser errors, test failures, solver
   counterexamples, and human corrections are preferable to unsupported
   self-reflection.
9. **Train or optimize adapters only after establishing a baseline.** DSPy-like
   compilation and TALAR-like learned representations can follow once the
   semantics and evaluator are credible.

## 9. Annotated paper guide

### Foundations and limitations

- [Attention Is All You Need](https://proceedings.neurips.cc/paper_files/paper/2017/hash/3f5ee243547dee91fbd053c1c4a845aa-Abstract.html)
  — Transformer architecture.
- [Language Models are Few-Shot Learners](https://proceedings.neurips.cc/paper_files/paper/2020/hash/1457c0d6bfcb4967418bfb8ac142f64a-Abstract.html)
  — tasks and demonstrations specified in context.
- [Training Language Models to Follow Instructions with Human Feedback](https://proceedings.neurips.cc/paper_files/paper/2022/hash/b1efde53be364a73914f58805a001731-Abstract.html)
  — model scale alone does not guarantee intent following.
- [Do Prompt-Based Models Really Understand the Meaning of Their Prompts?](../30-sources/webson-pavlick-2022-prompt-meaning.md)
  — performance is insufficient evidence of human-like prompt understanding.
- [Rethinking the Role of Demonstrations](https://aclanthology.org/2022.emnlp-main.759/)
  — input distribution, label space, and format drive much in-context behavior.
- [FollowBench](https://aclanthology.org/2024.acl-long.257/)
  — fine-grained constraint-following benchmark.
- [Can LLMs Follow Simple Rules?](https://arxiv.org/abs/2311.04235)
  — programmatically evaluated rule-following failures.
- [Lost in the Middle](https://aclanthology.org/2024.tacl-1.9/)
  — position-sensitive use of long context.

### Reasoning, acting, and formalization

- [ReAct](https://openreview.net/forum?id=WE_vluYUL-X)
  — interleaved reasoning, action, and observation.
- [ProgPrompt](https://arxiv.org/abs/2209.11302)
  — program-like robot action and object specifications.
- [Code as Policies](https://arxiv.org/abs/2209.07753)
  — generated Python policies for embodied control.
- [PAL](https://proceedings.mlr.press/v202/gao23f)
  — program generation with interpreter-executed reasoning.
- [SatLM](../30-sources/ye-et-al-2023-satlm.md)
  — declarative constraints plus theorem proving.
- [Logic-LM](../30-sources/pan-et-al-2023-logic-lm.md)
  — multiple symbolic formalisms, solvers, and diagnostic repair.
- [LLM+P](../30-sources/liu-et-al-2023-llm-plus-p.md)
  — natural language to PDDL and classical planning.
- [NL2TL](https://aclanthology.org/2023.emnlp-main.985/)
  — natural-language to temporal-logic translation.
- [CaStL](https://arxiv.org/abs/2410.22225)
  — constraint extraction for long-horizon task and motion planning.

### Languages and runtimes

- [GOAL](../30-sources/de-boer-et-al-2002-agent-programming-with-declarative-goals.md)
  — declarative goals, beliefs, commitment strategies, and proof theory.
- [LMQL](../30-sources/beurer-kellner-et-al-2023-lmql.md)
  — scripting and constraints for language-model queries.
- [DSPy](../30-sources/khattab-et-al-2024-dspy.md)
  — declarative modules compiled against task metrics.
- [APPL](https://arxiv.org/abs/2406.13161)
  — Python-native prompt programming, context semantics, tracing, and replay.
- [PDL](https://arxiv.org/abs/2410.19135)
  — YAML-based declarative prompt programs.
- [SGLang](https://proceedings.neurips.cc/paper_files/paper/2024/hash/724be4472168f31ba1c9ac630f15dec8-Abstract-Conference.html)
  — language and runtime for efficient structured LM programs.
- [CodeAct](../30-sources/wang-et-al-2024-codeact.md)
  — executable Python as a unified agent action space.
- [TALAR](../30-sources/pang-et-al-2023-task-related-language.md)
  — learned task-related language and natural-language translator.
- [ADL](https://arxiv.org/abs/2504.14787)
  — declarative natural-language programming for agent-based chatbots.
- [AgentSpec](../30-sources/wang-et-al-2026-agentspec.md)
  — runtime safety policy DSL.
- [AgentSPEX](../30-sources/wang-et-al-2026-agentspex.md)
  — executable YAML agent workflows with explicit context.
- [LLM-as-Code](https://arxiv.org/abs/2606.15874)
  — program-controlled agent harness with LLMs as adaptive components.
- [Provable Coordination via Message Sequence Charts](https://arxiv.org/abs/2604.17612)
  — projected multi-agent protocols with structural guarantees.

## Connections

- [Can a task language improve LLM agents?](../40-inquiries/can-a-task-language-improve-llm-agents.md)
- [LLM agent task languages](../10-maps/llm-agent-task-languages.md)
- [Set and category principles for an agent programming language](set-and-category-principles-for-agent-programming-language.md)
  develops one candidate semantic foundation for the typed task IR.
- [Categorical foundations for agent languages](../10-maps/categorical-foundations-for-agent-languages.md)
  maps the supporting programming-language and applied-category literature.
- [UCAN capabilities for A-Lang](ucan-capabilities-for-agent-language.md)
  maps the declarative capability layer to portable signed grants and
  execution-time invocations without exposing signing authority to the LLM.

## Status of the thesis

The present evidence justifies building and testing a typed, declarative,
runtime-enforced task language. It does not yet justify claiming a universal
language of thought for LLMs. The immediate research target should be improved
semantic fidelity, constraint satisfaction, and verifiable task completion—not
an unmeasurable claim about subjective understanding.
