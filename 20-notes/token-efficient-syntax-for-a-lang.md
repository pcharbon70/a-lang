---
title: "Token-efficient syntax for A-Lang"
kind: note
created: 2026-08-11
maturity: developing
tags:
  - a-lang
  - language-design
  - llm-agents
  - token-efficiency
  - tokenization
aliases:
  - "Compact A-Lang syntax"
  - "Token-efficient A-Lang"
---

# Token-efficient syntax for A-Lang

## Executive conclusion

A-Lang should pursue a shorter **model-facing projection**, not make opaque
short names the canonical authored language.

The best-supported design is a dual representation:

1. humans author and review descriptive A-Lang;
2. the BEAM-resident compiler parses and statically checks it into the existing
   typed IR;
3. a deterministic projector emits a versioned, compact representation for
   model input or output;
4. the inverse projector reconstructs exactly the same checked semantics before
   the ordinary checker, backend, and runtime are allowed to proceed.

This approach preserves the project's central goal—an executable, inspectable,
runtime-enforced task contract—while creating a place to optimize token cost.
It also preserves the whole-toolchain BEAM invariant: the projector and inverse
parser must compile to `.beam` and run on ERTS with the rest of the trusted
compiler.

The evidence does not support globally changing descriptive identifiers such
as `release-workspace` into arbitrary one-letter names. Names carry semantic
information, pretrained models are brittle under syntax and name
perturbations, and the closest agent study found only small token savings from
identifier shortening with potentially material task loss. Compress repeated
schema and compiler-known structure first; shorten local names only as a
separately tested ablation.

## The question in A-Lang's terms

The current [A-Lang v2 language](alang-v2-language-reference.md) explicitly
spells out facts, inputs, effects, requirements, scopes, budgets, action
dependencies, error branches, child attenuation, completion predicates,
clarifications, and terminal state. That repetition is not accidental. The
compiler independently infers effects and requirements, compares them with the
declarations, and passes a closed capability contract to the runtime.

Token efficiency must therefore be defined more carefully than “fewer
characters”:

- **representation cost:** tokens charged or admitted by each target model;
- **semantic fidelity:** exact recovery of every field in the typed task IR;
- **behavioral fidelity:** no loss in constraint recovery, clarification,
  legal action selection, error handling, or completion judgment;
- **safety fidelity:** no widened effects, scopes, budgets, child authority, or
  false completion;
- **human cost:** authoring, reviewing, diagnosing, and migrating the language;
- **system cost:** projection, repair calls, latency, and model-specific
  adaptation.

A compact form is better only if it improves this combined outcome. A 30%
token reduction accompanied by more repairs or one additional unauthorized
effect is a regression for A-Lang.

Four interventions should be kept separate:

| Intervention | Example | What it changes |
| --- | --- | --- |
| Layout minification | remove optional spaces and newlines | non-semantic surface form |
| Grammar/schema compaction | `model-calls` → `m`, omit reconstructible empty fields | repeated compiler-known structure |
| Identifier shortening | `release-workspace` → `w` | names chosen to carry local meaning |
| Pattern sugar | one symbol represents a frequent subtree | a learned or predefined semantic macro |

Conflating these interventions would make it impossible to tell which saving
caused a fidelity change.

## What the evidence says

### Token count is a model property, not a spelling property

[Dagan, Synnaeve, and Roziere](https://proceedings.mlr.press/v235/dagan24a.html)
([reading note](../30-sources/dagan-et-al-2024-tokenizer-domain-adaptation.md))
show that vocabulary size, pre-tokenization rules, and training data affect
code generation speed, effective context, memory, and downstream performance.
Their successful tokenizer specialization also requires model adaptation at a
scale above roughly 50 billion tokens. A-Lang cannot assume that a spelling
which is cheap for one hosted model remains cheap for another.

A recent compact-constraint preprint supplies a useful negative control.
[Tang](https://arxiv.org/abs/2604.07192)
([reading note](../30-sources/tang-2026-compact-constraint-encoding.md))
expected Classical Chinese to be dense, but measured only 4.6% savings because
the tested BPE vocabulary represented the characters inefficiently. Human
information density and character count were poor proxies for tokens.

The same lesson appears in practitioner work. In one configuration-object
exercise, [Rickard](https://blog.matt-rickard.com/p/a-token-efficient-language-for-llms)
([reading note](../30-sources/rickard-2023-token-efficient-language.md))
measured pretty JSON at 162 OpenAI tokens, YAML at 85, and minified JSON at 64;
the figures and ordering changed with a LLaMA tokenizer. This is a useful
warning against the common claim that YAML, JSON, or any new notation is
intrinsically token-efficient. The post is an illustrative example, not a
benchmark.

**Implication:** A-Lang needs a tokenizer report per deployed model and corpus.
The compiler may optimize against an explicit tokenizer profile, but the
language specification should not promise a universal token ratio.

### Removing optional layout is the lowest-risk first step

[Pan et al.](https://arxiv.org/abs/2508.13666)
([reading note](../30-sources/pan-et-al-2025-hidden-cost-readability.md))
remove only layout whose removal preserves a program's AST. Across four
mainstream languages, ten models, and fill-in-the-middle completion, they
report about 24.5% average input-token reduction with generally small
correctness changes. Savings differ sharply by language because Python cannot
discard semantically meaningful indentation and newlines. They retain a
bidirectional transformer so human-readable code need not be sacrificed.

That is encouraging for a brace-and-semicolon language such as A-Lang, but the
task difference matters. Local code completion with a mainstream grammar is
not exact recovery of an unfamiliar capability contract. A-Lang should adopt
the paper's invariant—parse before and after, then compare structure—without
assuming its average result.

### Identifier names are not mere storage overhead

[CodeT5](https://aclanthology.org/2021.emnlp-main.685/)
([reading note](../30-sources/wang-et-al-2021-codet5.md)) treats
developer-assigned identifiers as rich code semantics. Its identifier-aware
pretraining tags names and learns to recover consistently masked identifiers.
This does not prove that every long name is useful, but it establishes that
names are a learnable signal rather than semantically empty punctuation.

[ReCode](https://aclanthology.org/2023.acl-long.773/)
([reading note](../30-sources/wang-et-al-2023-recode.md)) reinforces the
caution. More than 30 meaning-preserving-intended changes to docstrings,
function names, variable names, syntax, and layout expose substantial
worst-case instability in CodeGen, InCoder, and GPT-J. Syntax perturbations are
the most damaging category, and consistent name changes can still change
generation behavior.

The most direct evidence comes from
[Hrubec and Cito](https://arxiv.org/abs/2606.01326)
([reading note](../30-sources/hrubec-cito-2026-minification.md)). In a
100-instance GPT-4.1 SWE-bench Verified ablation, shortening variables,
functions, or classes saves only about 2.9%, 2.6%, and 4.5% of input tokens.
Resolution changes from a 46% baseline to 38%, 42%, and 45% respectively.
Variants that preserve a mapping recover more performance while saving fewer
tokens. The sample is small and stochastic, but its direction matches the
semantic-name evidence: identifier opacity needs a stronger burden of proof
than whitespace removal.

**Implication:** retain descriptive global task, resource, input, and evidence
names. If repeated references are expensive, bind a descriptive name once and
use a compiler-generated local alias. Keep the bidirectional name map in
diagnostics and evaluation.

### Compact structure can work when the vocabulary remains familiar

Tang compares full natural-language constraints with compact natural language
and tag headers across 11 models, 16 code-generation tasks, and more than 830
calls. The header reduces its constraint section by about 71% and the full
prompt by roughly 25–30%, with no detected compliance difference among the
three encodings. The confidence interval does not establish formal
equivalence, the platform is not externally reproducible, and failures cluster
in a few constraint types. It is nevertheless evidence that mnemonic,
model-familiar tags can compress stable constraint schema without an obvious
penalty.

[LLMLingua](https://aclanthology.org/2023.emnlp-main.825/)
([reading note](../30-sources/jiang-et-al-2023-llmlingua.md)) reaches much
higher compression by allocating different budgets to instructions,
demonstrations, and questions and iteratively removing lower-information
tokens. Its ablations show that indiscriminate removal is worse than preserving
dependencies and protecting sensitive prompt parts. A-Lang cannot use its
lossy method on the only copy of a security contract, but it can adopt the
allocation insight: compress closed scaffolding more aggressively than task
facts, prohibitions, paths, numeric budgets, and completion evidence.

### Semantic macros work after adaptation, not by surprise

[Token Sugar](https://arxiv.org/abs/2512.08266)
([reading note](../30-sources/sun-et-al-2025-token-sugar.md)) mines 799
frequent, token-heavy Python AST patterns and replaces them with reversible
special-token shorthands. Adapted small models reduce generated tokens by
7.7–11.2% with no desugaring failures and near-identical Pass@1 to matched
training baselines.

Its zero-shot experiment is decisive for A-Lang's near-term design. GPT-4.1
scores 94.5% Pass@1 on ordinary Python prefixes, 51.2% on sugarized prefixes,
and only 54.9% when examples of the sugars are added to the prompt. The paper
concludes that dedicated training is needed.

**Implication:** frequent A-Lang subtrees may eventually become learned macros
for a model family that A-Lang controls or adapts. Opaque macros should not be
the universal interchange with unadapted hosted models.

### End-to-end minification exposes the real tradeoff

Hrubec and Cito's full state-in-context run reduces average input from 90,535
to 52,776 tokens, or 42%, but lowers SWE-bench Verified resolution from 50% to
38%. A semantics-preserving source transformation is therefore not necessarily
performance-preserving for an LLM. A-Lang must report a Pareto frontier of
tokens and fidelity; token savings alone are not a success metric.

## Local corpus screening measurement

The frozen effectful-source-fidelity corpus provides a preliminary accounting
exercise. This is **not** a model trial and does not change or add a condition
to the frozen [planning stream](../60-planning/02-effectful-source-fidelity/README.md).

The measurement used all 24 model-visible `.alang` documents and their 24
minified typed-JSON controls. Corpus metadata before `model-visible-begin` was
excluded. Counts used tiktoken 0.12.0 with `cl100k_base` and `o200k_base` as
reproducible proxies; neither is asserted to be the exact tokenizer of the
hosted experiment models.

| Screening representation | `cl100k_base` | Change | `o200k_base` | Change |
| --- | ---: | ---: | ---: | ---: |
| Readable A-Lang v2 | 5,570 | baseline | 5,571 | baseline |
| Layout-minified A-Lang | 5,089 | −8.6% | 5,198 | −6.7% |
| Minified plus fixed keyword aliases | 4,347 | −22.0% | 4,359 | −21.8% |
| Minified plus derived top-level declarations | 4,693 | −15.7% | 4,755 | −14.6% |
| Checked compact projection | 3,988 | −28.4% | 4,000 | −28.2% |
| Compact projection plus opaque user identifiers | 3,687 | −33.8% | 3,692 | −33.7% |
| Existing minified typed JSON | 7,236 | +29.9% | 7,537 | +35.3% |

The transformations are deliberately simple screening conditions:

- layout minification collapses optional whitespace outside strings;
- aliases replace repeated closed vocabulary with fixed mnemonic forms, such
  as `facts→f`, `requirements→use`, `scopes→at`, `limits→cap`,
  `model-calls→m`, `timeout-ms→t`, `depends→<-`, `complete→ok`, and
  `artifact-exists→exists`;
- the derived condition omits top-level `effects` and `requirements` only from
  an already checked IR, where they remain recoverable from actions and scopes;
- the opaque condition consistently substitutes user identifiers with
  `a`, `b`, and so on while leaving string facts and paths unchanged.

Three observations matter more than the exact counts:

1. Readable A-Lang is already about 23% (`cl100k`) to 26% (`o200k`) smaller
   than the existing minified JSON controls on this corpus.
2. Optional layout alone offers only 7–9%, which is plausible given that v2 is
   already fairly dense.
3. Turning user identifiers opaque adds only about 5.4 percentage points beyond
   the checked compact projection. Most estimated savings come from repeated
   grammar and schema, not from erasing task names.

The compact candidates are not accepted syntax, have not passed the A-Lang
parser, and have not been shown to preserve model fidelity. They bound an
opportunity; they do not establish a language change.

## Design alternatives

| Alternative | Likely saving | Model risk | Human cost | Assessment |
| --- | --- | --- | --- | --- |
| Keep readable v2 only | none | known baseline | low | retain as control and canonical source |
| Canonical layout minifier | small | low to moderate | low with automatic formatting | first experiment |
| Checked compact projection | medium | moderate until tested | low if hidden behind tooling | recommended direction |
| Compact authored surface | medium | moderate to high | higher review and diagnostic burden | do not make canonical yet |
| Opaque one-letter identifiers | small incremental saving | high relative to saving | high | reject by default |
| Position-only vectors such as `cap[3,1,0,…]` | medium | silent field-swap risk | high | reject for authority and budgets |
| Learned semantic macros | potentially medium | severe zero-shot risk | training and versioning cost | later, model-specific research |
| Replace a pretrained tokenizer | potentially large | model migration risk | very high training cost | out of near-term scope |

## Proposed compact-projection architecture

The compact representation should be a serialization of checked semantics, not
a second informal language that can drift from the compiler.

```text
readable A-Lang source
        │
        ▼
BEAM lexer → parser → resolver → checker → typed IR + derived semantics
                                             │
                                             ▼
                              versioned compact projector
                                             │
                                             ▼
                                      model-visible form
                                             │
                                             ▼
                              inverse parser + round-trip check
                                             │
                                             ▼
                         same checker → same backend → same ERTS runtime
```

The projection needs the following invariants:

- **Versioned:** use a distinct identifier such as `alang-model-v1`; do not
  silently redefine `alang-source-v2`.
- **Bijective over checked IR:** decoding the projection must reproduce a
  canonical IR byte-for-byte or by an explicitly versioned semantic digest.
- **No implicit authority:** non-empty effects, scopes, budgets, child grants,
  error branches, and completion predicates cannot disappear. A field may be
  omitted only if the decoder deterministically restores its exact value.
- **No positional security fields:** budgets and scopes retain keyed forms so a
  transposition cannot turn bytes into time or child calls into model calls.
- **Descriptive names once:** full task and resource names are declared once;
  compiler-assigned local aliases may compress repeated references and always
  carry a reverse map.
- **Tokenizer-profiled:** alias choice is measured against each target
  tokenizer. Unicode density and character length are not selection criteria.
- **Source-mapped:** diagnostics name the readable field and original
  identifier, never only an alias such as `m` or `x3`.
- **Canonical:** one IR has one compact rendering so cache keys, semantic
  digests, and evaluations are stable.
- **BEAM-native:** projector, decoder, validators, and compiler command remain
  trusted BEAM modules; no foreign sidecar enters the compiler path.

An illustrative projection might look like this:

```alang
task release-note{
  f["Create a release note","Do not invent changes"];
  i changes:json!;
  at{m[writer];w[output];p[note="/workspace/release-note.md"]};
  cap{s=3;m=1;r=0;c=0;w=1;b=2048;t=30s};
  draft=gen;publish=put<-draft;finish=done<-publish;
  ok[exists note,u8 note,maxb note=2048];end done;
}
```

This example is a design probe, not a proposed grammar. Its useful ideas are
structural: bind a repeated path once, retain mnemonic boundaries, key every
budget, derive repeated manifests only after checking, and make empty/default
fields reconstructible. Whether `f`, `at`, or `cap` is actually cheaper and
understood must be measured per tokenizer and model.

## Evaluation before any language change

The compact question should become a new, separately versioned experiment
after the frozen effectful-source-fidelity stream. Reusing its semantic cases
is valuable; modifying its files, prompts, or preregistered conditions is not.
The resulting design now lives in the
[compact projection fidelity plan](../60-planning/03-compact-projection-fidelity/README.md):
the old cases are development-only, a new 24-case corpus supplies confirmatory
evidence, and 1,152 primary cells cross six comprehension conditions with a
readable-versus-compact generation, repair, and action/completion core.

### Conditions

At minimum, compare:

1. readable A-Lang v2;
2. AST-preserving layout-minified A-Lang;
3. minified A-Lang with mnemonic keyword aliases;
4. a checked compact projection with reconstructible schema elision;
5. the same projection with opaque user identifiers;
6. the current typed-JSON control.

If learned macros are later studied, they require separate adapted-model and
zero-shot conditions. Results from adapted models cannot justify the universal
surface.

### Tasks and perturbations

Measure both directions:

- model reads a task and emits the normalized task record;
- model generates a task representation from natural language;
- model repairs a deliberately invalid representation from diagnostics;
- model selects legal next actions and completion evidence from the checked
  task.

Cross the surfaces with paraphrase, irrelevant context, prompt injection,
missing information, constraint density, long descriptive names, same-prefix
identifiers, and renamed-but-equivalent identifiers. Include cases where one
negation, one digit, or one scope boundary changes the correct outcome.

### Metrics

Report a Pareto frontier rather than a single compression score:

- actual prompt and completion tokens from provider usage plus local counts
  from every declared tokenizer;
- exact field and semantic-digest fidelity;
- syntax validity and repair-call rate;
- omitted constraints and invented actions;
- unauthorized effects, scope widening, budget widening, and false completion;
- clarification recall for missing information;
- latency and monetary or local-compute cost;
- author and reviewer time, diagnostic accuracy, and name-map mistakes;
- worst-case as well as average performance across perturbations and models.

### Promotion gate

A compact projection should not become a default merely because it parses. A
reasonable preregistered gate is:

- deterministic round trip for every accepted task and generated test case;
- at least 20% median token reduction on each target tokenizer or provider
  usage report;
- no material loss in exact semantic fidelity in either declared model family;
- zero additional unauthorized effects, authority widening, or false
  completion;
- no material increase in repair calls or human diagnostic error;
- benefits survive identifier-renaming and constraint perturbations rather than
  only familiar examples.

The safety clauses are vetoes, not quantities that can be averaged away by
token savings.

## Research priorities

1. Add a read-only token audit that reports per-lexeme and per-section cost for
   the frozen corpus under every deployed tokenizer.
2. Prototype an AST-preserving layout projector and prove its round trip on all
   current v2 fixtures.
3. Prototype a checked compact projection that compresses closed vocabulary,
   repeated paths, and reconstructible declarations while keeping descriptive
   names.
4. Run the factorial fidelity study before changing the user-facing grammar.
5. Mine frequent IR subtrees only after real A-Lang usage exists; consider
   learned macro tokens only for explicitly adapted model families.

The first four priorities are operationalized by the
[six-phase campaign](../60-planning/03-compact-projection-fidelity/README.md).
They remain planned work until their reproducible completion evidence exists.

The main falsification criterion is straightforward: if the compact projection
does not retain A-Lang's fidelity and safety advantage across models, its token
savings are not worth promoting. In that case, keep readable A-Lang and use
ordinary context selection, caching, and runtime enforcement to control cost.

## Connections

- [Task languages for LLM agents](llm-agent-task-languages-deep-dive.md) — the
  broader design thesis that stable typed semantics and runtime enforcement
  matter more than a universally optimal surface.
- [A-Lang v2 language reference](alang-v2-language-reference.md) — the current
  grammar and explicit-declaration invariants this proposal must preserve.
- [A-Lang implementation reference](alang-implementation-reference.md) — the
  existing parse, check, derive, and BEAM backend pipeline where a projector
  would have to fit.
- [Can a compact projection reduce A-Lang token use without reducing fidelity?](../40-inquiries/can-a-compact-projection-reduce-alang-token-use-without-reducing-fidelity.md)
  — the open empirical question and promotion boundary.
- [Token-efficient A-Lang syntax](../10-maps/token-efficient-alang-syntax.md) —
  a path through the evidence and design options.

## Sources

- [Tokenizer domain adaptation](../30-sources/dagan-et-al-2024-tokenizer-domain-adaptation.md)
- [CodeT5 and identifier semantics](../30-sources/wang-et-al-2021-codet5.md)
- [ReCode robustness evaluation](../30-sources/wang-et-al-2023-recode.md)
- [LLMLingua](../30-sources/jiang-et-al-2023-llmlingua.md)
- [The hidden cost of readability](../30-sources/pan-et-al-2025-hidden-cost-readability.md)
- [Token Sugar](../30-sources/sun-et-al-2025-token-sugar.md)
- [State-in-context agent minification](../30-sources/hrubec-cito-2026-minification.md)
- [Compact constraint encoding](../30-sources/tang-2026-compact-constraint-encoding.md)
- [A token-efficient language for LLMs](../30-sources/rickard-2023-token-efficient-language.md)
