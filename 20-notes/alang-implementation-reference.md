---
title: "A-Lang implementation reference"
kind: note
created: 2026-08-10
maturity: developing
tags:
  - implementation
  - compiler
  - beam
  - runtime
  - ir
aliases: []
---

# A-Lang Implementation Reference

## Purpose

This document provides a complete reference for the A-Lang compiler pipeline,
intermediate representation, runtime kernel, and runtime ABI. It covers the
BEAM-resident implementation from source to executable artifact.

Both trusted compiler passes and accepted A-Lang programs execute as loaded
BEAM modules on ERTS; no host-language evaluator is an A-Lang runtime.

## Compiler Pipeline

The full pipeline from source to BEAM executable:

```
A-Lang v2 Source
    |
    v
alang_fidelity_lexer.erl  -- Tokenizer
    |  (UTF-8 validation, shebang detection, keywords, punctuation,
    |   strings, integers, byte+line+column origins)
    v
alang_fidelity_parser.erl -- Parser
    |  (Produces alang_source_ast_v2 with closed node shapes,
    |   source origins on every node)
    v
alang_fidelity_source.erl -- Source-to-Semantic Decoder
    |  (Translates AST into representation-neutral alang_semantic_input_v2)
    |
    +-- alang_fidelity_control.erl -- Typed JSON Decoder (alternative frontend)
    |       (Parses alang-task-json-v1 into same semantic envelope)
    |
    v
alang_fidelity_semantics.erl -- Semantic Checker
    |  (Resolves identities, proves action graph reachability, types
    |   operations, validates child/completion/path/terminal contracts,
    |   produces alang_checked_semantics_v2)
    v
alang_fidelity_authority.erl -- Authority Deriver
    |  (Infers effects from action graph, derives least requirements from
    |   scopes, computes static bounds, produces alang_derived_semantics_v2)
    v
alang_fidelity_ir.erl -- IR Lowerer
    |  (Lowers checked semantics into alang_typed_task_ir_v2 with deterministic
    |   node IDs, effect ordinals, and preorder numbering; validates closed shapes)
    v
alang_fidelity_forms_v2.erl -- Abstract Format Adapter
    |  (Renders IR into allowed Erlang Abstract Format subset)
    v
alang_fidelity_backend_v2.erl -- Backend Compiler
    |  (Calls compile:forms/2 with strong_validation, compiles deterministically,
    |   inspects .beam module with beam_lib, validates exact module/exports/imports)
    v
alang_fidelity_artifact_v2.erl -- Artifact Inspector
    |  (Validates BEAM container: exact module name, exports, imports, chunks,
    |   compiler profile, metadata; binds artifact to compiler evidence)
    v
Loaded .beam module on ERTS  -- Runtime Execution
    |
    v
alang_fidelity_runtime.erl  -- Runtime Supervisor
    |  (Binds metadata to operator resources, broker grants, static counters,
    |   durable workspace state, bounded repair, attenuated children)
    v
alang_fidelity_runtime_abi.erl -- Runtime ABI
    |  (Four fixed calls: begin_task, effect, delegate, complete)
    v
Completion Verification      -- Phase 6 filesystem verifier
    |  (Checks completion predicates, produces alang_fidelity_completion_witness_v1)
```

### Two Frontends Converge

Both `alang-source-v2` (text) and `alang-task-json-v1` (typed JSON) are parsed
independently but converge to the **same** `alang_semantic_input_v2` envelope
before semantic checking. This ensures identical semantics regardless of
source representation.

## Lexer

**Module:** `alang_fidelity_lexer.erl`

The lexer tokenizes `alang-source-v2` with byte and line-column origins. Key
properties:

- UTF-8 validation with bounded input
- Shebang detection (`#!alang-source-v2`)
- Keywords: `task`, `facts`, `input`, `effects`, `requirements`, `scopes`,
  `limits`, `step`, `on-error`, `child`, `complete`, `clarify`, `terminal`,
  `required`, `optional`, `true`, `false`
- Punctuation: `{`, `}`, `[`, `]`, `:`, `;`, `,`, `.`, `=>`
- Identifiers: `[a-zA-Z_][a-zA-Z0-9_-]*` (max 128 bytes)
- Integers: `[0-9]+` (max 19 digits, signed 64-bit)
- String literals: `"..."` with `\"` and `\\` escapes (max 4,096 bytes)
- No source-controlled atoms (all tokens remain binaries)

### Token Types

```erlang
type token() ::
    {shebang, binary()} |
    {identifier, binary(), {pos(), pos()}} |
    {integer, integer(), {pos(), pos()}} |
    {string, binary(), {pos(), pos()}} |
    {keyword, binary(), {pos(), pos()}} |
    {punctuation, binary(), {pos(), pos()}} |
    {eof, {pos(), pos()}}.
```

### Origin Tracking

Every token carries its source position as `{Line, Column}` where `Line` is
1-indexed and `Column` is byte offset within the line. Origins are preserved
through the parser into the AST and ultimately into the semantic input.

## Parser

**Module:** `alang_fidelity_parser.erl`

The parser produces `alang_source_ast_v2` with closed node shapes. Key
properties:

- Deterministic error reporting with source origins
- No backtracking (predictive parsing)
- Closed node shapes (no dynamic fields)
- Source origins on every node (for diagnostics)

### AST Node Types

```erlang
-type document() :: #{
    shebang => binary(),
    task => task_node()
}.

-type task_node() :: #{
    module := task,
    name := binary(),
    body := task_body_node()
}.

-type task_body_node() :: #{
    facts := [string_node()],
    inputs := [input_node()],
    effects := [operation_node()],
    requirements := [requirement_node()],
    scopes := scopes_node(),
    limits := limits_node(),
    steps := [step_node()],
    on_error := [error_handler_node()],
    child := child_node() | none,
    complete := [predicate_node()],
    clarify := [string_node()],
    terminal := terminal_node()
}.
```

### Error Reporting

Parse errors include:
- Error reason (atom)
- Source origin `{Line, Column}`
- Expected tokens
- Recovered AST fragment (when possible)

## Semantic Input

**Module:** `alang_fidelity_source.erl`

Translates AST into representation-neutral `alang_semantic_input_v2`. This
envelope is the same regardless of whether the source was A-Lang text or
typed JSON.

### Semantic Envelope Structure

```erlang
-type semantic_input() :: #{
    format := alang_semantic_input_v2,
    case_id => binary(),           % from corpus metadata
    task_id => binary(),           % computed: task:<case_id>/<input_count>
    goal_facts => [binary()],
    inputs => [input_descriptor()],
    actions => [action_descriptor()],
    effects => [binary()],         % sorted, unique
    requirements => [requirement_descriptor()],
    scopes => scopes_descriptor(),
    budgets => budgets_descriptor(),
    error_branches => [error_branch_descriptor()],
    child_attenuation => child_attenuation_descriptor() | none,
    completion_predicates => [completion_predicate_descriptor()],
    clarification_needs => [binary()],
    terminal_class => terminal_class(),
    source_digest => binary(),     % SHA-256 of raw source bytes
    semantic_digest => binary()    % SHA-256 of normalized semantic task
}.

-type input_descriptor() :: #{
    name => binary(),
    type := text | json | path | model_profile,
    required := boolean()
}.

-type action_descriptor() :: #{
    id => binary(),
    operation := model_generate | model_repair | workspace_write | complete,
    depends_on => [binary()]
}.

-type requirement_descriptor() :: #{
    kind := model | workspace,
    resource => binary()
}.

-type scopes_descriptor() :: #{
    models => [binary()],
    workspaces => [binary()],
    paths => [binary()]
}.

-type budgets_descriptor() :: #{
    steps => non_neg_integer(),
    model_calls => non_neg_integer(),
    repair_calls => non_neg_integer(),
    child_calls => non_neg_integer(),
    workspace_writes => non_neg_integer(),
    output_bytes => non_neg_integer(),
    timeout_ms => non_neg_integer()
}.
```

### Semantic Digest

The semantic digest is computed as:

```erlang
semantic_digest(#{case_id := CaseId, inputs := Inputs, ...}) ->
    Normalized = normalize_semantic(#{case_id := CaseId, inputs := Inputs, ...}),
    crypto:hash(sha256, normalize_to_canonical_binary(Normalized)).
```

The normalization removes:
- Source-specific origins (line/column numbers)
- Representation-specific metadata (shebang, corpus-case comment)
- Set presentation (orders maps by key, sorts lists by element)

This ensures that semantically equivalent tasks (e.g., A-Lang vs JSON) produce
the same digest.

## Semantic Checker

**Module:** `alang_fidelity_semantics.erl`

Resolves identities, proves action graph reachability, types operations, and
validates contracts. Key checks:

1. **Identity resolution** — all step references resolve to declared steps
2. **Action graph reachability** — every action transitively reaches `complete`
3. **Operation typing** — operations match declared effects
4. **Child attenuation** — child limits ≤ parent limits, no recursion
5. **Path safety** — all paths start with `/workspace/`, no `..` or `.`
6. **Completion predicates** — references resolve to declared steps/paths
7. **Terminal consistency** — `complete` requires empty `clarify`,
   `needs-clarification` requires non-empty `clarify`

### Checked Semantics Structure

```erlang
-type checked_semantics() :: #{
    format := alang_checked_semantics_v2,
    task_id => binary(),
    goal_facts => [binary()],
    inputs => [input_descriptor()],
    actions => [action_descriptor()],
    effects => [binary()],
    requirements => [requirement_descriptor()],
    scopes => scopes_descriptor(),
    budgets => budgets_descriptor(),
    error_branches => [error_branch_descriptor()],
    child_attenuation => child_attenuation_descriptor() | none,
    completion_predicates => [completion_predicate_descriptor()],
    clarification_needs => [binary()],
    terminal_class := terminal_class(),
    action_graph := acyclic_dag(),
    resolved_ids => map(),
    semantic_digest => binary()
}.
```

## Authority Deriver

**Module:** `alang_fidelity_authority.erl`

Infers effects from action graph, derives least requirements from scopes, and
computes static bounds. Key functions:

- `infer_effects(Actions) -> [binary()]` — collects unique operations
- `derive_requirements(Scopes) -> [requirement_descriptor()]` — extracts unique
  resource kinds and names
- `compute_static_bounds(Budgets) -> map()` — validates budget constraints

### Effect Inference

```erlang
infer_effects(Actions) ->
    Operations = [action_operation(Action) || Action <- Actions],
    Effects = lists:usort(Operations),
    %% repair implies generate
    lists:usort(Effects ++ case lists:member(model_repair, Operations) of
        true -> [model_generate];
        false -> []
    end).
```

### Requirement Derivation

```erlang
derive_requirements(Scopes) ->
    Models = maps:get(models, Scopes),
    Workspaces = maps:get(workspaces, Scopes),
    [{model, M} || M <- lists:usort(Models)] ++
    [{workspace, W} || W <- lists:usort(Workspaces)].
```

## Intermediate Representation

**Module:** `alang_fidelity_ir.erl`

Lowers checked semantics into `alang_typed_task_ir_v2`. Key properties:

- Deterministic node IDs (preorder numbering)
- Effect ordinals (contiguous integers)
- Closed node shapes
- Source maps preserved separately

### IR Structure

```erlang
-type typed_ir() :: #{
    format := alang_typed_task_ir_v2,
    module => binary(),                    % case_id as binary
    semantic_digest => binary(),            % 64 hex chars
    manifest => runtime_manifest(),
    tasks => [task_descriptor()],           % exactly one task
    nodes => [node_descriptor()]            % 1-16 nodes, preorder
}.

-type task_descriptor() :: #{
    id => binary(),
    parameters => [input_descriptor()],
    result_type := terminal,
    body_root => node_id(),                 % final complete node
    limits => budgets_descriptor(),
    static_bounds => map(),
    manifest => runtime_manifest(),
    child => child_descriptor() | none,
    completion => completion_descriptor(),
    error_branches => [error_branch_descriptor()],
    terminal_class := terminal_class()
}.

-type node_descriptor() :: #{
    id => node_id(),                        % deterministic preorder
    action_id => binary(),
    kind := complete | effect_request | delegate,
    type := terminal | binary | unit,
    operation := model_generate | model_repair | workspace_write | child_run,
    dependencies => [node_id()],            % prior nodes only
    effect_ordinal => integer,              % contiguous
    child => child_descriptor()             % only for delegate
}.
```

### Node Kinds

- `complete` — the terminal node (always last, exactly one)
- `effect_request` — any non-complete, non-delegate operation
- `delegate` — child.run (carries a child descriptor)

### Preorder Numbering

Nodes are numbered in preorder traversal of the action DAG. This ensures:
- Deterministic ordering
- Dependencies always have lower IDs
- The complete node always has the highest ID

```erlang
number_nodes(#{actions := Actions, body_root := RootId}) ->
    Preorder = preorder_traversal(Actions, RootId),
    lists:zipwith(fun(Node, Index) ->
        Node#{id => list_to_binary(io_lib:format("node:~4..0B", [Index]))}
    end, Preorder, lists:seq(0, length(Preorder) - 1)).
```

### Effect Ordinals

Effects are assigned contiguous integers starting from 0. The ordinal is
stable across runs and enables compact encoding in the runtime ABI.

```erlang
assign_effect_ordinals(Effects) ->
    lists:zipwith(fun(Eff, Index) -> {Eff, Index} end, Effects, lists:seq(0, length(Effects) - 1)).
```

## Abstract Format Adapter

**Module:** `alang_fidelity_forms_v2.erl`

Renders IR into allowed Erlang Abstract Format subset. Key properties:

- Allows only a small subset of Erlang syntax
- No maps, records, or funs in generated code
- No string-as-operations (no dynamic module/function calls)
- No unsafe BIFs (no `erlang:apply`, `erlang:eval`, etc.)

### Allowed Abstract Format Constructs

- Atoms (from closed set)
- Tuples (from closed set)
- Lists (finite, bounded)
- Integers (signed 64-bit)
- Binary literals (from closed set)
- Function clauses (allowlisted)
- Pattern matching (allowlisted)

### Forbidden Constructs

- Maps
- Records
- Funs
- Try/catch
- Comprehensions
- String interpolation
- Dynamic function calls
- Unsafe BIFs

## Backend Compiler

**Module:** `alang_fidelity_backend_v2.erl`

Calls `compile:forms/2` with `strong_validation` and deterministic output. Key
properties:

- Uses pinned OTP 29 compiler
- `strong_validation` enabled (rejects undefined functions, bad imports, etc.)
- Deterministic binary output (no timestamps, no random IDs)
- Inspects resulting `.beam` module with `beam_lib`

### Compilation Flow

```erlang
compile_ir(IR) ->
    Forms = forms_v2:render(IR),
    {ok, Module, Warnings} = compile:forms(Forms, [
        strong_validation,
        {outdir, <<"/dev/null">>},
        {report_errors, false}
    ]),
    %% Validate the compiled module
    validate_module(Module, IR),
    {ok, Module}.
```

## Artifact Inspector

**Module:** `alang_fidelity_artifact_v2.erl`

Validates the BEAM container. Key checks:

1. **Module name** — must be `alang_fidelity_program_v2` (or case-specific)
2. **Exports** — must match allowlisted functions
3. **Imports** — must match allowlisted modules
4. **Chunks** — must be from allowlisted set
5. **Compiler profile** — must match pinned OTP version
6. **Metadata** — must contain semantic digest and version

### Artifact Validation

```erlang
validate_module(Module, IR) ->
    {ok, {Module, [Code]}} = beam_lib:chunks(Module, [
        attributes, exports, imports, code
    ]),
    %% Check module name
    ensure(maps:get(module, attributes), ?EXPECTED_MODULE),
    %% Check exports
    ensure(exports, ?ALLOWED_EXPORTS),
    %% Check imports
    ensure(imprts, ?ALLOWED_IMPORTS),
    ok.
```

## Runtime Kernel

**Module:** `alang_fidelity_runtime.erl`

Binds inspected artifact metadata to operator resources, broker grants, static
counters, durable workspace state, bounded repair, and attenuated children. Key
properties:

- Supervised BEAM process execution
- Closed runtime ABI (four fixed calls)
- Opaque capability grants
- Deterministic effect accounting
- Durable journaling

### Runtime Supervision Tree

```
session_supervisor
  ├─ task_coordinator (gen_server)
  │   ├─ model_adapter (port/sidecar)
  │   ├─ workspace_adapter (port/sidecar)
  │   └─ child_supervisor (one_for_one)
  │       └─ child_task (gen_server)
  └─ journal_adapter (gen_server)
```

### Runtime Context

The runtime context contains only safe information:

```erlang
-type runtime_context() :: #{
    format := runtime,
    binding_digest => binary(),
    task_id => binary(),
    step_id => binary(),
    effect_ordinal => integer(),
    deadline_ms => non_neg_integer()
}.
```

No secrets, credentials, or capabilities are exposed to the task process.

## Runtime ABI

**Module:** `alang_fidelity_runtime_abi.erl`

Exposes four fixed calls to generated BEAM code. All calls are routed through
`gen_server:call/3` with 15-second timeout.

### ABI Specification

```erlang
%% Begin a task with the given inputs
-spec begin_task(runtime_context(), binary(), list()) ->
    {ok, reference()} | {error, term()}.

%% Request an effect (model.generate, workspace.write)
-spec effect(runtime_context(), reference(), integer(), binary(),
             binary(), list()) -> {ok, term()} | {error, term()}.

%% Delegate to a child task
-spec delegate(runtime_context(), reference(), integer(), binary(),
               binary(), list()) -> {ok, term()} | {error, term()}.

%% Complete the task with the given completion witness
-spec complete(runtime_context(), reference(), binary(), map(), binary()) ->
    {ok, map()} | {error, term()}.
```

### Effect Request

The `effect/6` call requests an operation. The runtime:

1. Validates the effect ordinal against the task's declared effects
2. Checks the step's dependency graph
3. Enforces the effect budget
4. Invokes the appropriate adapter (model, workspace)
5. Records the effect in the journal
6. Returns the result or error

```erlang
effect(Context, Token, Ordinal, ActionId, Operation, Dependencies) ->
    %% Validate ordinal
    ensure(ordinal_in_range(Ordinal, Context), invalid_ordinal),
    %% Check dependencies
    ensure(dependencies_met(Dependencies, Context), unmet_dependencies),
    %% Enforce budget
    ensure(budget_remaining(effects, Context), budget_exceeded),
    %% Invoke adapter
    Result = invoke_adapter(Operation, Context),
    %% Record in journal
    journal:append(effect, Context, #{operation => Operation, result => Result}),
    %% Update budget
    {ok, update_budget(effects, Context)}.
```

### Child Delegation

The `delegate/6` call spawns a child task with attenuated authority. The child:

1. Inherits parent's scopes (subset)
2. Cannot include `child.run` in effects
3. Has `child-calls` budget of zero
4. Has limits ≤ parent limits

```erlang
delegate(Context, Token, Ordinal, ActionId, Operation, Dependencies) ->
    %% Validate child descriptor
    ChildDesc = maps:get(child, Context),
    ensure(ChildDesc =/= none, no_child_allowed),
    %% Spawn child supervisor
    ChildSup = supervisor:start_child(child_supervisor, [ChildDesc, Context]),
    %% Record delegation
    journal:append(delegate, Context, #{child_sup => ChildSup}),
    {ok, ChildSup}.
```

### Completion Verification

The `complete/5` call triggers verification of completion predicates. The
runtime:

1. Receives the completion witness (map of predicate results)
2. Validates each predicate against the filesystem
3. Records the verification in the journal
4. Returns the final result or error

```erlang
complete(Context, Token, ActionId, Completion, TerminalClass) ->
    %% Verify predicates
    Verified = verify_predicates(Completion, Context),
    %% Check terminal class
    ensure(verified_terminal_class(Verified) =:= TerminalClass,
           terminal_mismatch),
    %% Record completion
    journal:append(complete, Context, #{result => Verified}),
    %% Return final result
    {ok, #{verification => Verified, terminal_class => TerminalClass}}.
```

## Journal

**Module:** `alang_fidelity_journal.erl`

Provides a hash-chained append-only journal for effect accounting and
recovery. Key properties:

- Deterministic hashing (SHA-256)
- Append-only (no modification of past records)
- Hash chain (each record hashes the previous)
- Bounded size (configurable)

### Journal Structure

```erlang
-type journal_record() :: #{
    format := journal_record_v1,
    sequence => non_neg_integer(),
    timestamp => integer(),         % Unix epoch ms
    event := effect | delegate | journal | complete,
    data => map(),
    hash => binary(),               % SHA-256 of this record
    prev_hash => binary()           % SHA-256 of previous record
}.
```

### Hash Chain

```erlang
compute_hash(Record) ->
    Binary = term_to_binary(Record#{hash := undefined, prev_hash := undefined}),
    crypto:hash(sha256, Binary).

append_record(PrevHash, Event, Data, Journal) ->
    Sequence = maps:get(sequence, Journal) + 1,
    Record = #{
        format => journal_record_v1,
        sequence => Sequence,
        timestamp => os:timestamp_ms(),
        event => Event,
        data => Data,
        prev_hash => PrevHash
    },
    Hash = compute_hash(Record),
    Record#{hash := Hash}.
```

## Completion Witness

**Module:** `alang_fidelity_completion_witness.erl`

Produces a content-addressed completion witness. Key properties:

- Deterministic encoding (ETF)
- Bounded size (max 8,192 bytes)
- Content-addressed (SHA-256 digest)

### Witness Structure

```erlang
-type completion_witness() :: #{
    format := completion_witness_v1,
    task_id => binary(),
    step_id => binary(),
    predicates => [predicate_result()],
    verification_hash => binary(),
    witness_hash => binary()
}.

-type predicate_result() :: #{
    kind => binary(),
    target => binary(),
    expected => term(),
    actual => term(),
    passed => boolean()
}.
```

## Constraints and Exclusions

### Runtime-Level

The following are **not supported** in generated BEAM code:

1. **No dynamic code** — no NIF, port, filesystem, network, code-loader,
   process-spawn calls
2. **No unsafe BIFs** — no `erlang:apply`, `erlang:eval`, `erlang:load_module`,
   `erlang:spawn`, etc.
3. **No dynamic module calls** — no `Module:Function/Arity` where Module is
   not in the allowlist
4. **No string-as-operations** — no string interpreted as module/function/atom
5. **No portable authorization** — capabilities are opaque runtime-local grants
6. **No model-authored completion** — completion verified by external verifier

### Resource Bounds

| Limit | Value | Notes |
|---|---|---|
| IR nodes | 1-16 | Including complete step |
| Parameters | 1-16 | Input declarations |
| Steps/actions | 1-16 | Including complete |
| Completion predicates | 1-16 | Verification predicates |
| Effect ordinals | 0-N | Contiguous integers |
| Journal records | Unbounded | Append-only |
| Witness size | 8,192 bytes | Max size |

### BEAM Runtime Constraints

- Generated module always named `alang_fidelity_program_v2`
- Only runtime supervisor may load the compiled artifact
- Fixed allowlist of Erlang BIFs
- All evaluation order is deterministic (left-to-right)
- Effects are requests (not implicit host calls)
- Timeouts record uncertain results without auto-retry

## Connections

- [A-Lang v2 language reference](alang-v2-language-reference.md) — source syntax
- [Effectful source fidelity implementation](../effectful-source-fidelity/README.md) — the experiment implementation
- [Phase 1-8 proof-of-concept](../60-planning/01-minimal-proof-of-concept/README.md) — the original PoC
- [BEAM runtime for a native agent language](beam-runtime-for-native-agent-language.md) — design study
