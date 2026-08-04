---
title: "Can a task language improve LLM agents?"
kind: inquiry
created: 2026-07-30
status: open
tags:
  - llm-agents
  - task-specification
  - programming-languages
aliases:
  - "Would a programming language help LLM agents understand tasks?"
---

# Can a task language improve LLM agents?

## Why this matters

Natural language is expressive and accessible, but it often leaves goals,
constraints, state, permissions, and completion conditions implicit. LLM agents
must then recover those distinctions while also planning, selecting tools,
tracking state, and deciding when to stop.

A task language might separate these concerns and make part of the agent’s
behavior inspectable and enforceable. It might also fail by adding unfamiliar
syntax, imposing a brittle worldview, or merely moving ambiguity into a
translation step.

## Operational question

Does a typed, declarative, runtime-enforced task representation improve:

- faithful recovery of goals and constraints;
- clarification of missing information;
- legal and safe tool use;
- robustness to paraphrase, distractors, and long context;
- recovery from execution failures;
- correct recognition of task completion;

relative to natural language, structured Markdown, JSON schemas, Python
workflows, and domain-specific formal languages?

## Provisional answer

Probably, if the language is treated as an executable contract and intermediate
representation rather than a more elaborate prompt.

The evidence is strongest for:

- declarative goals and constraints;
- typed action and tool interfaces;
- external solvers and interpreters;
- runtime-enforced permissions and invariants;
- explicit state and context flow;
- verifier-driven repair.

There is not yet evidence for a universal novel syntax that inherently produces
deeper semantic understanding in arbitrary pretrained LLMs.

## Working hypotheses

1. A declarative specification will outperform an imperative procedure when the
   assignment primarily states desired outcomes and constraints.
2. Runtime enforcement will account for more of the improvement than the
   surface syntax shown to the model.
3. Familiar YAML, JSON, or Python representations will initially outperform a
   novel syntax unless the novel language receives demonstrations or training.
4. Separating goals from plans will improve recovery after environmental
   failure.
5. Explicit hard/soft constraint types will reduce both dropped requirements
   and needless refusals.
6. Context slicing by declared dependencies will improve long-horizon behavior
   and reduce cost.
7. Semantic translation errors will become the dominant residual failure after
   syntax, planning, and execution are mechanically checked.

## Paths to explore

- Define a typed task AST independent of surface syntax.
- Implement the AST first as schema-validated YAML.
- Compile repository-editing tasks into scoped capabilities, steps, and tests.
- Compare prompt-only and interpreter-enforced execution using the same task
  representation.
- Add perturbation tests for paraphrase, reordering, missing facts, conflicting
  constraints, irrelevant context, and prompt injection.
- Investigate round-trip checks in which the model paraphrases the normalized
  task and a human approves material assumptions before execution.
- Test whether a DSPy-style compiler can adapt prompt realizations of the same
  task IR across different model families.
- Explore learned, task-specific representations only after the authored
  semantics and evaluators are stable.

## Findings

- [Task languages for LLM agents: a deep dive](../20-notes/llm-agent-task-languages-deep-dive.md)
- [LLM agent task languages](../10-maps/llm-agent-task-languages.md)
- The [minimal proof of concept](../src/phase-08/reproducible-demonstration-package.md)
  shows that a typed task representation can drive BEAM compilation, runtime
  enforcement, bounded effects, and evidence-backed completion.
- The [controlled comparison](../src/phase-08/controlled-baseline-and-ablation-comparison.md)
  isolates material runtime-enforcement value but does not test whether an LLM
  understands a task better. Effectful acceptance tasks still begin as
  constructed typed IR rather than user-authored A-Lang source.
- The [architecture decision](../src/phase-08/proof-of-concept-architecture-decision.md)
  therefore narrows the demonstrated claim to executable contracts and makes
  effectful source-language fidelity the next decision boundary.

## Outcome

The inquiry remains open. The prototype supports runtime-enforced task
contracts, but the central language-understanding and source-notation questions
remain untested. The next comparison must start from user-authored effectful
source, hold the BEAM runtime constant, and measure fidelity against a strong
conventional typed notation across declared model families.
