---
title: "A-Lang v2 language reference"
kind: note
created: 2026-08-10
maturity: developing
tags:
  - language-reference
  - alang-syntax
  - task-language
  - beam
  - implementation
aliases: []
---

# A-Lang v2 Language Reference

## Purpose

This document provides a complete reference for the A-Lang v2 source syntax
(`alang-source-v2`). It covers the grammar, all task clauses, operations,
constraints, and design principles. This is the human-readable surface that
models must comprehend in the effectful source fidelity experiment.

A-Lang is a **task-declared programming language** for bounded LLM agent
execution on the BEAM VM. Programs specify *what work to do* (operations,
dependencies, constraints) rather than *how to compute it*. The runtime
handles execution, authorization, and verification.

## Version History

| Version | Status | Notes |
|---|---|---|
| `alang-source-v1` | Legacy | Minimal arithmetic module syntax; used in PoC phases 1-2 |
| `alang-source-v2` | Current | Rich task-declaration syntax; used in fidelity experiment |

## Complete Source Structure

Every v2 source file begins with a shebang line identifying the version,
followed by optional metadata comments, then a single task declaration:

```alang
#!alang-source-v2
// corpus-case: <case-id>
// semantic-sha256: <sha256-hex>
// model-visible-begin
task <task-name> {
  <task-body>
}
```

The entire source is a **single task declaration** (not a module containing
multiple tasks). The `// model-visible-begin` marker separates corpus metadata
from model-visible source. The semantic SHA-256 digest in the metadata is
independently reproducible from the visible source.

## Grammar

```
document       := shebang task
shebang        := "#!alang-source-v2"
task           := "task" identifier "{" task-body "}"
task-body      := (facts | input | effects | requirements | scopes | limits |
                   step | on-error | child | complete | clarify | terminal)* "}"
facts          := "facts" "[" string-literal ("," string-literal)* "]" ";"
input          := "input" identifier ":" type ("required" | "optional") ";"
effects        := "effects" "[" operation ("," operation)* "]" ";"
requirements   := "requirements" "[" requirement ("," requirement)* "]" ";"
requirement    := ("model" | "workspace") identifier
scopes         := "scopes" "{" scope-models scope-workspaces scope-paths "}" ";"
scope-models   := "models" "[" identifier ("," identifier)* "]" ";"
scope-workspaces := "workspaces" "[" identifier ("," identifier)* "]" ";"
scope-paths    := "paths" "[" path-literal ("," path-literal)* "]" ";"
limits         := "limits" "{" limit-item ("," limit-item)* "}" ";"
limit-item     := limit-keyword integer
limit-keyword  := "steps" | "model-calls" | "repair-calls" | "child-calls" |
                  "workspace-writes" | "output-bytes" | "timeout-ms"
step           := "step" identifier ":" operation "depends" "[" identifier ("," identifier)* "]" ";"
on-error       := "on-error" "[" error-handler ("," error-handler)* "]" ";"
error-handler  := identifier error-reason "=>" terminal-class
error-reason   := "denied" | "invalid-output" | "timeout" | "verification-failed"
terminal-class := "complete" | "failed" | "needs-clarification"
child          := "child" "{" child-body "}" ";" | "child" "none" ";"
child-body     := (child-effects | child-requirements | child-scopes | child-limits)*
child-effects  := "effects" "[" operation ("," operation)* "]" ";"
child-requirements := "requirements" "[" requirement ("," requirement)* "]" ";"
child-scopes   := "scopes" "{" scope-models scope-workspaces scope-paths "}" ";"
child-limits   := "limits" "{" limit-item ("," limit-item)* "}" ";"
complete       := "complete" "[" predicate ("," predicate)* "]" ";"
predicate      := predicate-kind target (":" value | ":=" value)
predicate-kind := "artifact-exists" | "sha256" | "max-bytes" | "utf8" |
                  "markdown-h1" | "journal-succeeded" | "clarification-recorded"
target         := path-literal | identifier
value          := bool-literal | string-literal | integer
clarify        := "clarify" "[" string-literal ("," string-literal)* "]" ";"
terminal       := "terminal" terminal-class ";"
type           := "text" | "json" | "path" | "model-profile"
identifier     := [a-zA-Z_][a-zA-Z0-9_-]*
integer        := [0-9]+
string-literal := "\"" string-content "\""
string-content := (escape-seq | printable-ascii)+
path-literal   := "/" [a-zA-Z0-9_./-]*
bool-literal   := "true" | "false"
operation      := "model.generate" | "model.repair" | "workspace.write" | "complete"
```

## Identifier Rules

- Pattern: `[a-zA-Z_][a-zA-Z0-9_-]*`
- Maximum length: 128 bytes
- Hyphens allowed (unlike Erlang)
- All identifiers remain **binaries** at runtime, never entering the VM atom table
- No source-controlled atoms

## Types

The input types are closed:

| Type | Runtime Representation | Example |
|---|---|---|
| `text` | binary | `input brief: text required;` |
| `json` | binary (parsed to map) | `input change-set: json required;` |
| `path` | binary | `input output-path: path required;` |
| `model-profile` | binary | `input writer: model-profile required;` |

Each input is either `required` or `optional`.

## Operations

The operations form a closed set of four. They appear in `effects`, `step`
declarations, and as node kinds in the typed IR:

| Operation | Description | Effect Inferred |
|---|---|---|
| `model.generate` | Invoke LLM to produce text | `model.generate` |
| `model.repair` | Invoke LLM to repair/fix output | `model.generate` (repair implies generate) |
| `workspace.write` | Write a file to the workspace | `workspace.write` |
| `complete` | Terminate the task (exactly one, must be last) | (none) |

### Effect Inference

The `effects` declaration must exactly match the operations inferred from the
action graph:

```erlang
operation_effect(<<"model.generate">>) -> [<<"model.generate">>];
operation_effect(<<"model.repair">>) -> [<<"model.generate">>];
operation_effect(<<"workspace.write">>) -> [<<"workspace.write">>];
operation_effect(<<"child.run">>) -> [<<"child.run">>];
operation_effect(<<"complete">>) -> [].
```

Only three unique effects exist: `model.generate`, `workspace.write`,
`child.run`.

## Task Clauses in Detail

### `facts`

A non-empty list of string literals describing the task's purpose. These are
model-visible and influence comprehension:

```alang
facts [
  "Create a concise release note",
  "Do not invent changes"
];
```

### `input`

Declares typed input parameters. The runtime supplies these values at task
start:

```alang
input brief: text required;
input change-set: json required;
input output-path: path optional;
```

### `effects`

Declares which operations the task may perform. The order matters (the parser
enforces a specific ordering):

```alang
effects [child.run, model.generate, workspace.write];
```

The declared effects must exactly match the operations inferred from the action
graph. Unknown effects are rejected at parse time.

### `requirements`

Declares the least authority (resources) the runtime must grant. Two resource
kinds exist:

```alang
requirements [model child-writer, workspace parent-workspace];
```

- `model` — a named model resource (e.g., `"child-writer"`)
- `workspace` — a named workspace resource (e.g., `"parent-workspace"`)

### `scopes`

Binds resource authorizations to specific models, workspaces, and paths. All
three fields are required:

```alang
scopes {
  models [child-writer];
  workspaces [parent-workspace];
  paths ["/workspace/delegated-brief.md"];
};
```

**Path constraints:**
- Must start with `/workspace/`
- Cannot contain `..`, `.`, or null bytes
- Must be a valid POSIX path under the workspace root

The runtime broker issues opaque grants based on this information. Source-
controlled names never enter the VM atom table.

### `limits`

Seven bounded counters, all required and all non-negative integers:

```alang
limits {
  steps 4;                    // total IR nodes (1-16)
  model-calls 2;              // model.generate + model.repair calls
  repair-calls 0;             // model.repair calls only
  child-calls 1;              // child.run calls
  workspace-writes 1;         // workspace.write calls
  output-bytes 2048;          // max output size
  timeout-ms 45000;           // deadline in milliseconds
};
```

**Constraint:** `model-calls >= repair-calls` and `steps >= 1`.

### `step` (Actions)

Ordered, named actions forming a directed acyclic graph (DAG). Each step
depends on zero or more prior steps by name:

```alang
step frame: model.generate depends [];
step delegate: child.run depends [frame];
step publish: workspace.write depends [delegate];
step finish: complete depends [publish];
```

**Constraints:**
- Every action must transitively reach the final `complete` step
- The `complete` step must be last in declaration order
- Dependencies must refer to earlier steps (no forward references)
- Maximum 16 steps per task

### `on-error`

Maps `(action, reason) => terminal_class` pairs. The task may declare up to
one handler per action:

```alang
on-error [
  repair invalid-output => failed,
  publish denied => failed
];
```

**Error reasons** (closed set):
- `denied` — authorization failure
- `invalid-output` — model produced malformed output
- `timeout` — step exceeded time limit
- `verification-failed` — completion predicate failed

**Terminal classes:**
- `complete` — task succeeded
- `failed` — task failed permanently
- `needs-clarification` — task needs more information

**Constraints:**
- `needs-clarification` requires non-empty `clarify` clause
- `complete` requires empty `clarify` clause
- Handlers are advisory; the runtime may override based on severity

### `child`

Declares whether the task may spawn a child task. Two forms:

**No child:**
```alang
child none;
```

**With attenuated child:**
```alang
child {
  effects [model.generate];
  requirements [model child-writer];
  scopes {
    models [child-writer];
    workspaces [];
    paths [];
  };
  limits {
    steps 2;
    model-calls 1;
    repair-calls 0;
    child-calls 0;
    workspace-writes 0;
    output-bytes 2048;
    timeout-ms 30000;
  };
};
```

**Child attenuation constraints:**
- Child effects cannot include `child.run` (no recursion)
- Child's `child-calls` budget must be zero
- Child limits must be ≤ parent limits (element-wise)
- Child scopes must be subsets of parent scopes
- Child cannot access parent's workspace paths not declared in child scopes

### `complete` (Completion Predicates)

Non-empty list of verification predicates checked by the Phase 6 filesystem
verifier. The model cannot claim completion; it must be verified:

```alang
complete [
  artifact-exists "/workspace/delegated-brief.md": true,
  utf8 "/workspace/delegated-brief.md": true,
  max-bytes "/workspace/delegated-brief.md": 2048,
  journal-succeeded "publish": true
];
```

**Seven predicate kinds:**

| Predicate | Target Type | Expected Type | Example |
|---|---|---|---|
| `artifact-exists` | path | bool | `artifact-exists "/path": true` |
| `sha256` | path | string (hex) | `sha256 "/path": "abc123..."` |
| `max-bytes` | path | int | `max-bytes "/path": 2048` |
| `utf8` | path | bool | `utf8 "/path": true` |
| `markdown-h1` | path | string | `markdown-h1 "/path": "# Release"` |
| `journal-succeeded` | step name | bool | `journal-succeeded "publish": true` |
| `clarification-recorded` | (none) | bool | `clarification-recorded: true` |

**Constraints:**
- Maximum 16 predicates per task
- Each predicate must reference a step or path declared earlier in the task
- `journal-succeeded` references a step name (string)
- `clarification-recorded` has no target (bool only)

### `clarify`

A list of strings describing what information is needed when the task cannot
complete autonomously. Used with `needs-clarification` terminal class:

```alang
clarify [
  "Need the incident record",
  "Confirm the output path"
];
```

**Constraints:**
- Empty list when terminal class is `complete`
- Non-empty list when terminal class is `needs-clarification`
- Strings are model-visible and influence clarification behavior

### `terminal`

The expected terminal class of the task. Must match the actual outcome or the
task is considered failed:

```alang
terminal complete;
terminal failed;
terminal needs-clarification;
```

**Constraints:**
- `needs-clarification` requires non-empty `clarify`
- `complete` requires empty `clarify`
- `failed` has no additional constraints

## Comments and Metadata

Comments use `//` line comments:

```alang
// corpus-case: ad-simple
// semantic-sha256: fc3463e8963f4710cda9c4004f2d484f3ae0e5941429042697fd952102d18857
// model-visible-begin
```

**Metadata fields:**
- `corpus-case` — identifies the corpus cell (for testing)
- `semantic-sha256` — SHA-256 of the semantic task (independently reproducible)
- `model-visible-begin` — marks the start of model-visible source

The semantic SHA-256 digest is computed from the normalized semantic task
after representation-specific origins are removed. It is used to verify that
the source and its semantic representation are consistent.

## Constraints and Exclusions

### Language-Level

The following are **not supported** in v2:

1. **No modules** — single task per file
2. **No expressions** — task-oriented, not expression-based
3. **No string interpolation** — forbidden
4. **No dynamic calls** — only allowlisted operations
5. **No recursion** — child tasks cannot spawn children
6. **No polymorphism** — types are closed
7. **No parallel composition** — steps are ordered (DAG)
8. **No portable authorization** — effects are declarations, not credentials
9. **No source-controlled atoms** — all identifiers remain binaries
10. **No unsafe paths** — must start with `/workspace/`, no `..` or `.`

### Resource Bounds

| Limit | Value | Notes |
|---|---|---|
| Source bytes | 1 MiB | Hard limit |
| Document bytes | 8,192 | After shebang and metadata |
| Token count | 4,096 | Estimated for LLM context |
| Identifier bytes | 128 | Max length |
| String literal bytes | 4,096 | Max length |
| Integer digits | 19 | Signed 64-bit |
| IR nodes | 1-16 | Includes complete step |
| Parameters | 1-16 | Input declarations |
| Steps/actions | 1-16 | Including complete |
| Completion predicates | 1-16 | Verification predicates |
| Child limit | `child-calls = 0` | No recursion |

### BEAM Runtime Constraints

- Generated module always named `alang_fidelity_program_v2`
- Only runtime supervisor may load the compiled artifact
- Fixed allowlist of Erlang BIFs; no `fun`, `try/catch`, comprehensions,
  maps, or records in Abstract Format
- All evaluation order is deterministic (left-to-right)
- Effects are requests (not implicit host calls); timeouts record uncertain
  results without auto-retry

## Example Tasks

### Simple Artifact Task

```alang
#!alang-source-v2
task simple-artifact {
  facts ["Create a concise release note from the change summary"];
  input change-summary: text required;
  effects [model.generate, workspace.write];
  requirements [model writer, workspace output];
  scopes {
    models [writer];
    workspaces [output];
    paths ["/workspace/release-note.md"];
  };
  limits {
    steps 2;
    model-calls 1;
    repair-calls 0;
    child-calls 0;
    workspace-writes 1;
    output-bytes 2048;
    timeout-ms 30000;
  };
  step draft: model.generate depends [];
  step publish: workspace.write depends [draft];
  step finish: complete depends [publish];
  on-error [];
  child none;
  complete [
    artifact-exists "/workspace/release-note.md": true,
    utf8 "/workspace/release-note.md": true,
    max-bytes "/workspace/release-note.md": 2048
  ];
  clarify [];
  terminal complete;
}
```

### Repair Task

```alang
#!alang-source-v2
task repair-task {
  facts ["Generate a release note and repair if malformed"];
  input change-summary: text required;
  effects [model.generate, workspace.write];
  requirements [model writer, workspace output];
  scopes {
    models [writer];
    workspaces [output];
    paths ["/workspace/release-note.md"];
  };
  limits {
    steps 3;
    model-calls 2;
    repair-calls 1;
    child-calls 0;
    workspace-writes 1;
    output-bytes 2048;
    timeout-ms 45000;
  };
  step draft: model.generate depends [];
  step repair: model.repair depends [draft];
  step publish: workspace.write depends [repair];
  step finish: complete depends [publish];
  on-error [repair invalid-output => failed];
  child none;
  complete [
    artifact-exists "/workspace/release-note.md": true,
    utf8 "/workspace/release-note.md": true
  ];
  clarify [];
  terminal complete;
}
```

### Attenuated Delegation Task

```alang
#!alang-source-v2
task delegation-task {
  facts ["Delegate drafting to a child, then publish the result"];
  input brief: text required;
  effects [child.run, model.generate, workspace.write];
  requirements [model child-writer, workspace parent-workspace];
  scopes {
    models [child-writer];
    workspaces [parent-workspace];
    paths ["/workspace/delegated-brief.md"];
  };
  limits {
    steps 4;
    model-calls 2;
    repair-calls 0;
    child-calls 1;
    workspace-writes 1;
    output-bytes 2048;
    timeout-ms 45000;
  };
  step frame: model.generate depends [];
  step delegate: child.run depends [frame];
  step publish: workspace.write depends [delegate];
  step finish: complete depends [publish];
  on-error [];
  child {
    effects [model.generate];
    requirements [model child-writer];
    scopes {
      models [child-writer];
      workspaces [];
      paths [];
    };
    limits {
      steps 2;
      model-calls 1;
      repair-calls 0;
      child-calls 0;
      workspace-writes 0;
      output-bytes 2048;
      timeout-ms 30000;
    };
  };
  complete [
    artifact-exists "/workspace/delegated-brief.md": true,
    journal-succeeded "publish": true
  ];
  clarify [];
  terminal complete;
}
```

## Design Principles

1. **Everything is declared, nothing is inferred at runtime** — effects,
   requirements, scopes, limits, and completion predicates are all explicit
   in source

2. **Deterministic by construction** — content-addressed digests at every
   level (source, semantic, IR, artifact); deterministic ETF encoding;
   ordered/normalized data structures

3. **Fail-closed** — unsupported versions, unknown effects, out-of-scope
   paths, and unverified completions are all rejected

4. **BEAM-native end-to-end** — entire compiler pipeline executes as BEAM
   modules on ERTS; no host-language evaluator

5. **Model as effect, not as logic** — the LLM is invoked as an
   `effect_request` node in the IR, not as the program's reasoning engine

6. **Capability security** — requirements and scopes form the capability
   system; the runtime broker issues opaque grants based on declared needs

7. **Attenuated delegation** — children are restricted copies of parents;
   no recursion, no widening of authority

8. **Independent verification** — completion is verified by an external
   filesystem verifier; the model cannot claim completion

## Connections

- [A-Lang v1 language surface](../src/phase-02/language-surface.md) — legacy syntax
- [A-Lang implementation reference](alang-implementation-reference.md) — compiler pipeline
- [Effectful source fidelity experiment](../60-planning/02-effectful-source-fidelity/README.md) — the experiment this syntax supports
- [Task languages for LLM agents: a deep dive](llm-agent-task-languages-deep-dive.md) — research motivation
