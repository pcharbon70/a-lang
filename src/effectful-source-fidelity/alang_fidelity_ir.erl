-module(alang_fidelity_ir).

-export([decode/1, digest/1, encode/1, lower/1, validate/1]).

-define(MAX_IR_BYTES, 1048576).

-spec lower(map()) -> {ok, map()} | {error, [map()]}.
lower(#{
    format := alang_derived_semantics_v2,
    checked := Checked,
    manifest := Manifest,
    task_limits := Limits,
    static_bounds := Bounds,
    child := Child
}) ->
    TaskId = maps:get(task_id, Checked),
    {Nodes, _NextSite} = lower_nodes(
        maps:get(actions, Checked), TaskId, Child, 0, 0, #{}
    ),
    BodyRoot = maps:get(id, lists:last(Nodes)),
    Task = #{
        id => TaskId,
        parameters => maps:get(inputs, Checked),
        result_type => terminal,
        body_root => BodyRoot,
        limits => Limits,
        static_bounds => Bounds,
        manifest => Manifest,
        child => Child,
        completion => maps:get(completion, Checked),
        error_branches => maps:get(error_branches, Checked),
        terminal_class => maps:get(terminal_class, Checked)
    },
    Ir = #{
        format => alang_typed_task_ir_v2,
        module => maps:get(case_id, Checked),
        semantic_digest => maps:get(semantic_digest, Checked),
        manifest => Manifest,
        tasks => [Task],
        nodes => Nodes
    },
    case validate(Ir) of
        ok ->
            {ok, IrDigest} = digest(Ir),
            {ok, #{
                format => alang_lowered_program_v2,
                ir => Ir,
                ir_digest => IrDigest,
                semantic_digest => maps:get(semantic_digest, Checked),
                frontend => maps:get(frontend, Checked),
                source_digest => maps:get(source_digest, Checked),
                source_map => maps:get(source_map, Checked),
                provenance => #{
                    format => alang_lowering_provenance_v1,
                    frontend => maps:get(frontend, Checked),
                    input_format => frontend_format(maps:get(frontend, Checked)),
                    source_digest => maps:get(source_digest, Checked),
                    semantic_digest => maps:get(semantic_digest, Checked),
                    ir_digest => IrDigest
                }
            }};
        {error, _} = Error -> Error
    end;
lower(_) ->
    {error, [diagnostic(invalid_derived_semantics,
        <<"expected alang_derived_semantics_v2">>)]}.

lower_nodes([], _TaskId, _Child, _Index, Site, _Ids) -> {[], Site};
lower_nodes([Action | Rest], TaskId, Child, Index, Site, Ids) ->
    Id = node_id(TaskId, Index),
    Dependencies = [maps:get(Dependency, Ids) || Dependency <-
        maps:get(depends_on, Action)],
    Operation = maps:get(operation, Action),
    {Node, NextSite} = lower_node(Action, Operation, Id, Dependencies,
        Child, Site),
    {Tail, FinalSite} = lower_nodes(Rest, TaskId, Child, Index + 1,
        NextSite, Ids#{maps:get(id, Action) => Id}),
    {[Node | Tail], FinalSite}.

lower_node(Action, <<"complete">>, Id, Dependencies, _Child, Site) ->
    {#{
        id => Id,
        action_id => maps:get(id, Action),
        kind => complete,
        type => terminal,
        dependencies => Dependencies
    }, Site};
lower_node(Action, <<"child.run">> = Operation, Id, Dependencies, Child, Site) ->
    {#{
        id => Id,
        action_id => maps:get(id, Action),
        kind => delegate,
        type => maps:get(result_type, Action),
        operation => Operation,
        runtime_operation => runtime_operation(Operation),
        dependencies => Dependencies,
        effect_ordinal => Site,
        child => Child
    }, Site + 1};
lower_node(Action, Operation, Id, Dependencies, _Child, Site) ->
    {#{
        id => Id,
        action_id => maps:get(id, Action),
        kind => effect_request,
        type => maps:get(result_type, Action),
        operation => Operation,
        runtime_operation => runtime_operation(Operation),
        dependencies => Dependencies,
        effect_ordinal => Site
    }, Site + 1}.

-spec validate(term()) -> ok | {error, [map()]}.
validate(Ir) ->
    try
        validate_ir(Ir),
        ok
    catch
        throw:{ir_error, Diagnostic} -> {error, [Diagnostic]};
        _Class:_Reason ->
            {error, [diagnostic(invalid_ir_shape,
                <<"invalid alang_typed_task_ir_v2 shape">>)]}
    end.

validate_ir(Ir) ->
    exact_map(Ir, [format, module, semantic_digest, manifest, tasks, nodes]),
    require(maps:get(format, Ir) =:= alang_typed_task_ir_v2,
        unsupported_ir_version, <<"expected alang_typed_task_ir_v2">>),
    require(valid_identifier(maps:get(module, Ir)), invalid_module_identity,
        <<"IR module identity is invalid">>),
    require(valid_digest(maps:get(semantic_digest, Ir)),
        invalid_semantic_digest, <<"semantic digest must be lowercase SHA-256">>),
    Manifest = maps:get(manifest, Ir),
    validate_manifest(Manifest),
    case maps:get(tasks, Ir) of
        [Task] -> validate_task_and_nodes(Task, maps:get(nodes, Ir), Manifest);
        _ -> fail(invalid_task_count, <<"v2 fidelity IR contains exactly one task">>)
    end.

validate_manifest(Manifest) ->
    exact_map(Manifest, [format, effects, requirements, resources, operations]),
    require(maps:get(format, Manifest) =:= alang_runtime_manifest_v2,
        invalid_manifest_version, <<"expected alang_runtime_manifest_v2">>),
    Effects = maps:get(effects, Manifest),
    require(is_list(Effects) andalso Effects =:= lists:usort(Effects) andalso
        lists:all(fun allowed_effect/1, Effects), invalid_manifest_effects,
        <<"manifest effects must be a sorted closed set">>),
    Requirements = maps:get(requirements, Manifest),
    require(is_list(Requirements) andalso Requirements =:= sort_maps(Requirements),
        invalid_manifest_requirements,
        <<"manifest requirements must be a sorted closed set">>),
    lists:foreach(fun validate_requirement/1, Requirements),
    Resources = maps:get(resources, Manifest),
    validate_resources(Resources),
    Operations = maps:get(operations, Manifest),
    require(is_list(Operations) andalso Operations =:= sort_operations(Operations),
        invalid_manifest_operations,
        <<"manifest operations must be sorted by semantic operation">>),
    lists:foreach(fun(Operation) ->
        validate_operation_manifest(Operation, Requirements)
    end, Operations).

validate_requirement(Requirement) ->
    exact_map(Requirement, [kind, resource]),
    require(lists:member(maps:get(kind, Requirement), [model, workspace]),
        invalid_requirement_kind, <<"requirement kind is outside the closed set">>),
    require(valid_identifier(maps:get(resource, Requirement)),
        invalid_requirement_resource, <<"requirement resource is invalid">>).

validate_resources(Resources) ->
    exact_map(Resources, [models, workspaces, paths]),
    lists:foreach(fun(Key) ->
        Values = maps:get(Key, Resources),
        require(is_list(Values) andalso Values =:= lists:usort(Values),
            invalid_resource_set, <<"manifest resource selectors must be sorted sets">>)
    end, [models, workspaces, paths]),
    require(lists:all(fun valid_identifier/1, maps:get(models, Resources)),
        invalid_model_resource, <<"model selector is invalid">>),
    require(lists:all(fun valid_identifier/1, maps:get(workspaces, Resources)),
        invalid_workspace_resource, <<"workspace selector is invalid">>),
    require(lists:all(fun safe_workspace_path/1, maps:get(paths, Resources)),
        invalid_path_resource, <<"path selector is unsafe">>).

validate_operation_manifest(Operation, ManifestRequirements) ->
    exact_map(Operation, [semantic_operation, runtime_operation, requirements]),
    Semantic = maps:get(semantic_operation, Operation),
    require(lists:member(Semantic, [<<"model.generate">>, <<"model.repair">>,
        <<"workspace.write">>, <<"child.run">>]),
        unknown_manifest_operation, <<"manifest operation is outside the closed set">>),
    require(maps:get(runtime_operation, Operation) =:= runtime_operation(Semantic),
        runtime_operation_mismatch, <<"runtime operation does not match registry mapping">>),
    Requirements = maps:get(requirements, Operation),
    require(is_list(Requirements) andalso Requirements =:= sort_maps(Requirements),
        invalid_operation_requirements,
        <<"operation requirements must be a sorted set">>),
    lists:foreach(fun(Requirement) ->
        validate_requirement(Requirement),
        require(lists:member(Requirement, ManifestRequirements),
            operation_requirement_outside_manifest,
            <<"operation requirement is absent from the manifest">>)
    end, Requirements).

validate_task_and_nodes(Task, Nodes, Manifest) ->
    exact_map(Task, [id, parameters, result_type, body_root, limits,
        static_bounds, manifest, child, completion, error_branches,
        terminal_class]),
    TaskId = maps:get(id, Task),
    require(is_binary(TaskId) andalso byte_size(TaskId) > 5,
        invalid_task_identity, <<"task identity is invalid">>),
    require(maps:get(result_type, Task) =:= terminal,
        invalid_task_result_type, <<"fidelity task result must be terminal">>),
    require(maps:get(manifest, Task) =:= Manifest,
        task_manifest_mismatch, <<"task and module manifests differ">>),
    validate_parameters(maps:get(parameters, Task)),
    Limits = maps:get(limits, Task),
    Bounds = maps:get(static_bounds, Task),
    validate_limits(Limits),
    validate_limits(Bounds),
    lists:foreach(fun(Key) ->
        require(maps:get(Key, Limits) >= maps:get(Key, Bounds),
            limit_below_static_bound,
            <<"task limit is below its recorded static bound">>)
    end, limit_keys()),
    Child = maps:get(child, Task),
    validate_child(Child, Limits),
    validate_completion(maps:get(completion, Task)),
    validate_error_branches(maps:get(error_branches, Task)),
    require(lists:member(maps:get(terminal_class, Task),
        [<<"complete">>, <<"failed">>, <<"needs-clarification">>]),
        invalid_terminal_class, <<"terminal class is outside the closed set">>),
    validate_nodes(Nodes, TaskId, Task, Manifest, Child).

validate_parameters(Parameters) ->
    require(is_list(Parameters) andalso length(Parameters) =< 16,
        invalid_parameters, <<"task parameters exceed the closed bound">>),
    lists:foreach(fun(Parameter) ->
        exact_map(Parameter, [id, name, type, required]),
        require(is_binary(maps:get(id, Parameter)), invalid_binding_identity,
            <<"parameter binding identity must be binary">>),
        require(valid_identifier(maps:get(name, Parameter)), invalid_parameter_name,
            <<"parameter name is invalid">>),
        require(lists:member(maps:get(type, Parameter),
            [binary, json, path, model_profile]), invalid_parameter_type,
            <<"parameter type is outside the closed set">>),
        require(is_boolean(maps:get(required, Parameter)), invalid_parameter_requiredness,
            <<"parameter requiredness must be boolean">>)
    end, Parameters).

validate_limits(Limits) ->
    exact_map(Limits, limit_keys()),
    lists:foreach(fun(Key) ->
        Value = maps:get(Key, Limits),
        require(is_integer(Value) andalso Value >= limit_minimum(Key),
            invalid_limit, <<"limit is not a bounded nonnegative integer">>)
    end, limit_keys()).

limit_keys() -> [steps, model_calls, repair_calls, child_calls,
    workspace_writes, output_bytes, timeout_ms].

limit_minimum(steps) -> 1;
limit_minimum(output_bytes) -> 1;
limit_minimum(timeout_ms) -> 1;
limit_minimum(_) -> 0.

validate_child(none, _ParentLimits) -> ok;
validate_child(Child, ParentLimits) ->
    exact_map(Child, [format, effects, requirements, resources, limits]),
    require(maps:get(format, Child) =:= alang_child_descriptor_v2,
        invalid_child_version, <<"expected alang_child_descriptor_v2">>),
    Effects = maps:get(effects, Child),
    require(is_list(Effects) andalso Effects =:= lists:usort(Effects) andalso
        not lists:member(<<"child.run">>, Effects), invalid_child_effects,
        <<"child effects must be a sorted nonrecursive set">>),
    lists:foreach(fun allowed_effect_required/1, Effects),
    Requirements = maps:get(requirements, Child),
    require(Requirements =:= sort_maps(Requirements), invalid_child_requirements,
        <<"child requirements must be sorted">>),
    lists:foreach(fun validate_requirement/1, Requirements),
    validate_resources(maps:get(resources, Child)),
    ChildLimits = maps:get(limits, Child),
    validate_limits(ChildLimits),
    lists:foreach(fun(Key) ->
        require(maps:get(Key, ChildLimits) =< maps:get(Key, ParentLimits),
            child_limit_widens_parent,
            <<"child limit exceeds its parent">>)
    end, limit_keys()),
    require(maps:get(child_calls, ChildLimits) =:= 0,
        recursive_child_budget, <<"child call budget must be zero">>).

allowed_effect_required(Effect) ->
    require(allowed_effect(Effect), invalid_child_effects,
        <<"child effect is outside the closed set">>).

validate_completion(Completion) ->
    exact_map(Completion, [predicates, terminal_class]),
    Predicates = maps:get(predicates, Completion),
    require(is_list(Predicates) andalso Predicates =:= sort_maps(Predicates) andalso
        Predicates =/= [], invalid_completion,
        <<"completion predicates must be a nonempty sorted set">>),
    lists:foreach(fun validate_predicate/1, Predicates).

validate_predicate(Predicate) ->
    exact_map(Predicate, [kind, target, expected, expected_type]),
    Kind = maps:get(kind, Predicate),
    require(lists:member(Kind, [<<"artifact-exists">>, <<"sha256">>,
        <<"max-bytes">>, <<"utf8">>, <<"markdown-h1">>,
        <<"journal-succeeded">>, <<"clarification-recorded">>]),
        invalid_completion_predicate, <<"completion predicate is unknown">>),
    require(is_binary(maps:get(target, Predicate)), invalid_completion_target,
        <<"completion target must be binary">>),
    require(lists:member(maps:get(expected_type, Predicate), [bool, binary, int]),
        invalid_completion_type, <<"completion expected type is invalid">>).

validate_error_branches(Branches) ->
    require(is_list(Branches) andalso Branches =:= sort_maps(Branches),
        invalid_error_branches, <<"error branches must be a sorted set">>).

validate_nodes(Nodes, TaskId, Task, Manifest, Child) ->
    require(is_list(Nodes) andalso Nodes =/= [] andalso length(Nodes) =< 16,
        invalid_node_count, <<"IR node count is outside the closed bound">>),
    {Ids, _NextSite} = lists:mapfoldl(fun({Node, Index}, Site) ->
        ExpectedId = node_id(TaskId, Index),
        validate_node(Node, ExpectedId, ids_before(Nodes, Index), Child, Site)
    end, 0, indexed(Nodes)),
    require(length(Ids) =:= length(lists:usort(Ids)), invalid_node_identity,
        <<"IR node identities must be unique">>),
    Last = lists:last(Nodes),
    require(maps:get(kind, Last) =:= complete andalso
        maps:get(body_root, Task) =:= maps:get(id, Last), invalid_body_root,
        <<"task body root must be the final complete node">>),
    require(length([ok || #{kind := complete} <- Nodes]) =:= 1,
        invalid_completion_node_count, <<"IR must contain exactly one complete node">>),
    NodeEffects = lists:usort([Effect || Node <- Nodes,
        Effect <- node_effect(Node)]),
    require(NodeEffects =:= maps:get(effects, Manifest),
        manifest_effect_mismatch, <<"node effects do not match the manifest">>),
    NodeOperations = lists:usort([maps:get(operation, Node) || Node <- Nodes,
        maps:get(kind, Node) =/= complete]),
    ManifestOperations = [maps:get(semantic_operation, Operation) ||
        Operation <- maps:get(operations, Manifest)],
    require(NodeOperations =:= ManifestOperations,
        manifest_operation_mismatch, <<"node operations do not match the manifest">>),
    RecomputedBounds = bounds_from_ir(Nodes, Child,
        maps:get(completion, Task)),
    require(RecomputedBounds =:= maps:get(static_bounds, Task),
        static_bound_mismatch, <<"recorded static bounds do not match the IR">>).

validate_node(Node, ExpectedId, PriorIds, Child, Site) ->
    Kind = maps:get(kind, Node, invalid),
    case Kind of
        complete ->
            exact_map(Node, [id, action_id, kind, type, dependencies]),
            validate_node_common(Node, ExpectedId, PriorIds),
            require(maps:get(type, Node) =:= terminal, invalid_complete_type,
                <<"complete node type must be terminal">>),
            {maps:get(id, Node), Site};
        effect_request ->
            exact_map(Node, [id, action_id, kind, type, operation,
                runtime_operation, dependencies, effect_ordinal]),
            validate_effect_node(Node, ExpectedId, PriorIds, Site),
            {maps:get(id, Node), Site + 1};
        delegate ->
            exact_map(Node, [id, action_id, kind, type, operation,
                runtime_operation, dependencies, effect_ordinal, child]),
            validate_effect_node(Node, ExpectedId, PriorIds, Site),
            require(maps:get(operation, Node) =:= <<"child.run">>,
                invalid_delegate_operation, <<"delegate node must use child.run">>),
            require(maps:get(child, Node) =/= none,
                missing_delegate_descriptor, <<"delegate node requires child descriptor">>),
            require(maps:get(child, Node) =:= Child,
                delegate_descriptor_mismatch,
                <<"delegate node and task child descriptors differ">>),
            {maps:get(id, Node), Site + 1};
        _ -> fail(unknown_node_kind, <<"IR node kind is outside the closed set">>)
    end.

validate_node_common(Node, ExpectedId, PriorIds) ->
    require(maps:get(id, Node) =:= ExpectedId, unstable_node_identity,
        <<"node identity does not match deterministic preorder">>),
    require(valid_identifier(maps:get(action_id, Node)), invalid_action_identity,
        <<"action identity is invalid">>),
    Dependencies = maps:get(dependencies, Node),
    require(is_list(Dependencies) andalso Dependencies =:= lists:usort(Dependencies)
        andalso lists:all(fun(Id) -> lists:member(Id, PriorIds) end, Dependencies),
        dangling_or_nonprior_node_reference,
        <<"node dependencies must be unique prior node identities">>).

validate_effect_node(Node, ExpectedId, PriorIds, Site) ->
    validate_node_common(Node, ExpectedId, PriorIds),
    Operation = maps:get(operation, Node),
    require(lists:member(Operation, [<<"model.generate">>, <<"model.repair">>,
        <<"workspace.write">>, <<"child.run">>]), unknown_ir_operation,
        <<"IR operation is outside the closed registry">>),
    require(maps:get(runtime_operation, Node) =:= runtime_operation(Operation),
        runtime_operation_mismatch, <<"IR runtime operation mapping is invalid">>),
    require(maps:get(effect_ordinal, Node) =:= Site, unstable_effect_ordinal,
        <<"effect ordinals must be contiguous preorder identities">>).

ids_before(Nodes, Index) ->
    [maps:get(id, Node) || Node <- lists:sublist(Nodes, Index)].

bounds_from_ir(Nodes, Child, Completion) ->
    ChildLimits = case Child of
        none -> #{model_calls => 0, repair_calls => 0, workspace_writes => 0};
        _ -> maps:get(limits, Child)
    end,
    #{
        steps => length(Nodes),
        model_calls => count_nodes(Nodes, [<<"model.generate">>, <<"model.repair">>]) +
            maps:get(model_calls, ChildLimits),
        repair_calls => count_nodes(Nodes, [<<"model.repair">>]) +
            maps:get(repair_calls, ChildLimits),
        child_calls => count_nodes(Nodes, [<<"child.run">>]),
        workspace_writes => count_nodes(Nodes, [<<"workspace.write">>]) +
            maps:get(workspace_writes, ChildLimits),
        output_bytes => completion_byte_minimum(Completion),
        timeout_ms => 1
    }.

count_nodes(Nodes, Operations) ->
    length([ok || Node <- Nodes, maps:get(kind, Node) =/= complete,
        lists:member(maps:get(operation, Node), Operations)]).

completion_byte_minimum(#{predicates := Predicates}) ->
    Values = [Expected || #{kind := <<"max-bytes">>, expected := Expected} <- Predicates],
    case Values of [] -> 1; _ -> lists:max(Values) end.

node_effect(#{kind := complete}) -> [];
node_effect(#{operation := <<"model.repair">>}) -> [<<"model.generate">>];
node_effect(#{operation := Operation}) -> [Operation].

-spec encode(map()) -> {ok, binary()} | {error, [map()]}.
encode(Ir) ->
    case validate(Ir) of
        ok -> {ok, term_to_binary({alang_typed_task_ir_v2, Ir}, [deterministic])};
        {error, _} = Error -> Error
    end.

-spec decode(binary()) -> {ok, map()} | {error, [map()]}.
decode(<<131, 80, _/binary>>) ->
    {error, [diagnostic(compressed_ir_etf,
        <<"compressed IR ETF is not accepted">>)]};
decode(Binary) when is_binary(Binary), byte_size(Binary) =< ?MAX_IR_BYTES ->
    try binary_to_term(Binary, [safe, used]) of
        {{alang_typed_task_ir_v2, Ir}, Used} when Used =:= byte_size(Binary) ->
            case validate(Ir) of
                ok ->
                    case term_to_binary({alang_typed_task_ir_v2, Ir}, [deterministic]) of
                        Binary -> {ok, Ir};
                        _ -> {error, [diagnostic(noncanonical_ir_etf,
                            <<"IR ETF is not deterministic canonical encoding">>)]}
                    end;
                {error, _} = Error -> Error
            end;
        {_Term, Used} when Used =/= byte_size(Binary) ->
            {error, [diagnostic(trailing_ir_data,
                <<"IR ETF contains trailing bytes">>)]};
        _ ->
            {error, [diagnostic(invalid_ir_envelope,
                <<"expected alang_typed_task_ir_v2 ETF envelope">>)]}
    catch
        error:badarg ->
            {error, [diagnostic(invalid_ir_etf, <<"invalid or unsafe IR ETF">>)]}
    end;
decode(Binary) when is_binary(Binary) ->
    {error, [diagnostic(ir_too_large, <<"IR ETF exceeds 1 MiB">>)]};
decode(_) ->
    {error, [diagnostic(invalid_ir_etf, <<"IR ETF must be binary">>)]}.

-spec digest(map()) -> {ok, binary()} | {error, [map()]}.
digest(Ir) ->
    case encode(Ir) of
        {ok, Binary} -> {ok, alang_fidelity_json:hex(crypto:hash(sha256, Binary))};
        {error, _} = Error -> Error
    end.

runtime_operation(<<"model.generate">>) -> <<"model.complete">>;
runtime_operation(<<"model.repair">>) -> <<"model.complete">>;
runtime_operation(<<"workspace.write">>) -> <<"workspace.write">>;
runtime_operation(<<"child.run">>) -> <<"child.run">>.

frontend_format(alang_source) -> <<"alang-source-v2">>;
frontend_format(typed_json) -> <<"alang-task-json-v1">>.

allowed_effect(Effect) ->
    lists:member(Effect, [<<"child.run">>, <<"model.generate">>,
        <<"workspace.write">>]).

safe_workspace_path(Path) when is_binary(Path), byte_size(Path) =< 4096 ->
    case Path of
        <<"/workspace/", Rest/binary>> when Rest =/= <<>> ->
            binary:match(Path, <<0>>) =:= nomatch andalso
            binary:match(Path, <<"\\">>) =:= nomatch andalso
            lists:all(fun(Segment) -> Segment =/= <<>> andalso
                Segment =/= <<".">> andalso Segment =/= <<"..">> end,
                binary:split(Rest, <<"/">>, [global]));
        _ -> false
    end;
safe_workspace_path(_) -> false.

valid_identifier(Value) when is_binary(Value) ->
    re:run(Value, <<"^[a-z][a-z0-9-]{0,127}$">>, [{capture, none}]) =:= match;
valid_identifier(_) -> false.

valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    re:run(Value, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match;
valid_digest(_) -> false.

sort_operations(Operations) ->
    lists:sort(fun(Left, Right) ->
        maps:get(semantic_operation, Left) =< maps:get(semantic_operation, Right)
    end, Operations).

sort_maps(List) ->
    lists:sort(fun(Left, Right) ->
        term_to_binary(Left, [deterministic]) =< term_to_binary(Right, [deterministic])
    end, List).

indexed(List) -> lists:zip(List, lists:seq(0, length(List) - 1)).

node_id(TaskId, Number) ->
    Suffix = iolist_to_binary(io_lib:format("~4..0B", [Number])),
    <<"node:", TaskId/binary, ":", Suffix/binary>>.

exact_map(Map, Keys) when is_map(Map) ->
    require(lists:sort(maps:keys(Map)) =:= lists:sort(Keys),
        invalid_ir_shape, <<"IR map has unknown or missing fields">>);
exact_map(_Value, _Keys) ->
    fail(invalid_ir_shape, <<"IR value must be a map">>).

require(true, _Code, _Message) -> ok;
require(false, Code, Message) -> fail(Code, Message).

fail(Code, Message) ->
    throw({ir_error, diagnostic(Code, Message)}).

diagnostic(Code, Message) ->
    #{class => lowering, code => Code, severity => error, message => Message}.
